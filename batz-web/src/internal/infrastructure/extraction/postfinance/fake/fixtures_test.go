package fake

import (
	"bytes"
	"flag"
	"os"
	"path/filepath"
	"testing"
)

var update = flag.Bool("update", false, "write the fixtures to ../testdata")

// The committed test set is exactly what the generator writes: regenerate it
// with
//
//	go test ./internal/infrastructure/extraction/postfinance/fake -update
func TestFixturesAreUpToDate(t *testing.T) {
	dir := filepath.Join("..", "testdata")
	for _, f := range Fixtures() {
		path := filepath.Join(dir, f.Name+".pdf")
		want := f.PDF()
		if !bytes.Equal(want, f.PDF()) {
			t.Fatalf("%s: two renderings differ", f.Name)
		}
		if *update {
			if err := os.MkdirAll(dir, 0o755); err != nil {
				t.Fatal(err)
			}
			if err := os.WriteFile(path, want, 0o644); err != nil {
				t.Fatal(err)
			}
			continue
		}
		got, err := os.ReadFile(path)
		if err != nil {
			t.Fatalf("%s: %v (run with -update)", f.Name, err)
		}
		if !bytes.Equal(got, want) {
			t.Errorf("%s: testdata is out of date (run with -update)", f.Name)
		}
	}
}

func TestConsecutiveMonthsAndCorruptions(t *testing.T) {
	fixtures := map[string]Fixture{}
	for _, f := range Fixtures() {
		fixtures[f.Name] = f
	}
	jan, feb, mar := fixtures["2026-01"].Statement, fixtures["2026-02"].Statement, fixtures["2026-03"].Statement
	if feb.Opening != jan.Closing() || mar.Opening != feb.Closing() {
		t.Error("the months must follow each other in balance")
	}
	if !feb.Start.Equal(jan.End.AddDate(0, 0, 1)) || !mar.Start.Equal(feb.End.AddDate(0, 0, 1)) {
		t.Error("the months must follow each other in dates")
	}
	other := fixtures["other-account-2026-04"].Statement
	if other.Opening != mar.Closing() || other.IBAN == mar.IBAN {
		t.Error("the other account continues March, under another IBAN")
	}
	for _, name := range []string{"inconsistent-amount", "inconsistent-total", "inconsistent-balance"} {
		if fixtures[name].Refusal == "" {
			t.Errorf("%s must name the check that refuses it", name)
		}
	}
}

func TestAmount(t *testing.T) {
	for cents, want := range map[int64]string{
		0: "0.00", 5: "0.05", 1250: "12.50", 165000: "1 650.00", 123456789: "1 234 567.89", -4785: "-47.85",
	} {
		if got := amount(cents); got != want {
			t.Errorf("amount(%d) = %q, want %q", cents, got, want)
		}
	}
}

func TestEscape(t *testing.T) {
	if got, want := escape("Épicerie (Coin) \\ 5°"), `\311picerie \(Coin\) \\ 5\260`; got != want {
		t.Errorf("escape = %q, want %q", got, want)
	}
}
