// Package application holds the use cases of the server.
package application

import (
	"context"
	"time"

	"github.com/alkariin/batz/batz-web/internal/domain/device"
)

// DeviceStore persists devices and pairing codes.
type DeviceStore interface {
	// CreatePairingCode stores the hash of a new code.
	CreatePairingCode(ctx context.Context, codeHash string, createdAt, expiresAt time.Time) error
	// DeletePairingCodesBefore removes codes that expired before t.
	DeletePairingCodesBefore(ctx context.Context, t time.Time) error
	// Pair atomically consumes the code and creates the device. It returns
	// device.ErrPairingCodeInvalid, ErrPairingCodeExpired or ErrPairingCodeUsed
	// when the code cannot be used at now.
	Pair(ctx context.Context, codeHash string, now time.Time, d device.Device) error
	DeviceByKeyHash(ctx context.Context, keyHash string) (device.Device, error)
	ListDevices(ctx context.Context) ([]device.Device, error)
	// RevokeDevice marks the device revoked at t; revoking it again keeps the
	// first date. It returns device.ErrNotFound for an unknown id.
	RevokeDevice(ctx context.Context, id string, t time.Time) error
	TouchDevice(ctx context.Context, id string, t time.Time) error
}
