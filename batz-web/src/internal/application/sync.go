package application

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/alkariin/batz/batz-web/internal/domain/device"
	"github.com/alkariin/batz/batz-web/internal/domain/journal"
	"github.com/alkariin/batz/batz-web/internal/version"
)

// Page limits. A page never cuts a modification: when one modification alone
// is larger than the requested size, it is sent whole.
const (
	// MaxPageEntries is the largest page accepted from an app, and the
	// largest an app may ask for. The app never writes a modification larger
	// than that.
	MaxPageEntries = 10000
	// DefaultPageEntries is the size of the pages sent when the app does not
	// ask for a size.
	DefaultPageEntries = 1000
	// maxPageBytes stops a page early when its entries hold large values.
	maxPageBytes = 8 << 20
)

var (
	ErrProtocolUnsupported = fmt.Errorf("unsupported exchange protocol, this server speaks version %d", journal.Protocol)
	ErrAppTooOld           = fmt.Errorf("app too old, this server requires version %s or later", version.MinAppVersion)
	ErrPageTooLarge        = fmt.Errorf("page over %d entries", MaxPageEntries)
	// ErrStateChanged means the server no longer holds what the page was
	// computed from (for instance it was restored from an older copy): the
	// app starts the exchange again from the server's current state.
	ErrStateChanged = errors.New("the server state changed since the page was computed")
)

// SyncRequest is one call of an exchange: the app's known state, and a page
// of entries the server lacks, computed from the server state since.
type SyncRequest struct {
	Protocol   int
	AppVersion string
	Known      journal.Known
	Since      journal.Known
	Entries    []journal.Entry
	// Limit is the largest page the app wants back; 0 for the default.
	Limit int
}

// SyncResult is the answer: the server state after integrating the app's
// page, and a page of entries the app lacks, computed from its known state.
type SyncResult struct {
	Known journal.Known
	// Since is the app's known state for the origins of Entries.
	Since   journal.Known
	Entries []journal.Entry
	// More is true when the server may hold more entries the app lacks.
	More bool
	// Added counts the entries of the app's page that were new.
	Added      int
	ServerTime time.Time
}

// Sync is the exchange of the journal between the apps and the server.
type Sync struct {
	store JournalStore
	now   func() time.Time
}

// NewSync builds the service. now is the clock, time.Now in production.
func NewSync(store JournalStore, now func() time.Time) *Sync {
	return &Sync{store: store, now: now}
}

// Exchange integrates the page of req in one operation, then answers with
// the server state and a page of what the app lacks. A page that is not
// entirely valid is refused as a whole, with journal.ErrInvalid; replaying a
// page changes nothing.
func (s *Sync) Exchange(ctx context.Context, from device.Device, req SyncRequest) (SyncResult, error) {
	if req.Protocol != journal.Protocol {
		return SyncResult{}, ErrProtocolUnsupported
	}
	if cmp, ok := version.Compare(req.AppVersion, version.MinAppVersion); !ok || cmp < 0 {
		return SyncResult{}, ErrAppTooOld
	}
	if len(req.Entries) > MaxPageEntries {
		return SyncResult{}, ErrPageTooLarge
	}
	if err := req.Known.Validate(); err != nil {
		return SyncResult{}, fmt.Errorf("known: %w", err)
	}
	origins, err := journal.ValidatePage(req.Entries, req.Since)
	if err != nil {
		return SyncResult{}, err
	}
	limit := req.Limit
	if limit <= 0 {
		limit = DefaultPageEntries
	}
	limit = min(limit, MaxPageEntries)

	now := s.now().UTC()
	var res SyncResult
	err = s.store.InTx(ctx, func(tx JournalTx) error {
		if len(req.Entries) > 0 {
			known, err := tx.Known(ctx)
			if err != nil {
				return err
			}
			// The invariant: for each origin, the server holds its entries
			// from the first one, without a gap. The page continues from
			// since; the server must hold at least that much.
			for origin := range origins {
				if after, ok := req.Since[origin]; ok && !known.Holds(origin, after) {
					return ErrStateChanged
				}
			}
			if res.Added, err = tx.Insert(ctx, req.Entries, from.ID, now); err != nil {
				return err
			}
		}
		known, err := tx.Known(ctx)
		if err != nil {
			return err
		}
		res.Known = known
		res.Entries, res.More, err = page(ctx, tx, req.Known, limit)
		return err
	})
	if err != nil {
		return SyncResult{}, err
	}
	res.Since = journal.Known{}
	for _, e := range res.Entries {
		origin, _ := journal.Origin(e.HLC)
		if hlc, ok := req.Known[origin]; ok {
			res.Since[origin] = hlc
		}
	}
	res.ServerTime = now
	return res, nil
}

// page returns the entries a copy with the known state lacks, oldest first:
// about limit of them, never cutting a modification.
func page(ctx context.Context, tx JournalTx, known journal.Known, limit int) ([]journal.Entry, bool, error) {
	rows, err := tx.After(ctx, known, limit+1)
	if err != nil {
		return nil, false, err
	}
	out, size := rows, 0
	for i, e := range rows {
		if size += e.Size(); i == limit || size > maxPageBytes {
			out = rows[:i]
			break
		}
	}
	if len(out) == len(rows) {
		return out, false, nil
	}
	// rows[len(out)] is the first entry left out: drop the entries of its
	// modification that made it in.
	cut := rows[len(out)].HLC
	for len(out) > 0 && out[len(out)-1].HLC == cut {
		out = out[:len(out)-1]
	}
	if len(out) == 0 {
		// One modification larger than a page: it goes whole.
		out, err = tx.Modification(ctx, cut)
		if err != nil {
			return nil, false, err
		}
	}
	return out, true, nil
}
