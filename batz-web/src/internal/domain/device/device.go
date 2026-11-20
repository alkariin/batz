// Package device models the devices paired with the server and the one-time
// codes used to pair them.
package device

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"fmt"
	"strings"
	"time"
	"unicode/utf8"
)

// PairingCodeTTL is how long a pairing code stays valid at most.
const PairingCodeTTL = 10 * time.Minute

// MaxNameLength is the maximum length of a device name, in characters.
const MaxNameLength = 64

// pairingAlphabet is Crockford's base32: no I, L, O or U, so a code read
// aloud or copied by hand is hard to get wrong.
const pairingAlphabet = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"

// pairingCodeLength gives 40 random bits, ample for a code that lives
// 10 minutes on a home network.
const pairingCodeLength = 8

var (
	ErrPairingCodeInvalid = errors.New("pairing code is invalid")
	ErrPairingCodeExpired = errors.New("pairing code has expired")
	ErrPairingCodeUsed    = errors.New("pairing code was already used")
	ErrInvalidName        = fmt.Errorf("device name must be 1 to %d characters", MaxNameLength)
	ErrNotFound           = errors.New("device not found")
	ErrUnknownKey         = errors.New("device key is unknown")
	ErrRevoked            = errors.New("device is revoked")
)

// Device is an app installation allowed to talk to the server.
type Device struct {
	ID         string
	Name       string
	KeyHash    string
	CreatedAt  time.Time
	LastSeenAt *time.Time
	RevokedAt  *time.Time
}

// Revoked reports whether the device was revoked.
func (d Device) Revoked() bool { return d.RevokedAt != nil }

// NewPairingCode returns a random code formatted as "XXXX-XXXX".
func NewPairingCode() (string, error) {
	buf := make([]byte, pairingCodeLength)
	if _, err := rand.Read(buf); err != nil {
		return "", fmt.Errorf("generate pairing code: %w", err)
	}
	var b strings.Builder
	for i, v := range buf {
		if i == pairingCodeLength/2 {
			b.WriteByte('-')
		}
		b.WriteByte(pairingAlphabet[int(v)%len(pairingAlphabet)])
	}
	return b.String(), nil
}

// NormalizePairingCode turns what a user typed into the canonical code:
// upper case, without separators, with the characters Crockford's base32
// treats as look-alikes mapped (O to 0, I and L to 1).
func NormalizePairingCode(s string) string {
	var b strings.Builder
	for _, r := range strings.ToUpper(s) {
		switch r {
		case ' ', '-', '\t':
			continue
		case 'O':
			r = '0'
		case 'I', 'L':
			r = '1'
		}
		b.WriteRune(r)
	}
	return b.String()
}

// HashPairingCode hashes a code as typed by the user.
func HashPairingCode(code string) string { return HashSecret(NormalizePairingCode(code)) }

// NewKey returns a random device key: 32 bytes, base64url without padding.
func NewKey() (string, error) {
	buf := make([]byte, 32)
	if _, err := rand.Read(buf); err != nil {
		return "", fmt.Errorf("generate device key: %w", err)
	}
	return base64.RawURLEncoding.EncodeToString(buf), nil
}

// HashSecret returns the hex SHA-256 of a secret. Codes and keys carry enough
// randomness that a slow hash would add nothing.
func HashSecret(secret string) string {
	sum := sha256.Sum256([]byte(secret))
	return hex.EncodeToString(sum[:])
}

// NewID returns a random UUID v4.
func NewID() (string, error) {
	var u [16]byte
	if _, err := rand.Read(u[:]); err != nil {
		return "", fmt.Errorf("generate id: %w", err)
	}
	u[6] = u[6]&0x0f | 0x40
	u[8] = u[8]&0x3f | 0x80
	return fmt.Sprintf("%x-%x-%x-%x-%x", u[0:4], u[4:6], u[6:8], u[8:10], u[10:16]), nil
}

// NormalizeName trims a device name and checks its length.
func NormalizeName(name string) (string, error) {
	name = strings.TrimSpace(name)
	if n := utf8.RuneCountInString(name); n == 0 || n > MaxNameLength {
		return "", ErrInvalidName
	}
	return name, nil
}
