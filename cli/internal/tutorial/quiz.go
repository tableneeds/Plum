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
	// oscillating around rest), finishing earns a confetti burst
	// (harmonica projectiles under gravity).
	shakePos float64
	shakeVel float64
	shaking  bool
	confetti []confettiParticle
	width    int // stage width for confetti, set by the model on resize
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

func (q *quizState) burstConfetti(width int) {
	if width < 20 {
		width = 60
	}
	fps := harmonica.FPS(33)
	q.confetti = q.confetti[:0]
	for i := 0; i < 48; i++ {
		x := float64(width)/2 + rand.Float64()*10 - 5
		vx := rand.Float64()*44 - 22
		vy := -(rand.Float64()*16 + 6) // launched upward, gravity brings them down
		p := harmonica.NewProjectile(fps,
			harmonica.Point{X: x, Y: 1},
			harmonica.Vector{X: vx, Y: vy},
			harmonica.Vector{Y: 32},
		)
		style := lipgloss.NewStyle().Foreground(lipgloss.Color(confettiColors[i%len(confettiColors)]))
		q.confetti = append(q.confetti, confettiParticle{
			proj:  p,
			pos:   p.Position(), // render at the spawn point before the first tick
			glyph: style.Render(confettiGlyphs[i%len(confettiGlyphs)]),
		})
	}
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
	if len(q.confetti) > 0 {
		alive := q.confetti[:0]
		for _, p := range q.confetti {
			p.pos = p.proj.Update()
			if p.pos.Y < confettiRows+2 { // fell off the stage
				alive = append(alive, p)
			}
		}
		q.confetti = alive
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
			q.burstConfetti(q.width)
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
		if len(q.confetti) > 0 {
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
