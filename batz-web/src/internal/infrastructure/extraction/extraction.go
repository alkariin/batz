// Package extraction reads a statement file in any format the server knows,
// told by its content: a PDF statement of PostFinance, or a CSV export of
// Neon.
package extraction

import (
	"bytes"
	"context"

	"github.com/alkariin/batz/batz-web/internal/domain/statement"
	"github.com/alkariin/batz/batz-web/internal/infrastructure/extraction/neon"
	"github.com/alkariin/batz/batz-web/internal/infrastructure/extraction/postfinance"
)

// Extractor hands a file to the module of its format.
type Extractor struct {
	PostFinance *postfinance.Extractor
	Neon        *neon.Extractor
}

// New returns an extractor running "pdftotext" from PATH for the PDF files.
func New() *Extractor { return &Extractor{PostFinance: postfinance.New(), Neon: neon.New()} }

// Formats are the formats read, as /healthz announces them.
func (x *Extractor) Formats() []string { return []string{postfinance.Format, neon.Format} }

// Available reports whether the tools of every format can be found.
func (x *Extractor) Available() error { return x.PostFinance.Available() }

// Extract reads file with the module of its format: a PDF goes to
// PostFinance (statement.ErrUnreadable when pdftotext cannot read it), a
// Neon export to Neon; any other file is statement.ErrUnknownFormat.
func (x *Extractor) Extract(ctx context.Context, file []byte) (statement.Statement, error) {
	switch {
	case bytes.HasPrefix(file, []byte("%PDF-")):
		return x.PostFinance.Extract(ctx, file)
	case neon.Detect(file):
		return x.Neon.Extract(ctx, file)
	}
	return statement.Statement{}, statement.ErrUnknownFormat
}
