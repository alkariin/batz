// Package fake writes fictitious PostFinance statements: PDF files laid out
// like the real ones (positions measured on real statements, 2026 layout),
// whose content is entirely invented. They are the test set of the
// extraction, in the repository and in the server image.
package fake

import (
	"fmt"
	"strings"
	"time"
)

// Statement is what a fictitious statement shows.
type Statement struct {
	Holder    []string // recipient block of the first page
	Title     string   // account name above the period
	IBAN      string   // as printed, with spaces
	AccountNo string
	BIC       string
	Currency  string
	Start     time.Time
	End       time.Time
	Issued    time.Time
	Opening   int64 // cents
	Entries   []Entry
	// FooterCode is the form code printed vertically in the left margin of
	// every page.
	FooterCode string
	Notes      []string // paragraph after the closing balance

	// Corruptions, for the statements that must be refused.
	PrintedCredits *int64 // printed total of credits, instead of the sum
	PrintedDebits  *int64
	PrintedClosing *int64 // printed closing balance, instead of the computed one
}

// Entry is one movement.
type Entry struct {
	Date   time.Time // booking date (column « Date »)
	Value  time.Time // value date; Date when zero
	Amount int64     // signed cents: positive for a credit
	Text   []string  // the lines of the « Texte » column
	// Label is the short label the extraction must give: the text
	// without its generic lines.
	Label string

	// Printed is the amount printed instead of Amount, to corrupt a line:
	// the balances stay those of the true amounts.
	Printed *int64
	// AtFooter moves the entry down to the top of the vertical footer, so
	// that the footer's top falls between the top of the label and the top
	// of the amount, half a point lower: pdftotext then puts the footer
	// between the label and the amount, as it does on real statements.
	AtFooter bool
	// NewPage starts a page before this entry.
	NewPage bool
}

func (e Entry) value() time.Time {
	if e.Value.IsZero() {
		return e.Date
	}
	return e.Value
}

func (e Entry) printed() int64 {
	if e.Printed != nil {
		return *e.Printed
	}
	return e.Amount
}

// Geometry measured on real statements (points from the top-left corner).
const (
	bodySize   = 8.5
	labelSize  = 6.4
	titleSize  = 12.8
	lineHeight = 12.0
	entryGap   = 4.39 // between two entries

	dateX    = 65.17
	textX    = 127.56
	creditR  = 354.3 // right edge of the credit column
	debitR   = 433.69
	valueR   = 487.52
	balanceR = 564.05
	labelR   = 118.0 // right edge of the labels of the first page's header

	firstRowTop  = 454.62 // first page
	nextRowTop   = 120.34 // other pages
	rowBottom    = 790.0  // no line of text below this
	footerX      = 15.34
	footerBottom = 728.5 // the footer reads upwards from there
	footerSize   = 6.5
	pageTop      = 809.25
	pageR        = 561.22
)

// PDF renders s.
func (s Statement) PDF() []byte {
	var pages []*page
	newPage := func() *page {
		p := &page{}
		pages = append(pages, p)
		if len(pages) == 1 {
			s.firstHeader(p)
		} else {
			s.nextHeader(p)
			s.columns(p, 105.64)
		}
		return p
	}
	p := newPage()
	top := firstRowTop

	// Opening balance.
	p.add(regular, bodySize, dateX, top, short(s.Start))
	p.add(regular, bodySize, textX, top, "Etat de compte")
	p.right(regular, bodySize, balanceR, top, amount(s.Opening))
	top += lineHeight + entryGap

	balance := s.Opening
	var credits, debits int64
	var day time.Time
	for i, e := range s.Entries {
		height := float64(len(e.Text)) * lineHeight
		if e.NewPage || top+height > rowBottom {
			p = newPage()
			top = nextRowTop
		}
		if e.AtFooter {
			// pdftotext puts the top of a line of text half a point below
			// the top used here: the label's top lands 0.3 point above the
			// footer's, the amount's 0.25 point below it.
			top = max(top, s.footerUpper()-0.85)
		}
		balance += e.Amount
		if e.printed() > 0 {
			credits += e.printed()
		} else {
			debits -= e.printed()
		}
		// As measured: the date, the amount and the balance sit half a
		// point lower than the first line of text.
		if !e.Date.Equal(day) {
			p.add(regular, bodySize, dateX, top+0.43, short(e.Date))
			day = e.Date
		}
		for j, line := range e.Text {
			p.add(regular, bodySize, textX, top+float64(j)*lineHeight, line)
		}
		column := debitR
		if e.printed() > 0 {
			column = creditR
		}
		p.right(regular, bodySize, column, top+0.57, amount(abs(e.printed())))
		p.right(regular, bodySize, valueR, top+0.42, short(e.value()))
		// The balance is printed after the last movement of each day.
		if i == len(s.Entries)-1 || !s.Entries[i+1].Date.Equal(e.Date) {
			p.right(regular, bodySize, balanceR, top+0.57, amount(balance))
		}
		top += height + entryGap
	}

	// Totals and closing balance.
	if top+2*lineHeight > rowBottom {
		p = newPage()
		top = nextRowTop
	}
	if s.PrintedCredits != nil {
		credits = *s.PrintedCredits
	}
	if s.PrintedDebits != nil {
		debits = *s.PrintedDebits
	}
	closing := balance
	if s.PrintedClosing != nil {
		closing = *s.PrintedClosing
	}
	p.add(regular, bodySize, textX, top, "Total")
	if credits != 0 {
		p.right(regular, bodySize, creditR, top+0.25, amount(credits))
	}
	if debits != 0 {
		p.right(regular, bodySize, debitR, top+0.25, amount(debits))
	}
	top += lineHeight + 2.7
	p.add(regular, bodySize, dateX, top, short(s.End))
	p.add(regular, bodySize, textX, top, "Etat de compte")
	p.right(regular, bodySize, balanceR, top, amount(closing))

	// Notes, on a page of their own as on real statements.
	if len(s.Notes) > 0 {
		p = &page{}
		pages = append(pages, p)
		s.nextHeader(p)
		for i, line := range s.Notes {
			p.add(regular, 7.9, textX, 99.49+float64(i)*11.4, line)
		}
	}

	for i, p := range pages {
		p.texts = append(p.texts, text{font: regular, size: footerSize, x: footerX, top: footerBottom, s: s.FooterCode, rotated: true})
		p.right(regular, 7.9, pageR, pageTop, fmt.Sprintf("Page %d / %d", i+1, len(pages)))
	}
	return render(pages)
}

// footerUpper is the top of the vertical footer.
func (s Statement) footerUpper() float64 {
	return footerBottom - width(regular, footerSize, s.FooterCode)
}

func (s Statement) firstHeader(p *page) {
	// Bank block (invented), recipient block, title and period.
	for i, line := range []string{"Banque postale fictive", "Service clients", "Tél. +41 00 000 00 00", "www.banque-fictive.example"} {
		p.add(regular, 5.8, 62.5, 85.33+float64(i)*8.5, line)
	}
	for i, line := range s.Holder {
		p.add(regular, 7.9, 283.46, 180.98+float64(i)*11, line)
	}
	p.add(bold, titleSize, textX, 311.9, s.Title)
	p.add(regular, bodySize, textX, 329.82, fmt.Sprintf("Extrait de compte %s - %s", long(s.Start), long(s.End)))
	rows := [][2]string{
		{"IBAN", s.IBAN + " " + s.Currency},
		{"Numéro de compte", s.AccountNo},
		{"BIC", s.BIC},
		{"Date", long(s.Issued)},
	}
	for i, row := range rows {
		top := 364.49 + float64(i)*12.78
		p.right(regular, labelSize, labelR, top, row[0])
		p.add(regular, bodySize, 127.02, top-1.74, row[1])
	}
	s.columns(p, 441.47)
}

func (s Statement) nextHeader(p *page) {
	rows := [][2]string{{"Date", long(s.Issued)}, {"IBAN", s.IBAN}, {"Numéro de compte", s.AccountNo}}
	for i, row := range rows {
		top := 60.71 + float64(i)*12
		p.right(regular, labelSize, 113.34, top, row[0])
		p.add(regular, bodySize, textX, top-1.6, row[1])
	}
}

func (s Statement) columns(p *page, top float64) {
	p.add(regular, labelSize, dateX, top, "Date")
	p.add(regular, labelSize, textX, top, "Texte")
	p.right(regular, labelSize, creditR, top, "Crédit")
	p.right(regular, labelSize, debitR, top, "Débit")
	p.right(regular, labelSize, valueR, top, "Valeur")
	p.right(regular, labelSize, balanceR, top, "Solde")
}

// amount prints cents as PostFinance does: 12 345.67, -12.30.
func amount(cents int64) string {
	sign := ""
	if cents < 0 {
		sign, cents = "-", -cents
	}
	units := fmt.Sprintf("%d", cents/100)
	var groups []string
	for len(units) > 3 {
		groups = append([]string{units[len(units)-3:]}, groups...)
		units = units[:len(units)-3]
	}
	groups = append([]string{units}, groups...)
	return fmt.Sprintf("%s%s.%02d", sign, strings.Join(groups, " "), cents%100)
}

func abs(n int64) int64 {
	if n < 0 {
		return -n
	}
	return n
}

func short(t time.Time) string { return t.Format("02.01.06") }
func long(t time.Time) string  { return t.Format("02.01.2006") }
