// Package postfinance reads the PDF statements of PostFinance, in French:
// the text comes from `pdftotext -layout`, run without a shell, with a time
// limit.
package postfinance

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"os/exec"
	"time"

	"github.com/alkariin/batz/batz-web/internal/domain/statement"
)

// Format is the name of the format, as the app stores it on the account.
const Format = "postfinance"

// DefaultTimeout bounds one run of pdftotext.
const DefaultTimeout = 30 * time.Second

// maxText bounds the text pdftotext may write: a statement of a month is a
// few dozen kilobytes.
const maxText = 8 << 20

// Extractor reads a statement with pdftotext.
type Extractor struct {
	// Command is the pdftotext executable, looked up in PATH.
	Command string
	Timeout time.Duration
}

// New returns an extractor running "pdftotext" from PATH.
func New() *Extractor { return &Extractor{Command: "pdftotext", Timeout: DefaultTimeout} }

// Available reports whether pdftotext can be found.
func (x *Extractor) Available() error {
	_, err := exec.LookPath(x.Command)
	return err
}

// Extract reads pdf and checks its consistency. It returns
// statement.ErrUnreadable for a file pdftotext cannot read (or that is no
// PDF), statement.ErrUnknownFormat for a PDF that is no PostFinance
// statement, and an *statement.InconsistentError naming the failed check.
// Errors never quote the text of the statement.
func (x *Extractor) Extract(ctx context.Context, pdf []byte) (statement.Statement, error) {
	if !bytes.HasPrefix(pdf, []byte("%PDF-")) {
		return statement.Statement{}, statement.ErrUnreadable
	}
	text, err := x.text(ctx, pdf)
	if err != nil {
		return statement.Statement{}, err
	}
	st, err := Parse(text)
	if err != nil {
		return statement.Statement{}, err
	}
	if err := st.Check(); err != nil {
		return statement.Statement{}, err
	}
	return st, nil
}

// text runs pdftotext, the PDF on its standard input and the text on its
// standard output: nothing is written to disk.
func (x *Extractor) text(ctx context.Context, pdf []byte) (string, error) {
	ctx, cancel := context.WithTimeout(ctx, x.Timeout)
	defer cancel()
	cmd := exec.CommandContext(ctx, x.Command, "-layout", "-enc", "UTF-8", "-q", "-", "-")
	cmd.Stdin = bytes.NewReader(pdf)
	var out limitedBuffer
	out.limit = maxText
	cmd.Stdout = &out
	err := cmd.Run()
	var exit *exec.ExitError
	switch {
	case ctx.Err() != nil:
		return "", fmt.Errorf("%w: pdftotext did not finish in %s", statement.ErrUnreadable, x.Timeout)
	case errors.As(err, &exit):
		return "", fmt.Errorf("%w: pdftotext exited with code %d", statement.ErrUnreadable, exit.ExitCode())
	case err != nil:
		return "", fmt.Errorf("run pdftotext: %w", err)
	case out.overflow:
		return "", fmt.Errorf("%w: more than %d bytes of text", statement.ErrUnreadable, maxText)
	}
	return out.String(), nil
}

// limitedBuffer keeps at most limit bytes and remembers it was cut.
type limitedBuffer struct {
	bytes.Buffer
	limit    int
	overflow bool
}

func (b *limitedBuffer) Write(p []byte) (int, error) {
	if room := b.limit - b.Len(); len(p) > room {
		b.overflow = true
		if room > 0 {
			b.Buffer.Write(p[:room])
		}
		return len(p), nil
	}
	return b.Buffer.Write(p)
}
