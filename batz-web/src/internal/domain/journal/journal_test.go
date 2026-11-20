package journal

import (
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

const devA = "aaaaaaaa-0000-4000-8000-000000000000"

func hlc(millis string, counter string, origin string) string {
	return strings.Repeat("0", 15-len(millis)) + millis + ":" + counter + ":" + origin
}

func entry(h, field, value string) Entry {
	return Entry{HLC: h, Entity: "transaction", RecordID: "t1", Field: field, Value: value}
}

func TestOrigin(t *testing.T) {
	o, err := Origin(hlc("1763647200000", "00ff", devA))
	require.NoError(t, err)
	assert.Equal(t, devA, o)
	for _, bad := range []string{
		"", "1763647200000:0000:" + devA, hlc("1", "00FF", devA), hlc("1", "0000", "ABC"),
		hlc("1", "0000", strings.Repeat("a", 65)), hlc("1", "000", devA),
	} {
		_, err := Origin(bad)
		assert.ErrorIs(t, err, ErrInvalid, bad)
	}
}

func TestEntryValidate(t *testing.T) {
	h := hlc("1000", "0000", devA)
	for _, ok := range []Entry{
		entry(h, "note", `"Légumes"`),
		entry(h, "amount", `-4590`),
		entry(h, "amount", `9223372036854775807`),
		entry(h, "archived", `true`),
		entry(h, "counterpartAccountId", `null`),
		entry(h, DeletedField, `false`),
		entry(h, "note", ` "spaces around" `),
	} {
		origin, err := ok.Validate()
		assert.NoError(t, err, ok)
		assert.Equal(t, devA, origin)
	}
	for _, bad := range []Entry{
		entry("nope", "note", `"x"`),
		{HLC: h, Entity: "Transaction", RecordID: "t1", Field: "note", Value: `"x"`},
		{HLC: h, Entity: "transaction", RecordID: "", Field: "note", Value: `"x"`},
		{HLC: h, Entity: "transaction", RecordID: strings.Repeat("r", 129), Field: "note", Value: `"x"`},
		entry(h, "_other", `"x"`),
		entry(h, "note", ``),
		entry(h, "note", `x`),
		entry(h, "amount", `1.5`),
		entry(h, "amount", `1e3`),
		entry(h, "amount", `9223372036854775808`),
		entry(h, "note", `{"a":1}`),
		entry(h, "note", `[1]`),
		entry(h, "note", `"a" "b"`),
		entry(h, DeletedField, `1`),
		entry(h, DeletedField, `null`),
		entry(h, "note", `"`+strings.Repeat("x", MaxValueBytes)+`"`),
	} {
		_, err := bad.Validate()
		assert.ErrorIs(t, err, ErrInvalid, "%+v", bad)
	}
}

func TestKnownValidate(t *testing.T) {
	assert.NoError(t, Known{devA: hlc("1", "0000", devA)}.Validate())
	assert.NoError(t, Known(nil).Validate())
	assert.ErrorIs(t, Known{"bbbbbbbb": hlc("1", "0000", devA)}.Validate(), ErrInvalid)
	assert.ErrorIs(t, Known{"NOT AN ORIGIN": "x"}.Validate(), ErrInvalid)
	assert.ErrorIs(t, Known{devA: "x"}.Validate(), ErrInvalid)
}

func TestValidatePage(t *testing.T) {
	h1, h2 := hlc("1000", "0000", devA), hlc("2000", "0000", devA)
	origins, err := ValidatePage([]Entry{entry(h1, "note", `"a"`), entry(h1, "amount", `1`), entry(h2, "note", `"b"`)}, nil)
	require.NoError(t, err)
	assert.Equal(t, map[string]bool{devA: true}, origins)

	_, err = ValidatePage([]Entry{entry(h2, "note", `"b"`), entry(h1, "note", `"a"`)}, nil)
	assert.ErrorContains(t, err, "sorted")
	_, err = ValidatePage([]Entry{entry(h1, "note", `"a"`), entry(h1, "note", `"a"`)}, nil)
	assert.ErrorContains(t, err, "twice")
	_, err = ValidatePage([]Entry{entry(h1, "note", `"a"`)}, Known{devA: h1})
	assert.ErrorContains(t, err, "not after")
	_, err = ValidatePage([]Entry{entry(h2, "note", `"b"`)}, Known{devA: h1})
	assert.NoError(t, err)
	_, err = ValidatePage(nil, Known{devA: "bad"})
	assert.ErrorIs(t, err, ErrInvalid)
}
