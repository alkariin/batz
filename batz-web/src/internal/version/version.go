// Package version exposes the build identity of the running binary.
package version

// Version is the version the binary was built from ("v0.1.0",
// "v0.1.0-3-gabc1234"). It is injected at build time with
//
//	go build -ldflags "-X github.com/alkariin/batz/batz-web/internal/version.Version=v0.1.0"
//
// A plain `go build` keeps "dev".
var Version = "dev"

// MinAppVersion is the oldest app version this server works with. The app
// compares it with its own version and warns when it is too old.
const MinAppVersion = "0.1.0"
