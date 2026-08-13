package tutorial

import (
	"strings"

	"github.com/charmbracelet/lipgloss"
)

// A typing challenge is the "now you try" moment: instead of watching the
// demo, you type the real command yourself. Input is strict — only the
// next correct character is accepted (a wrong key bumps the miss counter
// and briefly flashes) — so what your fingers learn is the actual command.

type typeChallenge struct {
	title    string // chapter this belongs to (for progress marking)
	target   string
	typed    int // correct characters entered so far
	misses   int
	flash    int  // frames left of wrong-key flash
	done     bool // target fully typed
	doneWait int  // frames of victory lap before the demo rolls
}

// typingTargets maps demo chapters to the command you practice there.
func typingTargets() map[string]string {
	return map[string]string{
		"The CLI: connecting a server": "plum connect",
		"Everyday commands":            "plum pull",
	}
}

// key feeds one printable keypress; backspace rewinds. Reports whether the
// challenge just completed.
func (t *typeChallenge) key(k string) bool {
	if t.done {
		return false
	}
	switch k {
	case "backspace":
		if t.typed > 0 {
			t.typed--
		}
		return false
	case " ":
		k = " "
	}
	if len(k) != 1 { // arrows, tabs, and friends aren't typing
		return false
	}
	if t.typed < len(t.target) && k[0] == t.target[t.typed] {
		t.typed++
		if t.typed == len(t.target) {
			t.done = true
			return true
		}
		return false
	}
	t.misses++
	t.flash = 5
	return false
}

// tick advances flash/victory timers; returns true while the post-success
// pause is still running.
func (t *typeChallenge) tick() bool {
	if t.flash > 0 {
		t.flash--
	}
	if t.done {
		t.doneWait++
		return t.doneWait < 25
	}
	return true
}

var (
	typedStyle  = lipgloss.NewStyle().Foreground(lipgloss.AdaptiveColor{Light: "#087443", Dark: "#3FCF8E"}).Bold(true)
	untypedDim  = lipgloss.NewStyle().Foreground(grayColor)
	flashStyle  = lipgloss.NewStyle().Foreground(lipgloss.Color("#FFFDF5")).Background(lipgloss.AdaptiveColor{Light: "#B42318", Dark: "#F97066"}).Bold(true)
	cursorStyle = lipgloss.NewStyle().Foreground(plumColor).Bold(true).Underline(true)
)

func (t *typeChallenge) view() string {
	var b strings.Builder
	b.WriteString(quizPrompt.Render("Your turn — type the command:") + "\n\n")

	b.WriteString(demoPromptStyle.Render("$ "))
	b.WriteString(typedStyle.Render(t.target[:t.typed]))
	if t.typed < len(t.target) {
		// The next expected character is highlighted (red-flashed after a
		// wrong key); the rest waits dimly.
		next := string(t.target[t.typed])
		if t.flash > 0 {
			b.WriteString(flashStyle.Render(next))
		} else {
			b.WriteString(cursorStyle.Render(next))
		}
		b.WriteString(untypedDim.Render(t.target[t.typed+1:]))
	}
	b.WriteString("\n\n")

	switch {
	case t.done:
		msg := "✓ That's the one."
		if t.misses == 0 {
			msg = "✓ Flawless."
		}
		b.WriteString(quizRight.Render(msg) + " " + dimText.Render("+25xp — rolling the demo..."))
	case t.misses > 0:
		b.WriteString(dimText.Render("keep going — typos don't count, they just sting"))
	default:
		b.WriteString(dimText.Render("esc to back out"))
	}
	return b.String()
}
