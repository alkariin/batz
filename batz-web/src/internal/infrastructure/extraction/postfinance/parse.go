package postfinance

import (
	"fmt"
	"regexp"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/alkariin/batz/batz-web/internal/domain/statement"
)

// The text of a statement, as `pdftotext -layout` writes it, is read line by
// line. The method is the one of the original script, proven on real
// statements, with page furniture removed from the labels and the amount
// that pdftotext sometimes separates from its label put back.

const (
	amountPattern = `-?\d{1,3}(?:[ \x{00A0}\x{202F}']\d{3})*\.\d{2}`
	datePattern   = `\d{2}\.\d{2}\.\d{2}`
	longDate      = `\d{2}\.\d{2}\.\d{4}`
)

var (
	headerRe = regexp.MustCompile(`^\s*Date\s+Texte\s+Crédit\s+Débit\s+Valeur\s+Solde\s*$`)
	periodRe = regexp.MustCompile(`Extrait de compte (` + longDate + `) - (` + longDate + `)`)
	// The IBAN, with the currency on the first page.
	ibanRe = regexp.MustCompile(`IBAN\s+([A-Z]{2}\d{2}(?: [0-9A-Z]{4})*(?: [0-9A-Z]{1,3})?)(?:\s+([A-Z]{3}))?\s*$`)
	// A movement: date (first of the day), text, amount, value date and the
	// balance after the last movement of the day.
	movementRe = regexp.MustCompile(`^\s*(?:(` + datePattern + `)\s+)?(\S.*?)\s{2,}(` + amountPattern +
		`)\s+(` + datePattern + `)(?:\s+(` + amountPattern + `))?\s*$`)
	// An amount that pdftotext put on a line of its own, after the vertical
	// footer: its label is the line before.
	detachedRe = regexp.MustCompile(`^\s*(?:(` + datePattern + `)\s+)?(` + amountPattern + `)\s+(` +
		datePattern + `)(?:\s+(` + amountPattern + `))?\s*$`)
	balanceRe = regexp.MustCompile(`^(?:(` + datePattern + `)\s+)?Etat de compte\s+(` + amountPattern + `)$`)
	totalRe   = regexp.MustCompile(`^Total\s+` + amountPattern + `(?:\s+` + amountPattern + `)?$`)
	amountRe  = regexp.MustCompile(amountPattern)

	// Page furniture, repeated on every page: never part of a label.
	furniture = []*regexp.Regexp{
		regexp.MustCompile(`^\d{5} FR \d+\.\d{2}$`), // vertical form code
		regexp.MustCompile(`^Page \d+ / \d+$`),
		regexp.MustCompile(`^Extrait de compte ` + longDate + ` - ` + longDate),
		regexp.MustCompile(`^IBAN\s+[A-Z]{2}\d{2}`),
		regexp.MustCompile(`^Numéro de compte\s+\d`),
		regexp.MustCompile(`^BIC\s+[A-Z0-9]{8,11}$`),
		regexp.MustCompile(`^Date:?\s+` + longDate + `(?:\s+Page \d+ / \d+)?$`),
	}
)

type parser struct {
	st         statement.Statement
	creditCol  int // rune position of the end of « Crédit » on the current page
	debitCol   int
	headerSeen bool
	periodSeen bool
	ibanSeen   bool
	opening    bool
	closing    bool
	totals     bool
	day        *statement.Date
	current    *movement
	movements  []*movement
}

type movement struct {
	date    statement.Date
	amount  int64
	lines   []string
	balance *int64
}

// Parse reads the text of a PostFinance statement. It returns
// statement.ErrUnknownFormat when the text is no PostFinance statement, and an
// *statement.InconsistentError (check « layout ») when it is one but cannot be
// read entirely. It does not check the consistency of the result: see
// statement.Statement.Check.
func Parse(text string) (statement.Statement, error) {
	p := &parser{st: statement.Statement{Format: Format}}
	for _, raw := range strings.Split(text, "\n") {
		if err := p.line(strings.TrimRight(raw, " \t\r\f")); err != nil {
			return statement.Statement{}, err
		}
	}
	return p.finish()
}

func (p *parser) line(line string) error {
	stripped := strings.TrimSpace(strings.Trim(line, "\f"))
	if stripped == "" {
		return nil
	}
	if !p.periodSeen {
		if m := periodRe.FindStringSubmatch(stripped); m != nil {
			start, ok1 := longDateOf(m[1])
			end, ok2 := longDateOf(m[2])
			if !ok1 || !ok2 {
				return layout("the period cannot be read")
			}
			p.st.PeriodStart, p.st.PeriodEnd, p.periodSeen = start, end, true
		}
	}
	// The IBAN of the account: in the header of the first page, where other
	// text may share its line, then at the start of a line on every page.
	if !p.headerSeen || strings.HasPrefix(stripped, "IBAN") {
		if err := p.iban(stripped); err != nil {
			return err
		}
	}
	if headerRe.MatchString(line) {
		// Columns move from one page to the next: amounts are placed by the
		// nearest end of column header.
		p.creditCol = runeIndex(line, "Crédit") + utf8.RuneCountInString("Crédit")
		p.debitCol = runeIndex(line, "Débit") + utf8.RuneCountInString("Débit")
		p.headerSeen = true
		return nil
	}
	if !p.headerSeen || p.closing {
		return nil // the address block before the first table; notes after it
	}
	for _, re := range furniture {
		if re.MatchString(stripped) {
			return nil
		}
	}
	if m := balanceRe.FindStringSubmatch(stripped); m != nil {
		amount, err := cents(m[2])
		if err != nil {
			return err
		}
		if !p.opening {
			p.st.OpeningBalance, p.opening = amount, true
		} else {
			p.st.ClosingBalance, p.closing = amount, true
		}
		p.current = nil
		return nil
	}
	if totalRe.MatchString(stripped) {
		for _, loc := range amountRe.FindAllStringIndex(line, -1) {
			amount, err := cents(line[loc[0]:loc[1]])
			if err != nil {
				return err
			}
			if p.isCredit(utf8.RuneCountInString(line[:loc[1]])) {
				p.st.TotalCredits = amount
			} else {
				p.st.TotalDebits = amount
			}
		}
		p.totals = true
		p.current = nil
		return nil
	}
	if p.totals {
		return nil
	}

	if m := detachedRe.FindStringSubmatchIndex(line); m != nil {
		// Its label is the last line read, appended to the movement before.
		if p.current == nil || len(p.current.lines) < 2 {
			return layout("an amount without a label after line %d", len(p.movements))
		}
		head := p.current.lines[len(p.current.lines)-1]
		p.current.lines = p.current.lines[:len(p.current.lines)-1]
		return p.movement(line, m[2:4], head, m[4:6], m[8:10])
	}
	if m := movementRe.FindStringSubmatchIndex(line); m != nil {
		return p.movement(line, m[2:4], line[m[4]:m[5]], m[6:8], m[10:12])
	}
	if p.current != nil {
		p.current.lines = append(p.current.lines, stripped)
	}
	return nil
}

func (p *parser) iban(stripped string) error {
	m := ibanRe.FindStringSubmatch(stripped)
	if m == nil {
		return nil
	}
	iban := strings.ReplaceAll(m[1], " ", "")
	if p.ibanSeen && iban != p.st.IBAN {
		return layout("two different IBANs in one statement")
	}
	p.st.IBAN, p.ibanSeen = iban, true
	if m[2] != "" && p.st.Currency == "" {
		p.st.Currency = m[2]
	}
	return nil
}

// movement starts a movement from the submatch positions of its date,
// amount and balance in line.
func (p *parser) movement(line string, dateLoc []int, text string, amountLoc, balanceLoc []int) error {
	if !p.opening {
		return layout("a movement before the opening balance")
	}
	if dateLoc[0] >= 0 {
		d, ok := shortDateOf(line[dateLoc[0]:dateLoc[1]])
		if !ok {
			return layout("a date cannot be read after line %d", len(p.movements))
		}
		p.day = &d
	}
	if p.day == nil {
		return layout("the first movement has no date")
	}
	amount, err := cents(line[amountLoc[0]:amountLoc[1]])
	if err != nil {
		return err
	}
	if amount < 0 {
		return layout("a negative amount in a column at line %d", len(p.movements)+1)
	}
	if !p.isCredit(utf8.RuneCountInString(line[:amountLoc[1]])) {
		amount = -amount
	}
	m := &movement{date: *p.day, amount: amount, lines: []string{strings.TrimSpace(text)}}
	if balanceLoc[0] >= 0 {
		b, err := cents(line[balanceLoc[0]:balanceLoc[1]])
		if err != nil {
			return err
		}
		m.balance = &b
	}
	p.movements = append(p.movements, m)
	p.current = m
	return nil
}

// isCredit tells whether an amount ending at rune position end is in the
// credit column rather than the debit one.
func (p *parser) isCredit(end int) bool {
	return abs(end-p.creditCol) < abs(end-p.debitCol)
}

func (p *parser) finish() (statement.Statement, error) {
	if !p.headerSeen && !p.periodSeen {
		return statement.Statement{}, statement.ErrUnknownFormat
	}
	switch {
	case !p.periodSeen:
		return statement.Statement{}, layout("the period is missing")
	case !p.ibanSeen:
		return statement.Statement{}, layout("the IBAN is missing")
	case !p.headerSeen:
		return statement.Statement{}, layout("the table of movements is missing")
	case !p.opening:
		return statement.Statement{}, layout("the opening balance is missing")
	case !p.closing:
		return statement.Statement{}, layout("the closing balance is missing")
	case !p.totals && len(p.movements) > 0:
		return statement.Statement{}, layout("the totals are missing")
	}
	p.st.Lines = make([]statement.Line, len(p.movements))
	for i, m := range p.movements {
		p.st.Lines[i] = statement.Line{
			Date:    m.date,
			Amount:  m.amount,
			RawText: strings.Join(m.lines, "\n"),
			Label:   Label(m.lines),
			Balance: m.balance,
		}
	}
	return p.st, nil
}

func layout(format string, args ...any) error {
	return &statement.InconsistentError{Check: statement.CheckLayout, Detail: fmt.Sprintf(format, args...)}
}

// cents reads 12 345.67 (thousands separated by a space, a no-break space or
// an apostrophe), without floating point.
func cents(s string) (int64, error) {
	clean := strings.Map(func(r rune) rune {
		switch r {
		case ' ', ' ', ' ', '\'':
			return -1
		}
		return r
	}, s)
	negative := strings.HasPrefix(clean, "-")
	clean = strings.TrimPrefix(clean, "-")
	units, fraction, ok := strings.Cut(clean, ".")
	if !ok || len(fraction) != 2 {
		return 0, layout("an amount cannot be read")
	}
	u, err1 := strconv.ParseInt(units, 10, 64)
	f, err2 := strconv.ParseInt(fraction, 10, 64)
	if err1 != nil || err2 != nil || u > 1e12 {
		return 0, layout("an amount cannot be read")
	}
	v := u*100 + f
	if negative {
		v = -v
	}
	return v, nil
}

func longDateOf(s string) (statement.Date, bool) {
	t, err := time.Parse("02.01.2006", s)
	if err != nil {
		return statement.Date{}, false
	}
	return statement.NewDate(t.Year(), t.Month(), t.Day())
}

// shortDateOf reads dd.mm.yy, in this century.
func shortDateOf(s string) (statement.Date, bool) {
	d, err1 := strconv.Atoi(s[0:2])
	m, err2 := strconv.Atoi(s[3:5])
	y, err3 := strconv.Atoi(s[6:8])
	if err1 != nil || err2 != nil || err3 != nil {
		return statement.Date{}, false
	}
	return statement.NewDate(2000+y, time.Month(m), d)
}

func runeIndex(s, sub string) int {
	i := strings.Index(s, sub)
	if i < 0 {
		return -1
	}
	return utf8.RuneCountInString(s[:i])
}

func abs(n int) int {
	if n < 0 {
		return -n
	}
	return n
}
