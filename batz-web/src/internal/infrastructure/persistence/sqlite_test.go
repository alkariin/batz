package persistence

import (
	"context"
	"database/sql"
	"path/filepath"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/alkariin/batz/batz-web/internal/domain/device"
)

func TestOpenTwiceKeepsData(t *testing.T) {
	path := filepath.Join(t.TempDir(), "batz.db")
	db, err := Open(path)
	require.NoError(t, err)
	store := NewDeviceStore(db)
	now := time.Date(2026, 11, 20, 10, 0, 0, 123e6, time.UTC)
	require.NoError(t, store.CreatePairingCode(context.Background(), "h", now, now.Add(time.Minute)))
	require.NoError(t, store.Pair(context.Background(), "h", now, device.Device{ID: "d1", Name: "Phone", KeyHash: "k", CreatedAt: now}))
	require.NoError(t, db.Close())

	db, err = Open(path) // migrations already applied: no change, no error
	require.NoError(t, err)
	defer db.Close()
	d, err := NewDeviceStore(db).DeviceByKeyHash(context.Background(), "k")
	require.NoError(t, err)
	assert.Equal(t, now, d.CreatedAt)
	assert.Nil(t, d.RevokedAt)

	var fk int
	require.NoError(t, db.QueryRow(`PRAGMA foreign_keys`).Scan(&fk))
	assert.Equal(t, 1, fk)
}

func TestDeletePairingCodesBefore(t *testing.T) {
	db, err := Open(filepath.Join(t.TempDir(), "batz.db"))
	require.NoError(t, err)
	defer db.Close()
	s := NewDeviceStore(db)
	now := time.Now()
	require.NoError(t, s.CreatePairingCode(context.Background(), "old", now.Add(-2*time.Hour), now.Add(-time.Hour)))
	require.NoError(t, s.CreatePairingCode(context.Background(), "new", now, now.Add(time.Minute)))
	require.NoError(t, s.DeletePairingCodesBefore(context.Background(), now))
	var n int
	require.NoError(t, db.QueryRow(`SELECT count(*) FROM pairing_codes`).Scan(&n))
	assert.Equal(t, 1, n)
}

// A database of server 0.2.0 (devices only, migration 1) gets the journal and
// keeps its devices.
func TestUpgradeFromTheDevicesOnlySchema(t *testing.T) {
	path := filepath.Join(t.TempDir(), "batz.db")
	old, err := sql.Open("sqlite", "file:"+path)
	require.NoError(t, err)
	up, err := migrations.ReadFile("migrations/000001_devices.up.sql")
	require.NoError(t, err)
	for _, stmt := range []string{
		string(up),
		`CREATE TABLE schema_migrations (version uint64, dirty bool)`,
		`CREATE UNIQUE INDEX version_unique ON schema_migrations (version)`,
		`INSERT INTO schema_migrations VALUES (1, 0)`,
		`INSERT INTO devices (id, name, key_hash, created_at) VALUES ('d1', 'Phone', 'k', 1)`,
	} {
		_, err := old.Exec(stmt)
		require.NoError(t, err, stmt)
	}
	require.NoError(t, old.Close())

	db, err := Open(path)
	require.NoError(t, err)
	defer db.Close()
	d, err := NewDeviceStore(db).DeviceByKeyHash(context.Background(), "k")
	require.NoError(t, err)
	assert.Equal(t, "Phone", d.Name)
	var version int
	require.NoError(t, db.QueryRow(`SELECT version FROM schema_migrations`).Scan(&version))
	assert.Equal(t, 2, version)
	var n int
	require.NoError(t, db.QueryRow(`SELECT count(*) FROM journal`).Scan(&n))
	assert.Equal(t, 0, n)
}
