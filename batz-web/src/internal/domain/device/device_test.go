package device

import (
	"regexp"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestNewPairingCode(t *testing.T) {
	format := regexp.MustCompile(`^[0-9A-HJKMNP-TV-Z]{4}-[0-9A-HJKMNP-TV-Z]{4}$`)
	seen := map[string]bool{}
	for range 200 {
		code, err := NewPairingCode()
		require.NoError(t, err)
		assert.Regexp(t, format, code)
		seen[code] = true
	}
	assert.Greater(t, len(seen), 195, "codes must be random")
}

func TestNormalizePairingCode(t *testing.T) {
	assert.Equal(t, "AB12CD10", NormalizePairingCode(" ab12-cdIO "))
	assert.Equal(t, "1111", NormalizePairingCode("iIlL"))
	assert.Equal(t, HashPairingCode("ABCD-EFGH"), HashPairingCode("abcd efgh"))
}

func TestNewKey(t *testing.T) {
	a, err := NewKey()
	require.NoError(t, err)
	b, err := NewKey()
	require.NoError(t, err)
	assert.Len(t, a, 43)
	assert.NotEqual(t, a, b)
	assert.NotEqual(t, a, HashSecret(a))
	assert.Len(t, HashSecret(a), 64)
}

func TestNewID(t *testing.T) {
	id, err := NewID()
	require.NoError(t, err)
	assert.Regexp(t, `^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$`, id)
}

func TestNormalizeName(t *testing.T) {
	name, err := NormalizeName("  Téléphone  ")
	require.NoError(t, err)
	assert.Equal(t, "Téléphone", name)

	_, err = NormalizeName("   ")
	assert.ErrorIs(t, err, ErrInvalidName)

	_, err = NormalizeName(strings.Repeat("é", MaxNameLength))
	assert.NoError(t, err)
	_, err = NormalizeName(strings.Repeat("é", MaxNameLength+1))
	assert.ErrorIs(t, err, ErrInvalidName)
}
