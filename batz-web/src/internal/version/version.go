// Package version exposes the build identity of the running binary.
package version

import (
	"regexp"
	"strconv"
)

// Version is the version the binary was built from ("v0.1.0",
// "v0.1.0-3-gabc1234"). It is injected at build time with
//
//	go build -ldflags "-X github.com/alkariin/batz/batz-web/internal/version.Version=v0.1.0"
//
// A plain `go build` keeps "dev".
var Version = "dev"

// MinAppVersion is the oldest app version this server works with: 0.10.0 is
// the first that keeps the lines of a transaction split between categories
// when it modifies it; an older one would rewrite it with one line and
// leave the others counted twice. 0.9.0 was the first to read the lines of
// the rules, the fixed amounts of redistribution, the order of the accounts
// and their tax flag, the notes of balances and the links between debts and
// transactions. The app compares it with its own version and refuses to
// synchronise when it is older; the server refuses its exchanges too.
const MinAppVersion = "0.10.0"

var versionPattern = regexp.MustCompile(`^v?(\d+)(?:\.(\d+))?(?:\.(\d+))?`)

// Compare compares two versions such as "0.3.0", "v1.2" or
// "v0.1.0-3-gabc1234" (anything after the numbers is ignored), like the app
// does. ok is false if either cannot be read.
func Compare(a, b string) (result int, ok bool) {
	x, okA := parse(a)
	y, okB := parse(b)
	if !okA || !okB {
		return 0, false
	}
	for i := range 3 {
		if x[i] != y[i] {
			if x[i] < y[i] {
				return -1, true
			}
			return 1, true
		}
	}
	return 0, true
}

func parse(v string) ([3]int, bool) {
	var out [3]int
	m := versionPattern.FindStringSubmatch(v)
	if m == nil {
		return out, false
	}
	for i := range 3 {
		if m[i+1] == "" {
			continue
		}
		n, err := strconv.Atoi(m[i+1])
		if err != nil {
			return out, false
		}
		out[i] = n
	}
	return out, true
}
