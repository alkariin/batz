package persistence

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"time"

	"github.com/alkariin/batz/batz-web/internal/domain/device"
)

// DeviceStore implements application.DeviceStore on SQLite.
type DeviceStore struct{ db *sql.DB }

// NewDeviceStore wraps an open database.
func NewDeviceStore(db *sql.DB) *DeviceStore { return &DeviceStore{db: db} }

func ms(t time.Time) int64 { return t.UnixMilli() }

func fromMs(v int64) time.Time { return time.UnixMilli(v).UTC() }

func fromNullMs(v sql.NullInt64) *time.Time {
	if !v.Valid {
		return nil
	}
	t := fromMs(v.Int64)
	return &t
}

func (s *DeviceStore) CreatePairingCode(ctx context.Context, codeHash string, createdAt, expiresAt time.Time) error {
	_, err := s.db.ExecContext(ctx,
		`INSERT INTO pairing_codes (code_hash, created_at, expires_at) VALUES (?, ?, ?)`,
		codeHash, ms(createdAt), ms(expiresAt))
	if err != nil {
		return fmt.Errorf("create pairing code: %w", err)
	}
	return nil
}

func (s *DeviceStore) DeletePairingCodesBefore(ctx context.Context, t time.Time) error {
	if _, err := s.db.ExecContext(ctx, `DELETE FROM pairing_codes WHERE expires_at < ?`, ms(t)); err != nil {
		return fmt.Errorf("delete old pairing codes: %w", err)
	}
	return nil
}

func (s *DeviceStore) Pair(ctx context.Context, codeHash string, now time.Time, d device.Device) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("pair: %w", err)
	}
	defer tx.Rollback() //nolint:errcheck // no-op after commit

	var expiresAt int64
	var usedAt sql.NullInt64
	err = tx.QueryRowContext(ctx,
		`SELECT expires_at, used_at FROM pairing_codes WHERE code_hash = ?`, codeHash).
		Scan(&expiresAt, &usedAt)
	switch {
	case errors.Is(err, sql.ErrNoRows):
		return device.ErrPairingCodeInvalid
	case err != nil:
		return fmt.Errorf("pair: %w", err)
	case usedAt.Valid:
		return device.ErrPairingCodeUsed
	case ms(now) >= expiresAt:
		return device.ErrPairingCodeExpired
	}

	if _, err := tx.ExecContext(ctx,
		`INSERT INTO devices (id, name, key_hash, created_at) VALUES (?, ?, ?, ?)`,
		d.ID, d.Name, d.KeyHash, ms(d.CreatedAt)); err != nil {
		return fmt.Errorf("pair: create device: %w", err)
	}
	if _, err := tx.ExecContext(ctx,
		`UPDATE pairing_codes SET used_at = ?, device_id = ? WHERE code_hash = ?`,
		ms(now), d.ID, codeHash); err != nil {
		return fmt.Errorf("pair: consume code: %w", err)
	}
	if err := tx.Commit(); err != nil {
		return fmt.Errorf("pair: %w", err)
	}
	return nil
}

const deviceColumns = `id, name, key_hash, created_at, last_seen_at, revoked_at`

func scanDevice(row interface{ Scan(...any) error }) (device.Device, error) {
	var d device.Device
	var created int64
	var seen, revoked sql.NullInt64
	if err := row.Scan(&d.ID, &d.Name, &d.KeyHash, &created, &seen, &revoked); err != nil {
		return device.Device{}, err
	}
	d.CreatedAt = fromMs(created)
	d.LastSeenAt = fromNullMs(seen)
	d.RevokedAt = fromNullMs(revoked)
	return d, nil
}

func (s *DeviceStore) DeviceByKeyHash(ctx context.Context, keyHash string) (device.Device, error) {
	d, err := scanDevice(s.db.QueryRowContext(ctx,
		`SELECT `+deviceColumns+` FROM devices WHERE key_hash = ?`, keyHash))
	if errors.Is(err, sql.ErrNoRows) {
		return device.Device{}, device.ErrUnknownKey
	}
	if err != nil {
		return device.Device{}, fmt.Errorf("find device: %w", err)
	}
	return d, nil
}

func (s *DeviceStore) ListDevices(ctx context.Context) ([]device.Device, error) {
	rows, err := s.db.QueryContext(ctx, `SELECT `+deviceColumns+` FROM devices ORDER BY created_at, id`)
	if err != nil {
		return nil, fmt.Errorf("list devices: %w", err)
	}
	defer rows.Close()
	devices := []device.Device{}
	for rows.Next() {
		d, err := scanDevice(rows)
		if err != nil {
			return nil, fmt.Errorf("list devices: %w", err)
		}
		devices = append(devices, d)
	}
	return devices, rows.Err()
}

func (s *DeviceStore) RevokeDevice(ctx context.Context, id string, t time.Time) error {
	res, err := s.db.ExecContext(ctx,
		`UPDATE devices SET revoked_at = COALESCE(revoked_at, ?) WHERE id = ?`, ms(t), id)
	if err != nil {
		return fmt.Errorf("revoke device: %w", err)
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return device.ErrNotFound
	}
	return nil
}

func (s *DeviceStore) TouchDevice(ctx context.Context, id string, t time.Time) error {
	if _, err := s.db.ExecContext(ctx, `UPDATE devices SET last_seen_at = ? WHERE id = ?`, ms(t), id); err != nil {
		return fmt.Errorf("touch device: %w", err)
	}
	return nil
}
