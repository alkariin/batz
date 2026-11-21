package postfinance

import (
	"regexp"
	"strings"
)

// The generic lines of a PostFinance text, the same for every client: the
// type of operation and its date, the card number, the IBAN of the other
// party, the heading before the name of who sent a credit.
var (
	// « ACHAT/SERVICE DU 05.01.2026 », « ACHAT/PRESTATION TWINT DU »,
	// « ENVOI D'ARGENT TWINT DU 09.01.2026 »: upper-case words ending with
	// « DU » and maybe the date.
	operationDuRe = regexp.MustCompile(`^[A-ZÀ-ÖØ-Þ][A-ZÀ-ÖØ-Þ/'’ .-]* DU(?: \d{2}\.\d{2}\.\d{4})?$`)
	// Operation types printed alone on their line.
	operationRe = regexp.MustCompile(`^(?:DÉBIT|CRÉDIT|CRÉDIT POSTFINANCE CARD|PRIX POUR)$`)
	// The date of the operation, on the line after its type.
	operationDateRe = regexp.MustCompile(`^(?:DU )?\d{2}\.\d{2}\.\d{4}$`)
	cardRe          = regexp.MustCompile(`^CARTE N(?:O|°) [X\d]+$`)
	ibanLineRe      = regexp.MustCompile(`^[A-Z]{2}\d{2}[0-9A-Z]{11,30}$`)
	orderingRe      = regexp.MustCompile(`^DONNEUR D['’]ORDRE:?$`)
)

// Label is the short label of a movement: its lines without the generic
// ones, joined by spaces, when the module recognises the type of
// operation; otherwise the whole text on one line.
func Label(lines []string) string {
	whole := strings.Join(strings.Fields(strings.Join(lines, " ")), " ")
	if len(lines) == 0 || !(operationDuRe.MatchString(lines[0]) || operationRe.MatchString(lines[0])) {
		return whole
	}
	var kept []string
	for i, line := range lines {
		switch {
		case i == 0:
			continue
		case i == 1 && operationDateRe.MatchString(line):
			continue
		case cardRe.MatchString(line), ibanLineRe.MatchString(line), orderingRe.MatchString(line):
			continue
		}
		kept = append(kept, line)
	}
	if len(kept) == 0 {
		return whole
	}
	return strings.Join(strings.Fields(strings.Join(kept, " ")), " ")
}
