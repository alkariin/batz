package persistence

import (
	"context"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/alkariin/batz/batz-web/internal/application"
	"github.com/alkariin/batz/batz-web/internal/domain/device"
)

func TestStatementFiles(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "statements")
	files := NewStatementFiles(dir)
	fp := application.Fingerprint([]byte("%PDF-1.4 a"))

	has, err := files.Has(fp)
	require.NoError(t, err)
	assert.False(t, has)
	_, err = files.Read(fp)
	assert.ErrorIs(t, err, application.ErrPDFNotFound, "a rebuilt server has no file: no error")

	require.NoError(t, files.Save(fp, []byte("%PDF-1.4 a")))
	has, err = files.Has(fp)
	require.NoError(t, err)
	assert.True(t, has)
	pdf, err := files.Read(fp)
	require.NoError(t, err)
	assert.Equal(t, []byte("%PDF-1.4 a"), pdf)

	entries, err := os.ReadDir(dir)
	require.NoError(t, err)
	require.Len(t, entries, 1, "no temporary file left")
	assert.Equal(t, fp+".pdf", entries[0].Name())

	assert.Error(t, files.Save("../escape", []byte("x")))
	_, err = files.Has("../escape")
	assert.Error(t, err)
	_, err = files.Read("../batz")
	assert.ErrorIs(t, err, application.ErrPDFNotFound)
}

func TestBackupsCopyTheDatabaseAndKeepTheLatest(t *testing.T) {
	dir := t.TempDir()
	db, err := Open(filepath.Join(dir, "batz.db"))
	require.NoError(t, err)
	defer db.Close()
	now := time.Date(2026, 11, 21, 10, 0, 0, 0, time.UTC)
	ctx := context.Background()
	require.NoError(t, NewDeviceStore(db).CreatePairingCode(ctx, "h", now, now.Add(time.Minute)))
	require.NoError(t, NewDeviceStore(db).Pair(ctx, "h", now, device.Device{ID: "d1", Name: "Phone", KeyHash: "k", CreatedAt: now}))

	backups := NewBackups(db, filepath.Join(dir, "backups"), DefaultBackups, func() time.Time { return now })
	var written []string
	for i := range 14 {
		now = now.Add(time.Duration(i+1) * time.Minute)
		require.NoError(t, backups.Backup(ctx))
		written = append(written, "batz-"+now.Format("20060102T150405.000Z")+".db")
	}
	names, err := backups.List()
	require.NoError(t, err)
	assert.Equal(t, written[2:], names, "the 12 latest, oldest first")

	// A copy is a database the server opens, with the data.
	copyDB, err := Open(filepath.Join(dir, "backups", names[len(names)-1]))
	require.NoError(t, err)
	defer copyDB.Close()
	d, err := NewDeviceStore(copyDB).DeviceByKeyHash(ctx, "k")
	require.NoError(t, err)
	assert.Equal(t, "Phone", d.Name)

	assert.Error(t, backups.Backup(ctx), "the same instant twice is refused rather than overwritten")
}
