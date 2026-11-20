package application_test

import (
	"context"
	"path/filepath"
	"sync"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/alkariin/batz/batz-web/internal/application"
	"github.com/alkariin/batz/batz-web/internal/domain/device"
	"github.com/alkariin/batz/batz-web/internal/infrastructure/persistence"
)

// clock is a settable test clock.
type clock struct {
	mu sync.Mutex
	t  time.Time
}

func (c *clock) now() time.Time          { c.mu.Lock(); defer c.mu.Unlock(); return c.t }
func (c *clock) advance(d time.Duration) { c.mu.Lock(); c.t = c.t.Add(d); c.mu.Unlock() }

// newService runs the use cases against a real SQLite file: the atomicity of
// pairing lives in the store and is part of what is tested.
func newService(t *testing.T) (*application.Devices, *clock) {
	t.Helper()
	db, err := persistence.Open(filepath.Join(t.TempDir(), "batz.db"))
	require.NoError(t, err)
	t.Cleanup(func() { db.Close() })
	c := &clock{t: time.Date(2026, 11, 20, 10, 0, 0, 0, time.UTC)}
	return application.NewDevices(persistence.NewDeviceStore(db), c.now), c
}

var ctx = context.Background()

func TestPairWithValidCode(t *testing.T) {
	s, c := newService(t)
	code, err := s.CreatePairingCode(ctx, device.PairingCodeTTL)
	require.NoError(t, err)
	assert.Equal(t, c.now().Add(10*time.Minute), code.ExpiresAt)

	c.advance(9*time.Minute + 59*time.Second)
	paired, err := s.Pair(ctx, code.Code, " Phone ")
	require.NoError(t, err)
	assert.NotEmpty(t, paired.DeviceID)
	assert.NotEmpty(t, paired.Key)

	d, err := s.Authenticate(ctx, paired.Key)
	require.NoError(t, err)
	assert.Equal(t, paired.DeviceID, d.ID)
	assert.Equal(t, "Phone", d.Name)
	assert.NotEqual(t, paired.Key, d.KeyHash, "the key is stored hashed")
	assert.Equal(t, device.HashSecret(paired.Key), d.KeyHash)
}

func TestCodeTypedLooselyIsAccepted(t *testing.T) {
	s, _ := newService(t)
	code, err := s.CreatePairingCode(ctx, device.PairingCodeTTL)
	require.NoError(t, err)
	_, err = s.Pair(ctx, " "+device.NormalizePairingCode(code.Code)+" ", "Laptop")
	require.NoError(t, err)
}

func TestExpiredCodeIsRefused(t *testing.T) {
	s, c := newService(t)
	code, err := s.CreatePairingCode(ctx, device.PairingCodeTTL)
	require.NoError(t, err)
	c.advance(10 * time.Minute)
	_, err = s.Pair(ctx, code.Code, "Phone")
	assert.ErrorIs(t, err, device.ErrPairingCodeExpired)
}

func TestUsedCodeIsRefused(t *testing.T) {
	s, _ := newService(t)
	code, err := s.CreatePairingCode(ctx, device.PairingCodeTTL)
	require.NoError(t, err)
	_, err = s.Pair(ctx, code.Code, "Phone")
	require.NoError(t, err)
	_, err = s.Pair(ctx, code.Code, "Other")
	assert.ErrorIs(t, err, device.ErrPairingCodeUsed)

	devices, err := s.List(ctx)
	require.NoError(t, err)
	assert.Len(t, devices, 1)
}

func TestWrongCodeIsRefused(t *testing.T) {
	s, _ := newService(t)
	_, err := s.CreatePairingCode(ctx, device.PairingCodeTTL)
	require.NoError(t, err)
	_, err = s.Pair(ctx, "ZZZZ-ZZZZ", "Phone")
	assert.ErrorIs(t, err, device.ErrPairingCodeInvalid)
}

func TestConcurrentPairingUsesTheCodeOnce(t *testing.T) {
	s, _ := newService(t)
	code, err := s.CreatePairingCode(ctx, device.PairingCodeTTL)
	require.NoError(t, err)

	const n = 8
	errs := make(chan error, n)
	var wg sync.WaitGroup
	for range n {
		wg.Add(1)
		go func() { defer wg.Done(); _, err := s.Pair(ctx, code.Code, "Phone"); errs <- err }()
	}
	wg.Wait()
	close(errs)
	ok := 0
	for err := range errs {
		if err == nil {
			ok++
		} else {
			assert.ErrorIs(t, err, device.ErrPairingCodeUsed)
		}
	}
	assert.Equal(t, 1, ok)
}

func TestInvalidNameDoesNotConsumeTheCode(t *testing.T) {
	s, _ := newService(t)
	code, err := s.CreatePairingCode(ctx, device.PairingCodeTTL)
	require.NoError(t, err)
	_, err = s.Pair(ctx, code.Code, "  ")
	assert.ErrorIs(t, err, device.ErrInvalidName)
	_, err = s.Pair(ctx, code.Code, "Phone")
	assert.NoError(t, err)
}

func TestPairingCodeValidityIsBounded(t *testing.T) {
	s, _ := newService(t)
	_, err := s.CreatePairingCode(ctx, 0)
	assert.Error(t, err)
	_, err = s.CreatePairingCode(ctx, 11*time.Minute)
	assert.Error(t, err)
	_, err = s.CreatePairingCode(ctx, time.Second)
	assert.NoError(t, err)
}

func TestAuthenticateRefusesUnknownAndRevokedKeys(t *testing.T) {
	s, c := newService(t)
	code, err := s.CreatePairingCode(ctx, device.PairingCodeTTL)
	require.NoError(t, err)
	paired, err := s.Pair(ctx, code.Code, "Phone")
	require.NoError(t, err)

	_, err = s.Authenticate(ctx, "not-a-key")
	assert.ErrorIs(t, err, device.ErrUnknownKey)

	c.advance(time.Hour)
	require.NoError(t, s.Revoke(ctx, paired.DeviceID))
	_, err = s.Authenticate(ctx, paired.Key)
	assert.ErrorIs(t, err, device.ErrRevoked)

	// Revoking again keeps the first date.
	c.advance(time.Hour)
	require.NoError(t, s.Revoke(ctx, paired.DeviceID))
	devices, err := s.List(ctx)
	require.NoError(t, err)
	require.Len(t, devices, 1)
	assert.Equal(t, c.now().Add(-time.Hour), *devices[0].RevokedAt)
}

func TestAuthenticateRecordsLastSeen(t *testing.T) {
	s, c := newService(t)
	code, err := s.CreatePairingCode(ctx, device.PairingCodeTTL)
	require.NoError(t, err)
	paired, err := s.Pair(ctx, code.Code, "Phone")
	require.NoError(t, err)

	c.advance(time.Minute)
	_, err = s.Authenticate(ctx, paired.Key)
	require.NoError(t, err)
	devices, err := s.List(ctx)
	require.NoError(t, err)
	require.NotNil(t, devices[0].LastSeenAt)
	assert.Equal(t, c.now(), *devices[0].LastSeenAt)
}

func TestRevokeUnknownDevice(t *testing.T) {
	s, _ := newService(t)
	assert.ErrorIs(t, s.Revoke(ctx, "nope"), device.ErrNotFound)
}
