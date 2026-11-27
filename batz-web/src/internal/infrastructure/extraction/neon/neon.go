// Package neon reads the CSV exports of transactions of Neon: one line per
// transaction, the most recent first, fields quoted and separated by
// semicolons, after a header line. An export prints no balance: the app
// checks it against the balance the user types.
package neon

import (
	"bytes"
	"context"
	"encoding/csv"
	"errors"
	"fmt"
	"io"
	"regexp"
	"slices"
	"strconv"
	"strings"
	"time"

	"github.com/alkariin/batz/batz-web/internal/domain/statement"
)

// Format is the name of the format, as the app stores it on the account.
const Format = "neon"

// The columns read, by their name in the header; the others (Neon's own
// category, tags, Wise, Spaces) are left out: the user can change them in
// Neon, and the text of a line must not change from one export to the next.
const (
	colDate             = "Date"
	colAmount           = "Amount"
	colOriginalAmount   = "Original amount"
	colOriginalCurrency = "Original currency"
	colDescription      = "Description"
	colSubject          = "Subject"
)

var (
	required = []string{colDate, colAmount, colOriginalAmount, colOriginalCurrency, colDescription, colSubject}
	amountRe = regexp.MustCompile(`^(-?)(\d{1,12})(?:\.(\d{1,2}))?$`)
	spacesRe = regexp.MustCompile(`\s+`)
	bom      = []byte("\xef\xbb\xbf")
)

// Extractor reads an export; it needs no external tool.
type Extractor struct{}

// New returns an extractor.
func New() *Extractor { return &Extractor{} }

// Detect reports whether data is a Neon export: its first line is a header
// that names the columns read.
func Detect(data []byte) bool {
	_, err := header(newReader(data))
	return err == nil
}

// Extract reads data and checks its consistency. It returns
// statement.ErrUnknownFormat for a file that is no Neon export, and an
// *statement.InconsistentError (check « layout ») for an export that
// cannot be read entirely. Errors never quote the text of the export.
func (x *Extractor) Extract(_ context.Context, data []byte) (statement.Statement, error) {
	st, err := Parse(data)
	if err != nil {
		return statement.Statement{}, err
	}
	if err := st.Check(); err != nil {
		return statement.Statement{}, err
	}
	return st, nil
}

func newReader(data []byte) *csv.Reader {
	r := csv.NewReader(bytes.NewReader(bytes.TrimPrefix(data, bom)))
	r.Comma = ';'
	return r
}

// header reads the first line and returns the position of each column read.
func header(r *csv.Reader) (map[string]int, error) {
	names, err := r.Read()
	if err != nil {
		return nil, statement.ErrUnknownFormat
	}
	columns := map[string]int{}
	for i, name := range names {
		columns[strings.TrimSpace(name)] = i
	}
	for _, name := range required {
		if _, ok := columns[name]; !ok {
			return nil, statement.ErrUnknownFormat
		}
	}
	return columns, nil
}

// Parse reads an export into a statement without balances, its lines from
// the oldest to the most recent (the lines of a day keep the order of the
// bank, reversed), its period from the first line to the last.
//
// The raw text of a line is its description, its subject when it has one,
// and for a payment in another currency its original amount and currency
// (« -60.00 DKK »): the exchange rate is left out. The app identifies a
// line by its account, date, amount and raw text, so that an export that
// overlaps an earlier one brings only its new lines: this text must stay
// the same from one version of the server to the next.
func Parse(data []byte) (statement.Statement, error) {
	r := newReader(data)
	columns, err := header(r)
	if err != nil {
		return statement.Statement{}, err
	}
	var lines []statement.Line
	for n := 2; ; n++ {
		record, err := r.Read()
		if errors.Is(err, io.EOF) {
			break
		}
		if err != nil {
			return statement.Statement{}, layout("line %d cannot be read", n)
		}
		field := func(name string) string { return clean(record[columns[name]]) }
		date, ok := dateOf(field(colDate))
		if !ok {
			return statement.Statement{}, layout("the date of line %d cannot be read", n)
		}
		amount, ok := cents(field(colAmount))
		if !ok {
			return statement.Statement{}, layout("the amount of line %d cannot be read", n)
		}
		description, subject := field(colDescription), field(colSubject)
		label := description
		if label == "" {
			label = subject
		}
		if label == "" {
			return statement.Statement{}, layout("line %d has neither description nor subject", n)
		}
		text := []string{label}
		if subject != "" && subject != label {
			text = append(text, subject)
		}
		original, currency := field(colOriginalAmount), field(colOriginalCurrency)
		if original != "" && currency != "" && currency != statement.Currency {
			text = append(text, original+" "+currency)
		}
		lines = append(lines, statement.Line{Date: date, Amount: amount, RawText: strings.Join(text, "\n"), Label: label})
	}
	if len(lines) == 0 {
		return statement.Statement{}, layout("the export holds no transaction")
	}
	slices.Reverse(lines)
	slices.SortStableFunc(lines, func(a, b statement.Line) int {
		switch {
		case a.Date.Before(b.Date):
			return -1
		case b.Date.Before(a.Date):
			return 1
		}
		return 0
	})
	return statement.Statement{
		Format:      Format,
		Currency:    statement.Currency,
		PeriodStart: lines[0].Date,
		PeriodEnd:   lines[len(lines)-1].Date,
		Lines:       lines,
	}, nil
}

// clean trims a field and puts its spaces and line breaks on one line.
func clean(s string) string { return spacesRe.ReplaceAllString(strings.TrimSpace(s), " ") }

func dateOf(s string) (statement.Date, bool) {
	t, err := time.Parse("2006-01-02", s)
	if err != nil {
		return statement.Date{}, false
	}
	return statement.NewDate(t.Year(), t.Month(), t.Day())
}

// cents reads « -12.5 », « -12.50 » or « 12 » without floating point.
func cents(s string) (int64, bool) {
	m := amountRe.FindStringSubmatch(s)
	if m == nil {
		return 0, false
	}
	units, err := strconv.ParseInt(m[2], 10, 64)
	if err != nil {
		return 0, false
	}
	fraction := m[3] + strings.Repeat("0", 2-len(m[3]))
	f, _ := strconv.ParseInt(fraction, 10, 64)
	v := units*100 + f
	if m[1] == "-" {
		v = -v
	}
	return v, true
}

func layout(format string, args ...any) error {
	return &statement.InconsistentError{Check: statement.CheckLayout, Detail: fmt.Sprintf(format, args...)}
}
