package tutorial

import (
	"fmt"
	"math"
	"math/rand"
	"strings"

	"github.com/charmbracelet/harmonica"
	"github.com/charmbracelet/lipgloss"
)

// The quiz is the tour's last stop: three quick questions answered with
// arrow keys, instant feedback, no score-keeping bureaucracy.

type quizQuestion struct {
	prompt  string
	options []string
	correct int
	explain string
}

type quizState struct {
	questions []quizQuestion
	index     int  // current question
	cursor    int  // highlighted option
	answered  bool // an answer has been picked for the current question
	right     bool // ...and whether it was correct
	finished  bool

	// physics: a wrong answer shakes the question (underdamped spring
	// oscillating around rest), finishing earns confetti rain (harmonica
	// projectiles drifting down the finale screen for as long as you stay).
	shakePos   float64
	shakeVel   float64
	shaking    bool
	confetti   []confettiParticle
	confettiOn bool
	width      int // stage width for confetti, set by the model on resize
}

type confettiParticle struct {
	proj  *harmonica.Projectile
	pos   harmonica.Point
	glyph string
}

// shakeSpring is deliberately underdamped: kicked once, it swings through
// rest several times before settling — a head-shake, not a nudge.
var shakeSpring = harmonica.NewSpring(harmonica.FPS(33), 14.0, 0.18)

var confettiGlyphs = []string{"●", "✦", "▪", "◆", "•"}
var confettiColors = []string{"#D183E8", "#8E4585", "#3FCF8E", "#F7C948", "#BC6FC5"}

func (q *quizState) startShake() {
	q.shaking = true
	q.shakePos = 0
	q.shakeVel = 55 // the kick; the spring does the rest
}

// startConfetti begins the finale's rain; particles keep spawning at the
// top for as long as the celebration screen is up.
func (q *quizState) startConfetti() {
	q.confettiOn = true
	q.confetti = q.confetti[:0]
	// Seed a first wave so the rain is already falling when the screen
	// appears, staggered down the field so it doesn't arrive as one line.
	for i := 0; i < 24; i++ {
		q.spawnConfetti(rand.Float64() * float64(confettiRows))
	}
}

func (q *quizState) spawnConfetti(y float64) {
	width := q.width
	if width < 20 {
		width = 60
	}
	fps := harmonica.FPS(33)
	i := len(q.confetti)
	p := harmonica.NewProjectile(fps,
		harmonica.Point{X: 1 + rand.Float64()*float64(width-2), Y: y},
		harmonica.Vector{X: rand.Float64()*4 - 2, Y: 1.5 + rand.Float64()*2.5},
		harmonica.Vector{Y: 3 + rand.Float64()*3}, // gentle gravity: drift, don't plummet
	)
	style := lipgloss.NewStyle().Foreground(lipgloss.Color(confettiColors[rand.Intn(len(confettiColors))]))
	q.confetti = append(q.confetti, confettiParticle{
		proj:  p,
		pos:   p.Position(), // render at the spawn point before the first tick
		glyph: style.Render(confettiGlyphs[i%len(confettiGlyphs)]),
	})
}

// tick advances the quiz's physics one frame.
func (q *quizState) tick() {
	if q.shaking {
		q.shakePos, q.shakeVel = shakeSpring.Update(q.shakePos, q.shakeVel, 0)
		if math.Abs(q.shakePos) < 0.2 && math.Abs(q.shakeVel) < 0.2 {
			q.shaking = false
			q.shakePos = 0
		}
	}
	if q.confettiOn {
		alive := q.confetti[:0]
		for _, p := range q.confetti {
			p.pos = p.proj.Update()
			if p.pos.Y < confettiRows { // fell off the stage
				alive = append(alive, p)
			}
		}
		q.confetti = alive
		// Keep the rain steady: top up what fell off, within a budget.
		for len(q.confetti) < 26 && rand.Float64() < 0.7 {
			q.spawnConfetti(0)
		}
	}
}

const confettiRows = 7

// confettiView renders the particle field above the finale text.
func (q *quizState) confettiView(width int) string {
	if width < 20 {
		width = 60
	}
	grid := make([][]string, confettiRows)
	for r := range grid {
		grid[r] = make([]string, width)
		for c := range grid[r] {
			grid[r][c] = " "
		}
	}
	for _, p := range q.confetti {
		x, y := int(math.Round(p.pos.X)), int(math.Round(p.pos.Y))
		if y >= 0 && y < confettiRows && x >= 0 && x < width {
			grid[y][x] = p.glyph
		}
	}
	rows := make([]string, confettiRows)
	for r := range grid {
		rows[r] = strings.TrimRight(strings.Join(grid[r], ""), " ")
	}
	return strings.Join(rows, "\n")
}

func newQuiz() quizState {
	return quizState{questions: []quizQuestion{
		{
			prompt:  "You rewrote a post in writing mode. The live site is showing...",
			options: []string{"your half-finished rewrite", "the published version, untouched", "a maintenance page"},
			correct: 1,
			explain: "Autosaves land in the entry's working draft — the published version doesn't change until you hit Publish.",
		},
		{
			prompt:  "Which command brings production content to your laptop?",
			options: []string{"plum push", "plum pull", "plum backup"},
			correct: 1,
			explain: "Pull moves content down; it works even when production runs Postgres and your laptop runs SQLite.",
		},
		{
			prompt:  "And plum push sends up...",
			options: []string{"entries and assets", "your content model (types & fieldsets)", "a Docker image"},
			correct: 1,
			explain: "Push code, pull data: structure goes up from plum/ YAML, content comes down as archives. Deploys stay with Kamal/Once.",
		},
	}}
}

func (q *quizState) current() quizQuestion { return q.questions[q.index] }

// handle processes a key and reports whether the quiz consumed it.
func (q *quizState) handle(key string) bool {
	if q.finished {
		if key == "r" {
			width := q.width
			*q = newQuiz()
			q.width = width
			return true
		}
		return false
	}
	switch key {
	case "up", "k":
		if !q.answered && q.cursor > 0 {
			q.cursor--
		}
		return true
	case "down", "j":
		if !q.answered && q.cursor < len(q.current().options)-1 {
			q.cursor++
		}
		return true
	case "enter", " ":
		if !q.answered {
			q.answered = true
			q.right = q.cursor == q.current().correct
			if !q.right {
				q.startShake()
			}
			return true
		}
		if !q.right {
			q.answered = false // try again
			return true
		}
		if q.index < len(q.questions)-1 {
			q.index++
			q.cursor = 0
			q.answered = false
		} else {
			q.finished = true
			q.startConfetti()
		}
		return true
	}
	return false
}

var (
	quizPrompt  = lipgloss.NewStyle().Bold(true)
	quizPointer = lipgloss.NewStyle().Foreground(plumColor).Bold(true)
	quizRight   = lipgloss.NewStyle().Foreground(lipgloss.AdaptiveColor{Light: "#087443", Dark: "#3FCF8E"}).Bold(true)
	quizWrong   = lipgloss.NewStyle().Foreground(lipgloss.AdaptiveColor{Light: "#B42318", Dark: "#F97066"}).Bold(true)
)

func (q *quizState) view() string {
	var b strings.Builder
	b.WriteString(dimText.Render(fmt.Sprintf("question %d of %d", q.index+1, len(q.questions))) + "\n\n")

	if q.finished {
		if q.confettiOn {
			b.WriteString(q.confettiView(q.width) + "\n")
		}
		b.WriteString(quizRight.Render("✓ All three. ") + "You know Plum.\n\n")
		b.WriteString("Go run " + quizPrompt.Render("plum connect") + " on something real.\n\n")
		b.WriteString(dimText.Render("r to retake the quiz · ←/h back through the tour · q to quit"))
		return b.String()
	}

	question := q.current()
	b.WriteString(quizPrompt.Render(question.prompt) + "\n\n")
	for i, opt := range question.options {
		switch {
		case q.answered && i == question.correct && q.right:
			b.WriteString(quizRight.Render("  ✓ "+opt) + "\n")
		case q.answered && i == q.cursor && !q.right:
			b.WriteString(quizWrong.Render("  ✗ "+opt) + "\n")
		case !q.answered && i == q.cursor:
			b.WriteString(quizPointer.Render("  ❯ ") + opt + "\n")
		default:
			b.WriteString("    " + opt + "\n")
		}
	}
	b.WriteString("\n")
	switch {
	case q.answered && q.right:
		b.WriteString(quizRight.Render("✓ Right. ") + question.explain + "\n\n" + dimText.Render("enter to continue"))
	case q.answered && !q.right:
		b.WriteString(quizWrong.Render("✗ Not quite. ") + dimText.Render("enter to try again"))
	default:
		b.WriteString(dimText.Render("↑/↓ choose · enter to answer"))
	}
	return b.String()
}
