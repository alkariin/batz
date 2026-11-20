// Package application holds the use cases of the server.
package application

import (
	"context"
	"time"

	"github.com/alkariin/batz/batz-web/internal/domain/device"
	"github.com/alkariin/batz/batz-web/internal/domain/journal"
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

// JournalStore keeps the reference copy of the change journal.
type JournalStore interface {
	// InTx runs fn in one write transaction: every exchange is applied, and
	// answered, as a single operation.
	InTx(ctx context.Context, fn func(tx JournalTx) error) error
}

// JournalTx reads and writes the journal inside a transaction.
type JournalTx interface {
	// Known returns, for each origin device, the latest timestamp held.
	Known(ctx context.Context) (journal.Known, error)
	// Insert stores the entries that are not there yet, ignoring the others,
	// and returns how many were new. from is the device that sent them.
	Insert(ctx context.Context, entries []journal.Entry, from string, at time.Time) (int, error)
	// After returns, sorted by timestamp then entity, record and field, at
	// most limit entries that a copy with the known state lacks.
	After(ctx context.Context, known journal.Known, limit int) ([]journal.Entry, error)
	// Modification returns every entry stamped hlc: one modification.
	Modification(ctx context.Context, hlc string) ([]journal.Entry, error)
}
