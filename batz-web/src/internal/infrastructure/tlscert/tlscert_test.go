package tlscert

import (
	"crypto/x509"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestLoadOrCreateKeepsTheCertificate(t *testing.T) {
	dir := t.TempDir()
	now := time.Date(2026, 11, 20, 12, 0, 0, 0, time.UTC)

	first, err := LoadOrCreate(dir, now)
	require.NoError(t, err)
	second, err := LoadOrCreate(dir, now.Add(time.Hour))
	require.NoError(t, err)
	assert.Equal(t, Fingerprint(first), Fingerprint(second))
	assert.Regexp(t, `^([0-9A-F]{2}:){31}[0-9A-F]{2}$`, Fingerprint(first))

	leaf, err := x509.ParseCertificate(first.Certificate[0])
	require.NoError(t, err)
	assert.Equal(t, time.Date(2036, 11, 20, 12, 0, 0, 0, time.UTC), leaf.NotAfter.UTC())
	assert.Contains(t, leaf.ExtKeyUsage, x509.ExtKeyUsageServerAuth)

	info, err := os.Stat(filepath.Join(dir, "tls", "server.key"))
	require.NoError(t, err)
	assert.Equal(t, os.FileMode(0o600), info.Mode().Perm())

	loaded, err := Load(dir)
	require.NoError(t, err)
	assert.Equal(t, Fingerprint(first), Fingerprint(loaded))
}

func TestEachDataDirGetsItsOwnCertificate(t *testing.T) {
	now := time.Now()
	a, err := LoadOrCreate(t.TempDir(), now)
	require.NoError(t, err)
	b, err := LoadOrCreate(t.TempDir(), now)
	require.NoError(t, err)
	assert.NotEqual(t, Fingerprint(a), Fingerprint(b))
}

func TestLoadFailsWithoutCertificate(t *testing.T) {
	_, err := Load(t.TempDir())
	assert.Error(t, err)
}
