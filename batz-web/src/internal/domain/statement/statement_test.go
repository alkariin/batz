package statement

import (
	"errors"
	"fmt"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func d(day int) Date { return Date{2026, time.March, day} }

func ptr(n int64) *int64 { return &n }

// A consistent statement: opening 1000.00, three movements, closing 1050.00.
func valid() Statement {
	return Statement{
		Format: "postfinance", IBAN: "CH0090000000123456789", Currency: "CHF",
		PeriodStart: d(1), PeriodEnd: d(31), OpeningBalance: 100000, ClosingBalance: 105000,
		TotalCredits: 20000, TotalDebits: 15000,
		Lines: []Line{
			{Date: d(2), Amount: -5000},
			{Date: d(2), Amount: -10000, Balance: ptr(85000)},
			{Date: d(25), Amount: 20000, Balance: ptr(105000)},
		},
	}
}

func check(t *testing.T, s Statement) string {
	t.Helper()
	err := s.Check()
	if err == nil {
		return ""
	}
	var inc *InconsistentError
	require.ErrorAs(t, err, &inc)
	return inc.Check
}

func TestAConsistentStatementPasses(t *testing.T) {
	assert.NoError(t, valid().Check())
	empty := valid()
	empty.Lines, empty.TotalCredits, empty.TotalDebits, empty.ClosingBalance = nil, 0, 0, 100000
	assert.NoError(t, empty.Check(), "a month without movement")
}

func TestEachCheck(t *testing.T) {
	cases := map[string]func(s *Statement){
		CheckCurrency:       func(s *Statement) { s.Currency = "EUR" },
		CheckPeriod:         func(s *Statement) { s.Lines[2].Date = Date{2026, time.April, 1} },
		CheckRunningBalance: func(s *Statement) { s.Lines[1].Balance = ptr(85001) },
		CheckTotals:         func(s *Statement) { s.TotalDebits = 15001 },
		CheckClosingBalance: func(s *Statement) { s.ClosingBalance = 105001 },
	}
	for want, corrupt := range cases {
		t.Run(want, func(t *testing.T) {
			s := valid()
			corrupt(&s)
			assert.Equal(t, want, check(t, s))
		})
	}
}

func TestPeriod(t *testing.T) {
	before := valid()
	before.Lines[0].Date = Date{2026, time.February, 28}
	assert.Equal(t, CheckPeriod, check(t, before), "before the period")

	disorder := valid()
	disorder.Lines[1].Date = d(1)
	assert.Equal(t, CheckPeriod, check(t, disorder), "out of order")

	reversed := valid()
	reversed.PeriodStart, reversed.PeriodEnd = d(31), d(1)
	assert.Equal(t, CheckPeriod, check(t, reversed))

	edges := valid()
	edges.Lines[0].Date, edges.Lines[1].Date, edges.Lines[2].Date = d(1), d(1), d(31)
	assert.NoError(t, edges.Check(), "the first and last days belong to the period")
}

func TestAnAmountChangedFailsAtTheFirstBalanceAfterIt(t *testing.T) {
	s := valid()
	s.Lines[0].Amount = -6000 // the printed totals and balances stay
	err := s.Check()
	var inc *InconsistentError
	require.ErrorAs(t, err, &inc)
	assert.Equal(t, CheckRunningBalance, inc.Check)
	assert.Contains(t, inc.Detail, "line 2")
}

func TestDates(t *testing.T) {
	_, ok := NewDate(2026, time.February, 29)
	assert.False(t, ok)
	leap, ok := NewDate(2028, time.February, 29)
	assert.True(t, ok)
	assert.Equal(t, "2028-02-29", leap.String())
	text, _ := leap.MarshalText()
	assert.Equal(t, "2028-02-29", string(text))
	assert.True(t, d(1).Before(d(2)))
	assert.True(t, Date{2025, time.December, 31}.Before(d(1)))
	assert.False(t, d(2).Before(d(2)))
}

func TestCents(t *testing.T) {
	assert.Equal(t, "-1234.50", Cents(-123450))
	assert.Equal(t, "0.05", Cents(5))
}

func TestRefusal(t *testing.T) {
	code, check, ok := Refusal(fmt.Errorf("wrapped: %w", &InconsistentError{Check: CheckTotals}))
	assert.Equal(t, []any{CodeInconsistent, CheckTotals, true}, []any{code, check, ok})
	code, _, ok = Refusal(fmt.Errorf("x: %w", ErrUnreadable))
	assert.Equal(t, []any{CodeUnreadable, true}, []any{code, ok})
	code, _, ok = Refusal(ErrUnknownFormat)
	assert.Equal(t, []any{CodeUnknownFormat, true}, []any{code, ok})
	_, _, ok = Refusal(errors.New("disk full"))
	assert.False(t, ok)
}
