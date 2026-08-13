package tutorial

import (
	"strings"

	"github.com/charmbracelet/lipgloss"
)

// A demo is a canned command run played back inside the tutorial: the
// command types itself out, spinners spin, output lines land one at a
// time — the CLI demonstrating itself without touching a real server.

type demoStep struct {
	spin  string // spinner label animated for a few frames before resolving
	line  string // the line this step settles into (styled, printed verbatim)
	pause int    // extra ticks to hold after the line lands
}

type demo struct {
	command string // typed out char-by-char after the prompt
	steps   []demoStep
}

// demoPlayer advances one tick at a time; every tick is one animation
// frame (the bubbletea side owns the clock).
type demoPlayer struct {
	demo    demo
	typed   int // chars of command shown so far
	step    int // index of the step currently animating
	frame   int // spinner frame within the current step
	holding int // pause ticks remaining after a landed line
	done    bool
}

const spinnerFramesPerStep = 10

var demoSpinnerFrames = []string{"⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷"}

func newDemoPlayer(d demo) *demoPlayer { return &demoPlayer{demo: d} }

// tick advances the playback one frame; returns false once finished.
func (p *demoPlayer) tick() bool {
	if p.done {
		return false
	}
	if p.typed < len(p.demo.command) {
		p.typed += 2 // two chars per frame reads as fast, confident typing
		if p.typed > len(p.demo.command) {
			p.typed = len(p.demo.command)
		}
		return true
	}
	if p.step >= len(p.demo.steps) {
		p.done = true
		return false
	}
	step := p.demo.steps[p.step]
	if p.holding > 0 {
		p.holding--
		if p.holding == 0 {
			p.step++
			p.frame = 0
		}
		return true
	}
	if step.spin != "" && p.frame < spinnerFramesPerStep {
		p.frame++
		return true
	}
	// line lands
	p.holding = step.pause + 1
	return true
}

// view renders the current playback frame.
func (p *demoPlayer) view() string {
	var b strings.Builder
	b.WriteString(demoPromptStyle.Render("$ ") + demoCmdStyle.Render(p.demo.command[:p.typed]))
	if p.typed < len(p.demo.command) {
		b.WriteString(demoCursorStyle.Render("█"))
		return b.String()
	}
	b.WriteString("\n")
	for i := 0; i < p.step && i < len(p.demo.steps); i++ {
		b.WriteString(p.demo.steps[i].line + "\n")
	}
	if p.step < len(p.demo.steps) {
		step := p.demo.steps[p.step]
		switch {
		case p.holding > 0:
			b.WriteString(step.line + "\n")
		case step.spin != "":
			frame := demoSpinnerFrames[p.frame%len(demoSpinnerFrames)]
			b.WriteString(demoSpinStyle.Render(frame) + " " + step.spin + "\n")
		}
	}
	if p.done {
		b.WriteString("\n" + dimText.Render("(demo over — press d to replay, or any other key to keep reading)"))
	}
	return b.String()
}

var (
	demoPromptStyle = lipgloss.NewStyle().Foreground(grayColor).Bold(true)
	demoCmdStyle    = lipgloss.NewStyle().Bold(true)
	demoCursorStyle = lipgloss.NewStyle().Foreground(plumColor)
	demoSpinStyle   = lipgloss.NewStyle().Foreground(plumColor)

	demoStepGlyph = lipgloss.NewStyle().Foreground(plumColor).Bold(true).Render("▸")
	demoOKGlyph   = lipgloss.NewStyle().Foreground(lipgloss.AdaptiveColor{Light: "#087443", Dark: "#3FCF8E"}).Bold(true).Render("✓")
)

func demoGutter(s string) string {
	return lipgloss.NewStyle().Foreground(grayColor).Render("  │ " + s)
}

// demos maps a chapter title to its playable demo; the footer advertises
// `d` on chapters that have one.
func demos() map[string]demo {
	pull := demo{
		command: "plum pull",
		steps: []demoStep{
			{line: demoStepGlyph + " " + lipgloss.NewStyle().Bold(true).Render("Exporting site on production")},
			{line: demoGutter("Exported The Final Word to /tmp/plum-pull-20260813.plum.zip"), pause: 3},
			{spin: "Downloading archive", line: demoOKGlyph + " Downloading archive " + dimText.Render("(700ms)")},
			{line: demoStepGlyph + " " + lipgloss.NewStyle().Bold(true).Render("Replacing local site")},
			{line: demoGutter("Replaced The Final Word with The Final Word (site 2)"), pause: 3},
			{line: demoOKGlyph + " Your local site now matches production", pause: 6},
		},
	}
	connect := demo{
		command: "plum connect",
		steps: []demoStep{
			{line: "This project is already connected to " + lipgloss.NewStyle().Bold(true).Render(`"production"`) + dimText.Render(" (via once, host plum-production)"), pause: 4},
			{spin: "Key-based SSH login to plum-production", line: demoOKGlyph + " Key-based SSH login to plum-production"},
			{spin: "Docker Engine installed", line: demoOKGlyph + " Docker Engine installed"},
			{spin: "once lists finalwordsports.com", line: demoOKGlyph + " once lists finalwordsports.com"},
			{line: "", pause: 1},
			{line: demoOKGlyph + " Everything looks good.", pause: 6},
		},
	}
	return map[string]demo{
		"The CLI: connecting a server": connect,
		"Everyday commands":            pull,
	}
}
