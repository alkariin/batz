package fake

import (
	"fmt"
	"strings"
	"time"
)

// Fixture is one file of the test set.
type Fixture struct {
	Name      string // file name in testdata, without extension
	Statement Statement
	// Refusal is the check that must refuse the statement ("" when it is
	// accepted); NotStatement marks a file that is no statement at all.
	Refusal      string
	NotStatement bool
	// Other is a file that is not a statement, when NotStatement.
	Other []byte
}

// PDF is the file of the fixture.
func (f Fixture) PDF() []byte {
	if f.NotStatement {
		return f.Other
	}
	return f.Statement.PDF()
}

// The fictitious account holder and accounts.
var (
	holder      = []string{"Camille Exemple", "Chemin des Essais 7", "9999 Fictiville"}
	mainIBAN    = "CH00 9000 0000 1234 5678 9"
	otherIBAN   = "CH00 9000 0000 9876 5432 1"
	footerCode  = "12345 FR 000000.00"
	cardNumber  = "XXXX0000"
	notesOfBank = []string{
		"Merci de contrôler cet extrait. Toute contestation doit nous parvenir dans les trente jours,",
		"faute de quoi il est réputé accepté.",
		"",
		"Ce document fictif sert aux tests de batz.",
	}
)

func day(y int, m time.Month, d int) time.Time { return time.Date(y, m, d, 0, 0, 0, 0, time.UTC) }

// Builders of the usual movements. The formulas (first lines, card line) are
// those of the bank, the same for all its clients; everything else is
// invented.

func card(date time.Time, cents int64, merchant, city string) Entry {
	bought := date.AddDate(0, 0, -1)
	return Entry{Date: date, Amount: -cents, Text: []string{
		"ACHAT/SERVICE DU " + long(bought), "CARTE NO " + cardNumber, merchant, city,
	}, Label: merchant + " " + city}
}

func online(date time.Time, cents int64, merchant, city string) Entry {
	return Entry{Date: date, Amount: -cents, Text: []string{
		"ACHAT/SHOPPING EN LIGNE DU", long(date.AddDate(0, 0, -2)), "CARTE N° " + cardNumber, merchant, city,
	}, Label: merchant + " " + city}
}

func twint(date time.Time, cents int64, merchant, city string) Entry {
	return Entry{Date: date, Amount: -cents, Text: []string{
		"ACHAT/PRESTATION TWINT DU", long(date), merchant, city,
	}, Label: merchant + " " + city}
}

func twintSent(date time.Time, cents int64, name, phone string, message ...string) Entry {
	text := append([]string{"ENVOI D'ARGENT TWINT DU " + long(date), "POUR " + name, phone}, message...)
	return Entry{Date: date, Amount: -cents, Text: text,
		Label: strings.Join(append([]string{"POUR " + name, phone}, message...), " ")}
}

func twintReceived(date time.Time, cents int64, name, phone string) Entry {
	return Entry{Date: date, Amount: cents, Text: []string{
		"RÉCEPTION D'ARGENT TWINT DU", long(date), "DE " + name, phone,
	}, Label: "DE " + name + " " + phone}
}

func debit(date time.Time, cents int64, iban string, lines ...string) Entry {
	return Entry{Date: date, Amount: -cents, Text: append([]string{"DÉBIT", iban}, lines...),
		Label: strings.Join(lines, " ")}
}

func credit(date time.Time, cents int64, lines ...string) Entry {
	return Entry{Date: date, Amount: cents, Text: append([]string{"CRÉDIT", "DONNEUR D'ORDRE:"}, lines...),
		Label: strings.Join(lines, " ")}
}

func cardRefund(date time.Time, cents int64, merchant, city string) Entry {
	return Entry{Date: date, Amount: cents, Text: []string{
		"CRÉDIT POSTFINANCE CARD", "DU " + long(date.AddDate(0, 0, -3)), "CARTE NO " + cardNumber, merchant, city,
	}, Label: merchant + " " + city}
}

func fee(date time.Time, cents int64, what string) Entry {
	return Entry{Date: date, Amount: -cents, Text: []string{"PRIX POUR", what}, Label: what}
}

func month(m time.Month, opening int64, entries []Entry) Statement {
	start := day(2026, m, 1)
	end := start.AddDate(0, 1, -1)
	return Statement{
		Holder: holder, Title: "Compte privé", IBAN: mainIBAN, AccountNo: "00-123456-7",
		BIC: "POFICHBEXXX", Currency: "CHF", Start: start, End: end, Issued: end.AddDate(0, 0, 1),
		Opening: opening, Entries: entries, FooterCode: footerCode, Notes: notesOfBank,
	}
}

// Closing balance of s, from its true amounts.
func (s Statement) Closing() int64 {
	b := s.Opening
	for _, e := range s.Entries {
		b += e.Amount
	}
	return b
}

const city = "Fictiville"

func january() Statement {
	d := func(n int) time.Time { return day(2026, time.January, n) }
	entries := []Entry{
		debit(d(5), 165000, "CH0000000000000000001", "Gérance Imaginaire SA", "Rue du Bail 3", "9999 Fictiville"),
		card(d(5), 4785, "Épicerie du Coin", city),
		card(d(6), 1250, "Boulangerie des Tests", city),
		twint(d(6), 2400, "Café de la Démo", "9998 Exempleville (CH)"),
		online(d(7), 8990, "Librairie en ligne SA", "Exempleville (CH)"),
		card(d(8), 6320, "Épicerie du Coin", city),
		fee(d(8), 500, "TENUE DE COMPTE 12.2025"),
		// A day that goes on over the next page: its date is printed once.
		card(d(9), 3510, "Pharmacie Modèle", city),
		card(d(9), 1990, "Kiosque Fictif", city),
		twintSent(d(9), 3500, "Dominique Essai.", "+41000000001", ", Repas du", "vendredi"),
	}
	entries[9].NewPage = true
	entries = append(entries,
		card(d(9), 870, "Boulangerie des Tests", city),
		card(d(12), 11245, "Grand Magasin Inventé", city),
		twintReceived(d(13), 4200, "Alex Modèle", "+41000000002"),
		card(d(14), 2560, "Épicerie du Coin", city),
		online(d(15), 4999, "Abonnement Musique SARL", "Exempleville (CH)"),
		debit(d(16), 8950, "CH0000000000000000002", "Assurance Fictive SA", "Case postale 10", "9997 Assuranceville"),
		card(d(19), 7340, "Station Service Inventée", city),
		card(d(20), 1525, "Kiosque Fictif", city),
		cardRefund(d(21), 2999, "Grand Magasin Inventé", city),
		twint(d(22), 1800, "Marché de Fictiville", city),
		card(d(23), 5675, "Épicerie du Coin", city),
		credit(d(23), 580000, "Employeur Fictif SA", "Rue de l'Usine 1", "9999 Fictiville"),
		card(d(26), 23900, "Magasin de Sport Exemple", "9998 Exempleville"),
		card(d(27), 3215, "Épicerie du Coin", city),
		debit(d(28), 50000, "CH0000000000000000003", "Camille Exemple", "Compte épargne"),
		card(d(29), 1470, "Boulangerie des Tests", city),
		twint(d(30), 950, "Parking de la Gare", city),
	)
	// An amount that pdftotext separates from its label by the footer,
	// without a date: a second movement of the day.
	entries[10].AtFooter = true
	return month(time.January, 234567, entries)
}

func february(opening int64) Statement {
	d := func(n int) time.Time { return day(2026, time.February, n) }
	entries := []Entry{
		debit(d(2), 165000, "CH0000000000000000001", "Gérance Imaginaire SA", "Rue du Bail 3", "9999 Fictiville"),
		card(d(2), 3890, "Épicerie du Coin", city),
		twint(d(3), 650, "Café de la Démo", "9998 Exempleville (CH)"),
		card(d(4), 12999, "Grand Magasin Inventé", city),
		card(d(5), 2100, "Pharmacie Modèle", city),
		fee(d(6), 500, "TENUE DE COMPTE 01.2026"),
		card(d(9), 4560, "Épicerie du Coin", city),
		twintSent(d(10), 2000, "Dominique Essai.", "+41000000001", ", Cinéma"),
		card(d(11), 1380, "Boulangerie des Tests", city),
		online(d(12), 15900, "Électroménager en ligne SA", "Exempleville (CH)"),
		card(d(13), 7420, "Station Service Inventée", city),
		debit(d(16), 8950, "CH0000000000000000002", "Assurance Fictive SA", "Case postale 10", "9997 Assuranceville"),
		card(d(17), 2875, "Épicerie du Coin", city),
		twintReceived(d(18), 1500, "Alex Modèle", "+41000000002"),
		card(d(19), 990, "Kiosque Fictif", city),
		fee(d(19), 200, "COMMANDE DE CARTE"),
		// A new day whose date and amount pdftotext separates from the label
		// by the footer.
		twintSent(d(20), 4500, "Sacha Témoin.", "+41000000003", ", Cadeau commun"),
		card(d(20), 3105, "Épicerie du Coin", city),
		credit(d(25), 580000, "Employeur Fictif SA", "Rue de l'Usine 1", "9999 Fictiville"),
		card(d(26), 18950, "Magasin de Sport Exemple", "9998 Exempleville"),
		debit(d(27), 50000, "CH0000000000000000003", "Camille Exemple", "Compte épargne"),
	}
	entries[16].AtFooter = true
	return month(time.February, opening, entries)
}

func march(opening int64) Statement {
	d := func(n int) time.Time { return day(2026, time.March, n) }
	entries := []Entry{
		debit(d(2), 165000, "CH0000000000000000001", "Gérance Imaginaire SA", "Rue du Bail 3", "9999 Fictiville"),
		card(d(3), 5230, "Épicerie du Coin", city),
		card(d(4), 1150, "Boulangerie des Tests", city),
		fee(d(6), 500, "TENUE DE COMPTE 02.2026"),
		twint(d(9), 2800, "Marché de Fictiville", city),
		card(d(10), 120000, "Garage Imaginaire", city),
		card(d(12), 4410, "Épicerie du Coin", city),
		debit(d(16), 8950, "CH0000000000000000002", "Assurance Fictive SA", "Case postale 10", "9997 Assuranceville"),
		online(d(18), 6490, "Librairie en ligne SA", "Exempleville (CH)"),
		credit(d(25), 580000, "Employeur Fictif SA", "Rue de l'Usine 1", "9999 Fictiville"),
		card(d(27), 3960, "Épicerie du Coin", city),
		debit(d(30), 50000, "CH0000000000000000003", "Camille Exemple", "Compte épargne"),
	}
	return month(time.March, opening, entries)
}

// otherAccount continues March in balance and dates, on another account.
func otherAccount(opening int64) Statement {
	d := func(n int) time.Time { return day(2026, time.April, n) }
	s := month(time.April, opening, []Entry{
		card(d(2), 2450, "Épicerie du Coin", city),
		card(d(7), 1890, "Boulangerie des Tests", city),
		credit(d(24), 580000, "Employeur Fictif SA", "Rue de l'Usine 1", "9999 Fictiville"),
	})
	s.IBAN = otherIBAN
	s.AccountNo = "00-987654-3"
	return s
}

func ptr(n int64) *int64 { return &n }

// Fixtures is the test set: three consecutive months, a statement of
// another account, three inconsistent statements and a file that is no
// statement.
func Fixtures() []Fixture {
	jan := january()
	feb := february(jan.Closing())
	mar := march(feb.Closing())

	amount := february(jan.Closing())
	amount.Entries[4].Printed = ptr(amount.Entries[4].Amount - 1000) // 10.00 more printed than booked

	total := february(jan.Closing())
	total.PrintedDebits = ptr(debitsOf(total) + 100)

	balance := february(jan.Closing())
	balance.PrintedClosing = ptr(balance.Closing() + 5)

	return []Fixture{
		{Name: "2026-01", Statement: jan},
		{Name: "2026-02", Statement: feb},
		{Name: "2026-03", Statement: mar},
		{Name: "other-account-2026-04", Statement: otherAccount(mar.Closing())},
		{Name: "inconsistent-amount", Statement: amount, Refusal: "runningBalance"},
		{Name: "inconsistent-total", Statement: total, Refusal: "totals"},
		{Name: "inconsistent-balance", Statement: balance, Refusal: "closingBalance"},
		{Name: "not-a-statement", NotStatement: true, Other: notAStatement()},
	}
}

func debitsOf(s Statement) int64 {
	var total int64
	for _, e := range s.Entries {
		if e.Amount < 0 {
			total -= e.Amount
		}
	}
	return total
}

// notAStatement is an invoice: a PDF, but no statement.
func notAStatement() []byte {
	p := &page{}
	p.add(bold, 14, 62, 80, "Facture n° 2026-0042")
	for i, line := range []string{
		"Atelier Fictif Sàrl, Rue de l'Exemple 5, 9999 Fictiville",
		"Date 12.03.2026",
		"Réparation d'un vélo                                  120.00",
		"Total CHF                                             120.00",
		"Payable dans les 30 jours. Merci de votre confiance.",
	} {
		p.add(regular, 10, 62, 120+float64(i)*16, line)
	}
	return render([]*page{p})
}

// String describes a fixture, for test names.
func (f Fixture) String() string { return fmt.Sprintf("fixture %s", f.Name) }
