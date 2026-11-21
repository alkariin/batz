// Package statement holds a bank statement as read from its file, and the
// checks of its internal consistency. Amounts are integer cents: no floating
// point anywhere.
package statement

import (
	"errors"
	"fmt"
	"time"
)

// Date is a calendar date, without time or time zone; it reads and writes
// as YYYY-MM-DD.
type Date struct {
	Year  int
	Month time.Month
	Day   int
}

// NewDate returns the date, or false if it does not exist.
func NewDate(year int, month time.Month, day int) (Date, bool) {
	t := time.Date(year, month, day, 0, 0, 0, 0, time.UTC)
	if t.Year() != year || t.Month() != month || t.Day() != day {
		return Date{}, false
	}
	return Date{year, month, day}, true
}

func (d Date) String() string { return fmt.Sprintf("%04d-%02d-%02d", d.Year, d.Month, d.Day) }

// MarshalText writes YYYY-MM-DD.
func (d Date) MarshalText() ([]byte, error) { return []byte(d.String()), nil }

// Before reports whether d comes before o.
func (d Date) Before(o Date) bool {
	if d.Year != o.Year {
		return d.Year < o.Year
	}
	if d.Month != o.Month {
		return d.Month < o.Month
	}
	return d.Day < o.Day
}

// Line is one movement of a statement.
type Line struct {
	// Date is the booking date.
	Date Date `json:"date"`
	// Amount is signed: positive for a credit, negative for a debit.
	Amount int64 `json:"amount"`
	// RawText is the bank's text, its lines separated by "\n", page
	// footers removed. The rules of the app read it, never the label.
	RawText string `json:"rawText"`
	// Label is the short label: the text without its generic lines, or the
	// whole text.
	Label string `json:"label"`
	// Balance is the balance printed after this line, when there is one.
	Balance *int64 `json:"balance,omitempty"`
}

// Statement is what a statement file says.
type Statement struct {
	Format string `json:"format"`
	// IBAN is the account's, without spaces.
	IBAN           string `json:"iban"`
	Currency       string `json:"currency"`
	PeriodStart    Date   `json:"periodStart"`
	PeriodEnd      Date   `json:"periodEnd"`
	OpeningBalance int64  `json:"openingBalance"`
	ClosingBalance int64  `json:"closingBalance"`
	// TotalCredits and TotalDebits are the totals printed, both positive.
	TotalCredits int64  `json:"totalCredits"`
	TotalDebits  int64  `json:"totalDebits"`
	Lines        []Line `json:"lines"`
}

// The checks a statement must pass; an InconsistentError names the one that
// failed.
const (
	// CheckLayout: the statement could not be read entirely (a movement
	// without a date or a label, a balance or the totals missing).
	CheckLayout = "layout"
	// CheckCurrency: the account is not in Swiss francs.
	CheckCurrency = "currency"
	// CheckPeriod: a movement outside the period, or out of order.
	CheckPeriod = "period"
	// CheckRunningBalance: a balance printed in the course of the statement
	// differs from the opening balance plus the movements before it.
	CheckRunningBalance = "runningBalance"
	// CheckTotals: the printed totals of credits or debits differ from the
	// movements.
	CheckTotals = "totals"
	// CheckClosingBalance: the opening balance plus the movements differ
	// from the closing balance.
	CheckClosingBalance = "closingBalance"
)

// Currency is the only one batz knows.
const Currency = "CHF"

var (
	// ErrUnreadable means the file is not a PDF that can be read.
	ErrUnreadable = errors.New("the file is not a readable PDF")
	// ErrUnknownFormat means the file is a PDF, but no statement in a format
	// the server knows.
	ErrUnknownFormat = errors.New("the file is not a statement in a known format")
)

// InconsistentError refuses a statement as a whole: Check names the check
// that failed. Detail holds dates, amounts and line numbers, never the
// text of the statement.
type InconsistentError struct {
	Check  string
	Detail string
}

func (e *InconsistentError) Error() string {
	return fmt.Sprintf("inconsistent statement (%s): %s", e.Check, e.Detail)
}

func inconsistent(check, format string, args ...any) error {
	return &InconsistentError{Check: check, Detail: fmt.Sprintf(format, args...)}
}

// Check verifies the internal consistency of s, in this order: currency,
// period, balances printed in its course, totals, closing balance. It
// returns the first failure as an *InconsistentError.
func (s Statement) Check() error {
	if s.Currency != Currency {
		return inconsistent(CheckCurrency, "currency %q, only %s is supported", s.Currency, Currency)
	}
	if s.PeriodEnd.Before(s.PeriodStart) {
		return inconsistent(CheckPeriod, "period ends (%s) before it starts (%s)", s.PeriodEnd, s.PeriodStart)
	}
	for i, l := range s.Lines {
		if l.Date.Before(s.PeriodStart) || s.PeriodEnd.Before(l.Date) {
			return inconsistent(CheckPeriod, "line %d dated %s, outside the period %s to %s",
				i+1, l.Date, s.PeriodStart, s.PeriodEnd)
		}
		if i > 0 && l.Date.Before(s.Lines[i-1].Date) {
			return inconsistent(CheckPeriod, "line %d dated %s, before line %d dated %s",
				i+1, l.Date, i, s.Lines[i-1].Date)
		}
	}
	running := s.OpeningBalance
	var credits, debits int64
	for i, l := range s.Lines {
		running += l.Amount
		if l.Amount > 0 {
			credits += l.Amount
		} else {
			debits -= l.Amount
		}
		if l.Balance != nil && *l.Balance != running {
			return inconsistent(CheckRunningBalance, "balance printed after line %d is %s, the movements give %s",
				i+1, Cents(*l.Balance), Cents(running))
		}
	}
	if credits != s.TotalCredits || debits != s.TotalDebits {
		return inconsistent(CheckTotals, "printed totals: credits %s, debits %s; the movements give credits %s, debits %s",
			Cents(s.TotalCredits), Cents(s.TotalDebits), Cents(credits), Cents(debits))
	}
	if running != s.ClosingBalance {
		return inconsistent(CheckClosingBalance, "opening balance %s plus the movements gives %s, the closing balance is %s",
			Cents(s.OpeningBalance), Cents(running), Cents(s.ClosingBalance))
	}
	return nil
}

// Cents formats an amount of cents for messages: -1234.50.
func Cents(c int64) string {
	sign := ""
	if c < 0 {
		sign, c = "-", -c
	}
	return fmt.Sprintf("%s%d.%02d", sign, c/100, c%100)
}

// Codes of the refusals, the same in the API and in `batz-web extract`.
const (
	CodeUnreadable    = "IMPORT_UNREADABLE"
	CodeUnknownFormat = "IMPORT_UNKNOWN_FORMAT"
	CodeInconsistent  = "IMPORT_INCONSISTENT"
)

// Refusal returns the code of a refusal and, for an inconsistent statement,
// the check that failed; ok is false when err refuses nothing (an internal
// failure).
func Refusal(err error) (code, check string, ok bool) {
	var inc *InconsistentError
	switch {
	case errors.As(err, &inc):
		return CodeInconsistent, inc.Check, true
	case errors.Is(err, ErrUnreadable):
		return CodeUnreadable, "", true
	case errors.Is(err, ErrUnknownFormat):
		return CodeUnknownFormat, "", true
	}
	return "", "", false
}

// Result is the outcome of reading a statement, as `batz-web extract`
// prints it: the statement, or the code and check of the refusal.
type Result struct {
	Accepted  bool       `json:"accepted"`
	Statement *Statement `json:"statement,omitempty"`
	Code      string     `json:"code,omitempty"`
	Check     string     `json:"check,omitempty"`
}
