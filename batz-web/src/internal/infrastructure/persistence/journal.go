package persistence

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"time"

	"github.com/alkariin/batz/batz-web/internal/application"
	"github.com/alkariin/batz/batz-web/internal/domain/journal"
)

// JournalStore implements application.JournalStore on SQLite.
type JournalStore struct{ db *sql.DB }

// NewJournalStore wraps an open database.
func NewJournalStore(db *sql.DB) *JournalStore { return &JournalStore{db: db} }

// InTx runs fn in a BEGIN IMMEDIATE transaction (see Open): exchanges are
// serialised, and each one is applied entirely or not at all.
func (s *JournalStore) InTx(ctx context.Context, fn func(application.JournalTx) error) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("journal: %w", err)
	}
	defer tx.Rollback() //nolint:errcheck // no-op after commit
	if err := fn(journalTx{tx}); err != nil {
		return err
	}
	if err := tx.Commit(); err != nil {
		return fmt.Errorf("journal: commit: %w", err)
	}
	return nil
}

type journalTx struct{ tx *sql.Tx }

func (t journalTx) Known(ctx context.Context) (journal.Known, error) {
	rows, err := t.tx.QueryContext(ctx, `SELECT origin, MAX(hlc) FROM journal GROUP BY origin`)
	if err != nil {
		return nil, fmt.Errorf("journal: known state: %w", err)
	}
	defer rows.Close()
	known := journal.Known{}
	for rows.Next() {
		var origin, hlc string
		if err := rows.Scan(&origin, &hlc); err != nil {
			return nil, fmt.Errorf("journal: known state: %w", err)
		}
		known[origin] = hlc
	}
	return known, rows.Err()
}

func (t journalTx) Insert(ctx context.Context, entries []journal.Entry, from string, at time.Time) (int, error) {
	stmt, err := t.tx.PrepareContext(ctx, `INSERT INTO journal
		(hlc, entity, record_id, field, value, origin, received_from, received_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT DO NOTHING`)
	if err != nil {
		return 0, fmt.Errorf("journal: insert: %w", err)
	}
	defer stmt.Close()
	added := 0
	for _, e := range entries {
		origin, err := journal.Origin(e.HLC)
		if err != nil {
			return 0, err
		}
		res, err := stmt.ExecContext(ctx, e.HLC, e.Entity, e.RecordID, e.Field, e.Value, origin, from, ms(at))
		if err != nil {
			return 0, fmt.Errorf("journal: insert: %w", err)
		}
		n, err := res.RowsAffected()
		if err != nil {
			return 0, fmt.Errorf("journal: insert: %w", err)
		}
		added += int(n)
	}
	return added, nil
}

const entryColumns = `hlc, entity, record_id, field, value`

func (t journalTx) After(ctx context.Context, known journal.Known, limit int) ([]journal.Entry, error) {
	// Every entry the copy lacks is after the lowest of its known
	// timestamps, unless it lacks an origin altogether.
	held, err := t.Known(ctx)
	if err != nil {
		return nil, err
	}
	lower := ""
	first := true
	for origin := range held {
		hlc, ok := known[origin]
		if !ok {
			lower = ""
			break
		}
		if first || hlc < lower {
			lower, first = hlc, false
		}
	}
	knownJSON, err := json.Marshal(known)
	if err != nil {
		return nil, err
	}
	return t.query(ctx, `SELECT `+entryColumns+` FROM journal j
		WHERE j.hlc > ?
		  AND NOT EXISTS (SELECT 1 FROM json_each(?) k WHERE k.key = j.origin AND j.hlc <= k.value)
		ORDER BY j.hlc, j.entity, j.record_id, j.field
		LIMIT ?`, lower, string(knownJSON), limit)
}

func (t journalTx) Modification(ctx context.Context, hlc string) ([]journal.Entry, error) {
	return t.query(ctx, `SELECT `+entryColumns+` FROM journal WHERE hlc = ?
		ORDER BY entity, record_id, field`, hlc)
}

func (t journalTx) query(ctx context.Context, query string, args ...any) ([]journal.Entry, error) {
	rows, err := t.tx.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("journal: read: %w", err)
	}
	defer rows.Close()
	out := []journal.Entry{}
	for rows.Next() {
		var e journal.Entry
		if err := rows.Scan(&e.HLC, &e.Entity, &e.RecordID, &e.Field, &e.Value); err != nil {
			return nil, fmt.Errorf("journal: read: %w", err)
		}
		out = append(out, e)
	}
	return out, rows.Err()
}
