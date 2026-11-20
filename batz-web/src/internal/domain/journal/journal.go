// Package journal models the change journal the server keeps for the apps.
//
// The server stores entries as they come and never interprets them: conflicts
// are resolved by the apps, field by field, the latest timestamp winning. It
// only checks their shape, so that a malformed page is refused as a whole
// (see docs/sync.md).
package journal

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"regexp"
	"strconv"
	"unicode/utf8"
)

// Protocol is the version of the exchange protocol this server speaks. The
// app sends the version it speaks; any other is refused.
const Protocol = 1

// DeletedField is the reserved field that records a deletion; its value is a
// boolean.
const DeletedField = "_deleted"

// Limits on the shape of an entry.
const (
	MaxNameLength     = 64
	MaxRecordIDLength = 128
	MaxValueBytes     = 256 << 10
)

var (
	// ErrInvalid wraps every shape error of an entry, a known state or a page.
	ErrInvalid = errors.New("invalid journal data")

	// A timestamp of the app's hybrid logical clock: wall time in
	// milliseconds (15 digits), counter (4 hex digits), origin device. The
	// fixed width makes the text order the time order.
	hlcPattern    = regexp.MustCompile(`^[0-9]{15}:[0-9a-f]{4}:([0-9a-f-]{1,64})$`)
	originPattern = regexp.MustCompile(`^[0-9a-f-]{1,64}$`)
	namePattern   = regexp.MustCompile(`^[a-z][a-zA-Z0-9]*$`)
)

func invalid(format string, args ...any) error {
	return fmt.Errorf("%w: %s", ErrInvalid, fmt.Sprintf(format, args...))
}

// Origin returns the device that made the change stamped hlc, or an error if
// hlc is not a well-formed timestamp.
func Origin(hlc string) (string, error) {
	m := hlcPattern.FindStringSubmatch(hlc)
	if m == nil {
		return "", invalid("malformed timestamp %q", hlc)
	}
	return m[1], nil
}

// Entry is one field of one record set to one value, at one time, on one
// device. Value is the JSON text of the value, kept exactly as received.
type Entry struct {
	HLC      string
	Entity   string
	RecordID string
	Field    string
	Value    string
}

// Key identifies an entry: two entries with the same key are the same change.
type Key struct{ HLC, Entity, RecordID, Field string }

// Key returns the identity of e.
func (e Entry) Key() Key { return Key{e.HLC, e.Entity, e.RecordID, e.Field} }

// Size approximates the space e takes in a JSON page.
func (e Entry) Size() int {
	return len(e.HLC) + len(e.Entity) + len(e.RecordID) + len(e.Field) + len(e.Value) + 64
}

// Validate checks the shape of e and returns its origin.
func (e Entry) Validate() (string, error) {
	origin, err := Origin(e.HLC)
	if err != nil {
		return "", err
	}
	if len(e.Entity) > MaxNameLength || !namePattern.MatchString(e.Entity) {
		return "", invalid("malformed entity %q", e.Entity)
	}
	if e.Field != DeletedField && (len(e.Field) > MaxNameLength || !namePattern.MatchString(e.Field)) {
		return "", invalid("malformed field %q", e.Field)
	}
	if e.RecordID == "" || len(e.RecordID) > MaxRecordIDLength || !utf8.ValidString(e.RecordID) {
		return "", invalid("malformed record id %q", e.RecordID)
	}
	if len(e.Value) > MaxValueBytes {
		return "", invalid("value over %d bytes", MaxValueBytes)
	}
	v, err := scalar(e.Value)
	if err != nil {
		return "", err
	}
	if _, isBool := v.(bool); e.Field == DeletedField && !isBool {
		return "", invalid("%s must be true or false, got %s", DeletedField, e.Value)
	}
	return origin, nil
}

// scalar decodes a JSON value that the journal accepts: null, a boolean, an
// integer that fits 64 bits, or a string. Amounts are integer cents, so
// there is no floating point.
func scalar(text string) (any, error) {
	dec := json.NewDecoder(bytes.NewReader([]byte(text)))
	dec.UseNumber()
	var v any
	if err := dec.Decode(&v); err != nil {
		return nil, invalid("value is not JSON: %q", text)
	}
	if _, err := dec.Token(); !errors.Is(err, io.EOF) {
		return nil, invalid("value has trailing data: %q", text)
	}
	switch n := v.(type) {
	case nil, bool, string:
		return v, nil
	case json.Number:
		if _, err := strconv.ParseInt(n.String(), 10, 64); err != nil {
			return nil, invalid("value is not a 64-bit integer: %q", text)
		}
		return v, nil
	default:
		return nil, invalid("value must be null, a boolean, an integer or a string: %q", text)
	}
}

// Known is a known state: for each origin device, the timestamp of the
// latest of its entries a copy of the journal holds. Every copy holds the
// entries of each origin from the first one, without a gap, so this is
// enough to tell what it lacks.
type Known map[string]string

// Validate checks that every key is an origin and every value one of its
// timestamps.
func (k Known) Validate() error {
	for origin, hlc := range k {
		if !originPattern.MatchString(origin) {
			return invalid("malformed origin %q", origin)
		}
		o, err := Origin(hlc)
		if err != nil {
			return err
		}
		if o != origin {
			return invalid("timestamp %q does not belong to origin %q", hlc, origin)
		}
	}
	return nil
}

// Holds reports whether a copy with this known state holds the entries
// stamped hlc, whose origin is origin.
func (k Known) Holds(origin, hlc string) bool {
	latest, ok := k[origin]
	return ok && hlc <= latest
}

// ValidatePage checks a page of entries sent by a copy of the journal:
// every entry well formed, sorted by timestamp, none twice, each after what
// the receiver held of its origin when the page was computed (since). It
// returns the origins present in the page.
func ValidatePage(entries []Entry, since Known) (map[string]bool, error) {
	if err := since.Validate(); err != nil {
		return nil, fmt.Errorf("since: %w", err)
	}
	origins := map[string]bool{}
	seen := make(map[Key]bool, len(entries))
	for i, e := range entries {
		origin, err := e.Validate()
		if err != nil {
			return nil, fmt.Errorf("entry %d: %w", i, err)
		}
		if i > 0 && e.HLC < entries[i-1].HLC {
			return nil, invalid("entry %d: entries must be sorted by timestamp", i)
		}
		if seen[e.Key()] {
			return nil, invalid("entry %d: sent twice", i)
		}
		seen[e.Key()] = true
		if since.Holds(origin, e.HLC) {
			return nil, invalid("entry %d: not after the state the page was computed from", i)
		}
		origins[origin] = true
	}
	return origins, nil
}
