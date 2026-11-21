package fake

import (
	"bytes"
	"fmt"
	"strings"
)

// A minimal PDF writer: A4 pages of text in the standard Helvetica fonts,
// WinAnsi encoded. Its output depends only on its input, byte for byte, so
// that the fixtures it writes can be compared with the committed ones.

const (
	pageWidth  = 595.276
	pageHeight = 841.89
)

type font int

const (
	regular font = iota
	bold
)

// text is one string drawn at a position measured from the top-left corner
// of the page, as pdftotext reports it: x is the left edge, top the top of
// the line box.
type text struct {
	font    font
	size    float64
	x, top  float64
	s       string
	rotated bool // 90° counterclockwise, reading upwards
}

type page struct{ texts []text }

func (p *page) add(f font, size, x, top float64, s string) {
	p.texts = append(p.texts, text{font: f, size: size, x: x, top: top, s: s})
}

// right draws s so that it ends at x.
func (p *page) right(f font, size, x, top float64, s string) {
	p.add(f, size, x-width(f, size, s), top, s)
}

// ascent is the share of the font size above the baseline, used to turn the
// top of a line box into a baseline.
const ascent = 0.78

func (p *page) content() []byte {
	var b bytes.Buffer
	for _, t := range p.texts {
		name := "F1"
		if t.font == bold {
			name = "F2"
		}
		baseline := pageHeight - t.top - ascent*t.size
		if t.rotated {
			// The string reads upwards from (x + size, top): its first
			// character is at the bottom.
			fmt.Fprintf(&b, "BT /%s %s Tf 0 1 -1 0 %s %s Tm (%s) Tj ET\n",
				name, num(t.size), num(t.x+ascent*t.size), num(pageHeight-t.top), escape(t.s))
			continue
		}
		fmt.Fprintf(&b, "BT /%s %s Tf 1 0 0 1 %s %s Tm (%s) Tj ET\n",
			name, num(t.size), num(t.x), num(baseline), escape(t.s))
	}
	return b.Bytes()
}

// num formats a coordinate with two decimals, without a trailing zero.
func num(f float64) string {
	s := fmt.Sprintf("%.2f", f)
	s = strings.TrimRight(strings.TrimRight(s, "0"), ".")
	if s == "-0" {
		return "0"
	}
	return s
}

// render assembles the document.
func render(pages []*page) []byte {
	var b bytes.Buffer
	offsets := []int{}
	obj := func(body string) {
		offsets = append(offsets, b.Len())
		fmt.Fprintf(&b, "%d 0 obj\n%s\nendobj\n", len(offsets), body)
	}
	b.WriteString("%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
	// 1 catalog, 2 page tree, 3 and 4 fonts, then a page and its content
	// for each page.
	kids := make([]string, len(pages))
	for i := range pages {
		kids[i] = fmt.Sprintf("%d 0 R", 5+2*i)
	}
	obj("<< /Type /Catalog /Pages 2 0 R >>")
	obj(fmt.Sprintf("<< /Type /Pages /Kids [%s] /Count %d >>", strings.Join(kids, " "), len(pages)))
	obj("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>")
	obj("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>")
	for i, p := range pages {
		obj(fmt.Sprintf("<< /Type /Page /Parent 2 0 R /MediaBox [0 0 %s %s] "+
			"/Resources << /Font << /F1 3 0 R /F2 4 0 R >> >> /Contents %d 0 R >>",
			num(pageWidth), num(pageHeight), 6+2*i))
		content := p.content()
		obj(fmt.Sprintf("<< /Length %d >>\nstream\n%sendstream", len(content), content))
	}
	xref := b.Len()
	fmt.Fprintf(&b, "xref\n0 %d\n0000000000 65535 f \n", len(offsets)+1)
	for _, off := range offsets {
		fmt.Fprintf(&b, "%010d 00000 n \n", off)
	}
	fmt.Fprintf(&b, "trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n", len(offsets)+1, xref)
	return b.Bytes()
}

// escape encodes s in WinAnsi as a PDF literal string.
func escape(s string) string {
	var b strings.Builder
	for _, r := range s {
		c, ok := winAnsi(r)
		if !ok {
			panic(fmt.Sprintf("fake: %q cannot be written in WinAnsi", r))
		}
		switch c {
		case '(', ')', '\\':
			b.WriteByte('\\')
			b.WriteByte(c)
		default:
			if c < 32 || c > 126 {
				fmt.Fprintf(&b, "\\%03o", c)
			} else {
				b.WriteByte(c)
			}
		}
	}
	return b.String()
}

func winAnsi(r rune) (byte, bool) {
	switch {
	case r >= 32 && r <= 126, r >= 0xA0 && r <= 0xFF:
		return byte(r), true
	case r == '’':
		return 0x92, true
	case r == '–':
		return 0x96, true
	}
	return 0, false
}

// widths of Helvetica (regular) for the characters 32 to 126, in thousandths
// of the font size; accented letters take the width of their base letter.
var helvetica = [95]int{
	278, 278, 355, 556, 556, 889, 667, 191, 333, 333, 389, 584, 278, 333, 278, 278,
	556, 556, 556, 556, 556, 556, 556, 556, 556, 556, 278, 278, 584, 584, 584, 556,
	1015, 667, 667, 722, 722, 667, 611, 778, 722, 278, 500, 667, 556, 833, 722, 778,
	667, 778, 722, 667, 611, 722, 667, 944, 667, 667, 611, 278, 278, 278, 469, 556,
	333, 556, 556, 500, 556, 556, 278, 556, 556, 222, 222, 500, 222, 833, 556, 556,
	556, 556, 333, 500, 278, 556, 500, 722, 500, 500, 500, 334, 260, 334, 584,
}

// width of s in points. Bold text is about 6 % wider; that precision is
// enough to align columns.
func width(f font, size float64, s string) float64 {
	total := 0
	for _, r := range s {
		w := 556
		if r >= 32 && r <= 126 {
			w = helvetica[r-32]
		}
		total += w
	}
	k := 1.0
	if f == bold {
		k = 1.06
	}
	return float64(total) * size / 1000 * k
}
