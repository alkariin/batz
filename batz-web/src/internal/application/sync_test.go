package application_test

import (
	"fmt"
	"math/rand/v2"
	"path/filepath"
	"slices"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/alkariin/batz/batz-web/internal/application"
	"github.com/alkariin/batz/batz-web/internal/domain/device"
	"github.com/alkariin/batz/batz-web/internal/domain/journal"
	"github.com/alkariin/batz/batz-web/internal/infrastructure/persistence"
	"github.com/alkariin/batz/batz-web/internal/version"
)

const (
	originA = "aaaaaaaa-0000-4000-8000-000000000000"
	originB = "bbbbbbbb-0000-4000-8000-000000000000"
	originC = "cccccccc-0000-4000-8000-000000000000"
)

var (
	phone  = device.Device{ID: "phone"}
	laptop = device.Device{ID: "laptop"}
)

func newSync(t *testing.T) *application.Sync {
	t.Helper()
	db, err := persistence.Open(filepath.Join(t.TempDir(), "batz.db"))
	require.NoError(t, err)
	t.Cleanup(func() { db.Close() })
	return application.NewSync(persistence.NewJournalStore(db), func() time.Time {
		return time.Date(2026, 11, 20, 10, 0, 0, 0, time.UTC)
	})
}

func stamp(millis int, origin string) string { return fmt.Sprintf("%015d:0000:%s", millis, origin) }

// modification returns n entries sharing one timestamp: one modification.
func modification(millis int, origin string, n int) []journal.Entry {
	out := make([]journal.Entry, n)
	for i := range out {
		out[i] = journal.Entry{
			HLC: stamp(millis, origin), Entity: "note", RecordID: fmt.Sprintf("r%d", millis),
			Field: fmt.Sprintf("f%02d", i), Value: fmt.Sprintf("%d", i),
		}
	}
	return out
}

func request(known, since journal.Known, entries ...journal.Entry) application.SyncRequest {
	return application.SyncRequest{Protocol: journal.Protocol, AppVersion: version.MinAppVersion, Known: known, Since: since, Entries: entries}
}

// pull pages through everything a copy with known lacks.
func pull(t *testing.T, s *application.Sync, known journal.Known, limit int) []journal.Entry {
	t.Helper()
	known = maps(known)
	var all []journal.Entry
	for range 1000 {
		req := request(known, nil)
		req.Limit = limit
		res, err := s.Exchange(t.Context(), laptop, req)
		require.NoError(t, err)
		all = append(all, res.Entries...)
		for _, e := range res.Entries {
			origin, _ := journal.Origin(e.HLC)
			if e.HLC > known[origin] {
				known[origin] = e.HLC
			}
		}
		if !res.More {
			return all
		}
		require.NotEmpty(t, res.Entries, "more without entries")
	}
	t.Fatal("pull did not end")
	return nil
}

func maps(k journal.Known) journal.Known {
	out := journal.Known{}
	for o, h := range k {
		out[o] = h
	}
	return out
}

func TestExchangeBothWays(t *testing.T) {
	s := newSync(t)
	ctx := t.Context()

	// The phone sends its two modifications to an empty server.
	page := append(modification(1000, originA, 2), modification(2000, originA, 1)...)
	res, err := s.Exchange(ctx, phone, request(journal.Known{originA: stamp(2000, originA)}, nil, page...))
	require.NoError(t, err)
	assert.Equal(t, 3, res.Added)
	assert.Equal(t, journal.Known{originA: stamp(2000, originA)}, res.Known)
	assert.Empty(t, res.Entries, "the phone holds everything the server holds")
	assert.False(t, res.More)
	assert.Equal(t, time.Date(2026, 11, 20, 10, 0, 0, 0, time.UTC), res.ServerTime)

	// The laptop, new, receives them, then sends its own.
	res, err = s.Exchange(ctx, laptop, request(nil, nil))
	require.NoError(t, err)
	assert.Equal(t, page, res.Entries)
	assert.Equal(t, journal.Known{}, res.Since, "the laptop held nothing of that origin")
	mine := modification(3000, originB, 1)
	res, err = s.Exchange(ctx, laptop, request(
		journal.Known{originA: stamp(2000, originA), originB: stamp(3000, originB)}, res.Known, mine...))
	require.NoError(t, err)
	assert.Equal(t, 1, res.Added)
	assert.Empty(t, res.Entries)

	// The phone receives the laptop's entry, and only that.
	res, err = s.Exchange(ctx, phone, request(journal.Known{originA: stamp(2000, originA)}, nil))
	require.NoError(t, err)
	assert.Equal(t, mine, res.Entries)
	assert.Equal(t, journal.Known{originA: stamp(2000, originA), originB: stamp(3000, originB)}, res.Known)

	// What the answer continues from is the receiver's state for its origins.
	res, err = s.Exchange(ctx, phone, request(journal.Known{originA: stamp(1000, originA), originB: stamp(3000, originB)}, nil))
	require.NoError(t, err)
	assert.Equal(t, modification(2000, originA, 1), res.Entries)
	assert.Equal(t, journal.Known{originA: stamp(1000, originA)}, res.Since)
}

func TestTheSamePageTwiceAddsNothing(t *testing.T) {
	s := newSync(t)
	page := append(modification(1000, originA, 2), modification(2000, originA, 2)...)
	known := journal.Known{originA: stamp(2000, originA)}
	res, err := s.Exchange(t.Context(), phone, request(known, nil, page...))
	require.NoError(t, err)
	assert.Equal(t, 4, res.Added)
	res, err = s.Exchange(t.Context(), phone, request(known, nil, page...))
	require.NoError(t, err)
	assert.Equal(t, 0, res.Added)
	assert.Equal(t, page, pull(t, s, nil, 100), "no duplicate")
}

func TestAnInvalidPageIsRefusedWhole(t *testing.T) {
	s := newSync(t)
	bad := modification(2000, originA, 1)[0]
	bad.Value = "1.5"
	page := append(modification(1000, originA, 2), bad)
	_, err := s.Exchange(t.Context(), phone, request(nil, nil, page...))
	assert.ErrorIs(t, err, journal.ErrInvalid)
	assert.Empty(t, pull(t, s, nil, 100), "nothing of the page was stored")

	unsorted := append(modification(2000, originA, 1), modification(1000, originA, 1)...)
	_, err = s.Exchange(t.Context(), phone, request(nil, nil, unsorted...))
	assert.ErrorIs(t, err, journal.ErrInvalid)

	_, err = s.Exchange(t.Context(), phone, request(journal.Known{originA: "nope"}, nil))
	assert.ErrorIs(t, err, journal.ErrInvalid)
}

func TestAPageThatWouldLeaveAGapIsRefused(t *testing.T) {
	s := newSync(t)
	_, err := s.Exchange(t.Context(), phone, request(nil, nil, modification(1000, originA, 1)...))
	require.NoError(t, err)
	// Computed when the server held up to 2000: it did not, e.g. restored
	// from an older copy in between.
	_, err = s.Exchange(t.Context(), phone, request(nil, journal.Known{originA: stamp(2000, originA)}, modification(3000, originA, 1)...))
	assert.ErrorIs(t, err, application.ErrStateChanged)
	assert.Len(t, pull(t, s, nil, 100), 1, "nothing was stored")

	// From the state the server really holds, it goes through.
	_, err = s.Exchange(t.Context(), phone, request(nil, journal.Known{originA: stamp(1000, originA)}, modification(3000, originA, 1)...))
	assert.NoError(t, err)
}

func TestProtocolAndAppVersion(t *testing.T) {
	s := newSync(t)
	req := request(nil, nil)
	req.Protocol = 2
	_, err := s.Exchange(t.Context(), phone, req)
	assert.ErrorIs(t, err, application.ErrProtocolUnsupported)
	for _, v := range []string{"0.5.0", "0.4.1", "0.4.0", "0.3.0", "0.2.0", "0.0.9", "", "dev"} {
		req = request(nil, nil)
		req.AppVersion = v
		_, err = s.Exchange(t.Context(), phone, req)
		assert.ErrorIs(t, err, application.ErrAppTooOld, v)
	}
	req = request(nil, nil)
	req.AppVersion = "0.6.0"
	_, err = s.Exchange(t.Context(), phone, req)
	assert.NoError(t, err)
}

func TestAPageOverTheLimitIsRefused(t *testing.T) {
	s := newSync(t)
	_, err := s.Exchange(t.Context(), phone, request(nil, nil, modification(1000, originA, application.MaxPageEntries+1)...))
	assert.ErrorIs(t, err, application.ErrPageTooLarge)
}

func TestPagesNeverCutAModification(t *testing.T) {
	s := newSync(t)
	var page []journal.Entry
	for _, m := range []struct{ millis, size int }{{1000, 3}, {2000, 3}, {3000, 6}, {4000, 1}} {
		page = append(page, modification(m.millis, originA, m.size)...)
	}
	_, err := s.Exchange(t.Context(), phone, request(nil, nil, page...))
	require.NoError(t, err)

	var sizes []int
	known := journal.Known{}
	for range 10 {
		req := request(known, nil)
		req.Limit = 4
		res, err := s.Exchange(t.Context(), laptop, req)
		require.NoError(t, err)
		if len(res.Entries) > 0 {
			sizes = append(sizes, len(res.Entries))
			known[originA] = res.Entries[len(res.Entries)-1].HLC
		}
		if !res.More {
			break
		}
	}
	// 3 (the next 3 would cross 4), 3, then 6 whole, then 1.
	assert.Equal(t, []int{3, 3, 6, 1}, sizes)
}

// Random histories of three origins, random known states, small pages: the
// pages hold exactly what the copy lacks, in time order, each modification
// whole.
func TestPagesHoldExactlyWhatIsMissing(t *testing.T) {
	r := rand.New(rand.NewPCG(2026, 11))
	for round := range 20 {
		s := newSync(t)
		var all []journal.Entry
		byOrigin := map[string][]string{}
		for _, origin := range []string{originA, originB, originC} {
			millis := 0
			var mine []journal.Entry
			for range r.IntN(12) {
				millis += 1 + r.IntN(50)
				m := modification(millis, origin, 1+r.IntN(4))
				mine = append(mine, m...)
				byOrigin[origin] = append(byOrigin[origin], m[0].HLC)
			}
			if len(mine) > 0 {
				_, err := s.Exchange(t.Context(), phone, request(nil, nil, mine...))
				require.NoError(t, err)
			}
			all = append(all, mine...)
		}
		known := journal.Known{}
		for origin, stamps := range byOrigin {
			if i := r.IntN(len(stamps) + 1); i > 0 {
				known[origin] = stamps[i-1]
			}
		}
		var want []journal.Entry
		for _, e := range all {
			origin, _ := journal.Origin(e.HLC)
			if !known.Holds(origin, e.HLC) {
				want = append(want, e)
			}
		}
		slices.SortFunc(want, func(a, b journal.Entry) int {
			if a.HLC != b.HLC {
				return compare(a.HLC, b.HLC)
			}
			return compare(a.Field, b.Field)
		})
		got := pull(t, s, known, 1+r.IntN(6))
		if len(want) == 0 {
			assert.Empty(t, got, "round %d", round)
		} else {
			assert.Equal(t, want, got, "round %d", round)
		}
	}
}

func compare(a, b string) int {
	switch {
	case a < b:
		return -1
	case a > b:
		return 1
	}
	return 0
}
