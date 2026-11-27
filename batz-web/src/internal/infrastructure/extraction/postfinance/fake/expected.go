package fake

import (
	"bytes"
	"encoding/json"
	"strings"
	"time"

	"github.com/alkariin/batz/batz-web/internal/domain/statement"
)

// Expected is what the extraction must give for the fixture, computed from
// what the generator printed rather than from the extraction itself.
func (f Fixture) Expected() statement.Result {
	switch {
	case f.NotStatement:
		return statement.Result{Code: statement.CodeUnknownFormat}
	case f.Refusal != "":
		return statement.Result{Code: statement.CodeInconsistent, Check: f.Refusal}
	}
	st := f.Statement.Expected()
	return statement.Result{Accepted: true, Statement: &st}
}

// ExpectedJSON is Expected as `batz-web extract` prints it.
func (f Fixture) ExpectedJSON() []byte {
	var b bytes.Buffer
	enc := json.NewEncoder(&b)
	enc.SetIndent("", "  ")
	enc.SetEscapeHTML(false)
	if err := enc.Encode(f.Expected()); err != nil {
		panic(err)
	}
	return b.Bytes()
}

// Expected is the statement as printed, for a statement without
// corruption.
func (s Statement) Expected() statement.Statement {
	st := statement.Statement{
		Format:         "postfinance",
		IBAN:           strings.ReplaceAll(s.IBAN, " ", ""),
		Currency:       s.Currency,
		PeriodStart:    dateOf(s.Start),
		PeriodEnd:      dateOf(s.End),
		OpeningBalance: statement.Amount(s.Opening),
		ClosingBalance: statement.Amount(s.Closing()),
		Lines:          []statement.Line{},
	}
	balance := s.Opening
	var credits, debits int64
	for i, e := range s.Entries {
		balance += e.Amount
		if e.Amount > 0 {
			credits += e.Amount
		} else {
			debits -= e.Amount
		}
		line := statement.Line{
			Date:    dateOf(e.Date),
			Amount:  e.Amount,
			RawText: strings.Join(e.Text, "\n"),
			Label:   e.Label,
		}
		if i == len(s.Entries)-1 || !s.Entries[i+1].Date.Equal(e.Date) {
			b := balance
			line.Balance = &b
		}
		st.Lines = append(st.Lines, line)
	}
	st.TotalCredits, st.TotalDebits = statement.Amount(credits), statement.Amount(debits)
	return st
}

func dateOf(t time.Time) statement.Date {
	return statement.Date{Year: t.Year(), Month: t.Month(), Day: t.Day()}
}
