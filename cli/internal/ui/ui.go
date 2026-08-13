// Package ui is the CLI's one voice: colors, glyphs, spinners, prompts, and
// streamed-output framing, heroku-style. Every function degrades to plain,
// script-friendly text when stdout isn't a TTY, when NO_COLOR is set, or
// when TERM=dumb — so CI logs and pipes see exactly what they always did.
package ui

import (
	"fmt"
	"io"
	"os"
	"strings"
	"sync"

	"github.com/charmbracelet/lipgloss"
	"golang.org/x/term"
)

var (
	stdoutTTY = term.IsTerminal(int(os.Stdout.Fd()))
	stdinTTY  = term.IsTerminal(int(os.Stdin.Fd()))

	styledOnce sync.Once
	styledVal  bool
)

// Styled reports whether output decoration (color, glyphs, spinners) is on.
func Styled() bool {
	styledOnce.Do(func() {
		styledVal = stdoutTTY && os.Getenv("NO_COLOR") == "" && os.Getenv("TERM") != "dumb"
	})
	return styledVal
}

// Interactive reports whether fancy prompts (arrow-key selects, styled
// inputs) can run: they need both a real stdin and a styled stdout.
func Interactive() bool {
	return Styled() && stdinTTY
}

// The plum palette. Adaptive colors pick a readable shade for light and
// dark terminal backgrounds.
var (
	plum   = lipgloss.AdaptiveColor{Light: "#8E4585", Dark: "#D183E8"}
	green  = lipgloss.AdaptiveColor{Light: "#087443", Dark: "#3FCF8E"}
	red    = lipgloss.AdaptiveColor{Light: "#B42318", Dark: "#F97066"}
	yellow = lipgloss.AdaptiveColor{Light: "#93540A", Dark: "#F7C948"}
	gray   = lipgloss.AdaptiveColor{Light: "#6B7280", Dark: "#7D8590"}

	stepGlyph  = lipgloss.NewStyle().Foreground(plum).Bold(true)
	stepText   = lipgloss.NewStyle().Bold(true)
	okGlyph    = lipgloss.NewStyle().Foreground(green).Bold(true)
	failGlyph  = lipgloss.NewStyle().Foreground(red).Bold(true)
	warnGlyph  = lipgloss.NewStyle().Foreground(yellow).Bold(true)
	dimStyle   = lipgloss.NewStyle().Foreground(gray)
	boldStyle  = lipgloss.NewStyle().Bold(true)
	plumStyle  = lipgloss.NewStyle().Foreground(plum)
	errorStyle = lipgloss.NewStyle().Foreground(red)
)

// Step announces a phase of work: "▸ Exporting site on production".
func Step(format string, a ...any) {
	msg := fmt.Sprintf(format, a...)
	if !Styled() {
		fmt.Println("==> " + msg)
		return
	}
	fmt.Println(stepGlyph.Render("▸") + " " + stepText.Render(msg))
}

// Success reports a completed step: "✓ Local site now matches production".
func Success(format string, a ...any) {
	msg := fmt.Sprintf(format, a...)
	if !Styled() {
		fmt.Println("✓ " + msg)
		return
	}
	fmt.Println(okGlyph.Render("✓") + " " + msg)
}

// Warn flags something non-fatal the user should read.
func Warn(format string, a ...any) {
	msg := fmt.Sprintf(format, a...)
	if !Styled() {
		fmt.Println("! " + msg)
		return
	}
	fmt.Println(warnGlyph.Render("▸") + " " + msg)
}

// Fail reports a failed step (the command usually returns an error after).
func Fail(format string, a ...any) {
	msg := fmt.Sprintf(format, a...)
	if !Styled() {
		fmt.Fprintln(os.Stderr, "✗ "+msg)
		return
	}
	fmt.Fprintln(os.Stderr, failGlyph.Render("✗")+" "+msg)
}

// Error renders a command's terminal error, replacing the old bare
// "plum: <err>" line.
func Error(err error) {
	if !Styled() {
		fmt.Fprintln(os.Stderr, "plum: "+err.Error())
		return
	}
	fmt.Fprintln(os.Stderr, failGlyph.Render("✗")+" "+errorStyle.Render(err.Error()))
}

// Blank prints an empty spacing line.
func Blank() { fmt.Println() }

// Dim returns text in the muted foreground (identity when unstyled).
func Dim(s string) string {
	if !Styled() {
		return s
	}
	return dimStyle.Render(s)
}

// Bold returns bolded text (identity when unstyled).
func Bold(s string) string {
	if !Styled() {
		return s
	}
	return boldStyle.Render(s)
}

// Accent returns text in the plum accent color (identity when unstyled).
func Accent(s string) string {
	if !Styled() {
		return s
	}
	return plumStyle.Render(s)
}

// StreamWriter wraps w so every line of streamed remote output is framed
// with a dim gutter — remote rake chatter reads as quoted material, not as
// the CLI's own voice. Unstyled, it returns w untouched.
func StreamWriter(w io.Writer) io.Writer {
	if !Styled() {
		return w
	}
	return &gutterWriter{w: w}
}

type gutterWriter struct {
	w       io.Writer
	partial bool // last write ended mid-line, so its gutter is already out
}

func (g *gutterWriter) Write(p []byte) (int, error) {
	if len(p) == 0 {
		return 0, nil
	}
	gutter := dimStyle.Render("  │ ")
	var b strings.Builder
	lines := strings.SplitAfter(string(p), "\n")
	for _, line := range lines {
		if line == "" {
			continue
		}
		if !g.partial {
			b.WriteString(gutter)
		}
		b.WriteString(line)
		g.partial = !strings.HasSuffix(line, "\n")
	}
	if _, err := io.WriteString(g.w, b.String()); err != nil {
		return 0, err
	}
	return len(p), nil
}
