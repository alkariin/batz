package version

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestCompare(t *testing.T) {
	for _, c := range []struct {
		a, b string
		want int
		ok   bool
	}{
		{"0.3.0", "0.3.0", 0, true},
		{"0.2.0", "0.3.0", -1, true},
		{"v0.10.0", "0.9.9", 1, true},
		{"v0.3.0-2-gabc1234", "0.3.0", 0, true},
		{"0.8.0-alpha", "0.8.0", 0, true},
		{"v0.8.0-alpha", "0.7.0", 1, true},
		{"0.8.0-alpha", "0.8.1", -1, true},
		{"1", "0.9", 1, true},
		{"dev", "0.3.0", 0, false},
		{"", "0.3.0", 0, false},
	} {
		got, ok := Compare(c.a, c.b)
		assert.Equal(t, c.ok, ok, "%s vs %s", c.a, c.b)
		assert.Equal(t, c.want, got, "%s vs %s", c.a, c.b)
	}
}
