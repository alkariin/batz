package application

import (
	"context"
	"fmt"
	"time"

	"github.com/alkariin/batz/batz-web/internal/domain/device"
)

// Devices pairs, authenticates, lists and revokes devices.
type Devices struct {
	store DeviceStore
	now   func() time.Time
}

// NewDevices builds the service. now is the clock, time.Now in production.
func NewDevices(store DeviceStore, now func() time.Time) *Devices {
	return &Devices{store: store, now: now}
}

// PairingCode is a freshly created one-time code.
type PairingCode struct {
	Code      string
	ExpiresAt time.Time
}

// CreatePairingCode creates a one-time code valid for ttl, which must be
// positive and at most device.PairingCodeTTL.
func (s *Devices) CreatePairingCode(ctx context.Context, ttl time.Duration) (PairingCode, error) {
	if ttl <= 0 || ttl > device.PairingCodeTTL {
		return PairingCode{}, fmt.Errorf("pairing code validity must be between 1ns and %s", device.PairingCodeTTL)
	}
	now := s.now().UTC()
	if err := s.store.DeletePairingCodesBefore(ctx, now.Add(-24*time.Hour)); err != nil {
		return PairingCode{}, err
	}
	code, err := device.NewPairingCode()
	if err != nil {
		return PairingCode{}, err
	}
	expiresAt := now.Add(ttl)
	if err := s.store.CreatePairingCode(ctx, device.HashPairingCode(code), now, expiresAt); err != nil {
		return PairingCode{}, err
	}
	return PairingCode{Code: code, ExpiresAt: expiresAt}, nil
}

// Paired is what a device receives once: its id and its secret key.
type Paired struct {
	DeviceID string
	Key      string
}

// Pair exchanges a valid code for a new device and its key. Only the hash of
// the key is stored.
func (s *Devices) Pair(ctx context.Context, code, name string) (Paired, error) {
	name, err := device.NormalizeName(name)
	if err != nil {
		return Paired{}, err
	}
	id, err := device.NewID()
	if err != nil {
		return Paired{}, err
	}
	key, err := device.NewKey()
	if err != nil {
		return Paired{}, err
	}
	now := s.now().UTC()
	d := device.Device{ID: id, Name: name, KeyHash: device.HashSecret(key), CreatedAt: now}
	if err := s.store.Pair(ctx, device.HashPairingCode(code), now, d); err != nil {
		return Paired{}, err
	}
	return Paired{DeviceID: id, Key: key}, nil
}

// Authenticate returns the device owning key, or device.ErrUnknownKey or
// device.ErrRevoked. It records when the device was last seen.
func (s *Devices) Authenticate(ctx context.Context, key string) (device.Device, error) {
	d, err := s.store.DeviceByKeyHash(ctx, device.HashSecret(key))
	if err != nil {
		return device.Device{}, err
	}
	if d.Revoked() {
		return device.Device{}, device.ErrRevoked
	}
	now := s.now().UTC()
	if err := s.store.TouchDevice(ctx, d.ID, now); err != nil {
		return device.Device{}, err
	}
	d.LastSeenAt = &now
	return d, nil
}

// List returns every device, revoked ones included, oldest first.
func (s *Devices) List(ctx context.Context) ([]device.Device, error) {
	return s.store.ListDevices(ctx)
}

// Revoke revokes a device; its key is refused from then on.
func (s *Devices) Revoke(ctx context.Context, id string) error {
	return s.store.RevokeDevice(ctx, id, s.now().UTC())
}
