package persistence

import (
	"context"
	"database/sql"
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"time"
)

// DefaultBackups is how many copies of the database are kept (specification,
// chapter 14).
const DefaultBackups = 12

// Backups writes dated copies of the database into a directory and keeps
// the latest ones (principle 5 of phase 3).
type Backups struct {
	db   *sql.DB
	dir  string
	keep int
	now  func() time.Time
}

// NewBackups keeps keep copies of db in dir; now is the clock.
func NewBackups(db *sql.DB, dir string, keep int, now func() time.Time) *Backups {
	return &Backups{db: db, dir: dir, keep: keep, now: now}
}

const backupPrefix, backupSuffix = "batz-", ".db"

// Backup writes a consistent copy of the database with VACUUM INTO, named by
// the UTC time (batz-20261121T101530.123Z.db, so that names sort in time
// order), then deletes the oldest copies beyond the number to keep.
func (b *Backups) Backup(ctx context.Context) error {
	if err := os.MkdirAll(b.dir, 0o700); err != nil {
		return err
	}
	name := backupPrefix + b.now().UTC().Format("20060102T150405.000Z") + backupSuffix
	path := filepath.Join(b.dir, name)
	if _, err := os.Stat(path); err == nil {
		return fmt.Errorf("backup %s already exists", name)
	}
	if _, err := b.db.ExecContext(ctx, `VACUUM INTO ?`, path); err != nil {
		return fmt.Errorf("copy the database: %w", err)
	}
	return b.prune()
}

// List returns the names of the copies, oldest first.
func (b *Backups) List() ([]string, error) {
	entries, err := os.ReadDir(b.dir)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, err
	}
	var names []string
	for _, e := range entries {
		if n := e.Name(); !e.IsDir() && strings.HasPrefix(n, backupPrefix) && strings.HasSuffix(n, backupSuffix) {
			names = append(names, n)
		}
	}
	slices.Sort(names)
	return names, nil
}

func (b *Backups) prune() error {
	names, err := b.List()
	if err != nil {
		return err
	}
	for len(names) > b.keep {
		if err := os.Remove(filepath.Join(b.dir, names[0])); err != nil {
			return err
		}
		names = names[1:]
	}
	return nil
}
