package tutorial

import (
	"math"
	"strings"

	"github.com/charmbracelet/harmonica"
	"github.com/charmbracelet/lipgloss"
)

// The splash is the tour's opening number: the PLUM wordmark springs up
// letter by letter while a plum bounces across the top of it on projectile
// physics, then the tagline fades in. Any key skips straight to chapter 1.

// A hand-drawn 5-row block font — just the four letters we need.
var splashFont = map[rune][]string{
	'P': {"█████ ", "██  ██", "█████ ", "██    ", "██    "},
	'L': {"██    ", "██    ", "██    ", "██    ", "██████"},
	'U': {"██  ██", "██  ██", "██  ██", "██  ██", " ████ "},
	'M': {"██   ██", "███ ███", "██ █ ██", "██   ██", "██   ██"},
}

const (
	splashWord       = "PLUM"
	splashFontRows   = 5
	splashBallRows   = 6  // sky above the wordmark the ball bounces through
	splashRelaunchIn = 50 // frames of rest before the plum bounces again
)

// letterShades run darker→brighter across the wordmark.
var letterShades = []string{"#8E4585", "#A55BA3", "#BC6FC5", "#D183E8"}

type splash struct {
	spring  harmonica.Spring
	offsets []float64 // per-letter vertical offset (rows below rest)
	vels    []float64
	started []int // frame each letter's spring wakes up

	ball        *harmonica.Projectile
	ballPos     harmonica.Point
	bounces     int
	ballDone    bool
	respawnWait int

	frame  int
	showUI bool // letters have settled; tagline + button are up
	done   bool
}

func newSplash() *splash {
	fps := int(1e9 / frameInterval.Nanoseconds())
	s := &splash{
		spring:  harmonica.NewSpring(harmonica.FPS(fps), 6.5, 0.55),
		offsets: make([]float64, len(splashWord)),
		vels:    make([]float64, len(splashWord)),
		started: make([]int, len(splashWord)),
	}
	for i := range s.offsets {
		s.offsets[i] = float64(splashFontRows + 2) // start fully sunk
		s.started[i] = i * 4                       // staggered entrance
	}
	s.launchBall()
	return s
}

// launchBall arcs the plum in from the left with a rightward drift and
// gravity; it bounces on the wordmark's roofline, losing bounce each time.
// The splash is a title screen now, so the show loops: the ball relaunches
// after a short rest for as long as the screen is up.
func (s *splash) launchBall() {
	fps := int(1e9 / frameInterval.Nanoseconds())
	s.ball = harmonica.NewProjectile(
		harmonica.FPS(fps),
		harmonica.Point{X: -2, Y: 0},
		harmonica.Vector{X: 11, Y: 2},
		harmonica.Vector{Y: 36},
	)
	s.ballPos = s.ball.Position()
	s.bounces = 0
	s.ballDone = false
	s.respawnWait = 0
}

// tick advances one frame; sets done once the show is over.
func (s *splash) tick() {
	if s.done {
		return
	}
	s.frame++

	for i := range s.offsets {
		if s.frame >= s.started[i] {
			s.offsets[i], s.vels[i] = s.spring.Update(s.offsets[i], s.vels[i], 0)
		}
	}

	if s.ballDone {
		s.respawnWait++
		if s.respawnWait >= splashRelaunchIn {
			s.launchBall()
		}
	} else {
		s.ballPos = s.ball.Update()
		floor := float64(splashBallRows - 1)
		if s.ballPos.Y >= floor && s.ball.Velocity().Y > 0 {
			s.bounces++
			vel := s.ball.Velocity()
			vel.Y = -vel.Y * 0.55 // damped bounce
			pos := s.ballPos
			pos.Y = floor
			s.reballistic(pos, vel)
			if s.bounces >= 4 || math.Abs(vel.Y) < 2 {
				s.ballDone = true
			}
		}
		if s.ballPos.X > 60 {
			s.ballDone = true
		}
	}

	if !s.showUI {
		settled := true
		for i := range s.offsets {
			if math.Abs(s.offsets[i]) > 0.3 || math.Abs(s.vels[i]) > 0.3 {
				settled = false
			}
		}
		s.showUI = settled
	}
}

func (s *splash) reballistic(pos harmonica.Point, vel harmonica.Vector) {
	fps := int(1e9 / frameInterval.Nanoseconds())
	s.ball = harmonica.NewProjectile(harmonica.FPS(fps), pos, vel, harmonica.Vector{Y: 36})
	s.ballPos = pos
}

var (
	splashBall    = lipgloss.NewStyle().Foreground(plumColor).Bold(true).Render("●")
	splashTagline = dimText.Render("content like code — a Rails-native CMS")
	splashQuit    = dimText.Render("q to quit")

	// The button breathes through the plum shades while the screen waits.
	buttonShades = []string{"#8E4585", "#A55BA3", "#BC6FC5", "#A55BA3"}
)

// button renders the start button, pulsing with the frame clock.
func (s *splash) button() string {
	shade := buttonShades[(s.frame/14)%len(buttonShades)]
	return lipgloss.NewStyle().
		Foreground(lipgloss.Color("#FFFDF5")).
		Background(lipgloss.Color(shade)).
		Padding(0, 4).
		Bold(true).
		Render("Start the tutorial  ↵")
}

// view composes the frame: sky with the bouncing plum, the rising
// wordmark, then (once things settle) the tagline.
func (s *splash) view(width, height int) string {
	letters := make([][]string, len(splashWord))
	wordWidth := 0
	for i, r := range splashWord {
		letters[i] = splashFont[r]
		wordWidth += lipgloss.Width(letters[i][0]) + 1
	}

	var b strings.Builder

	// Sky: the plum at its projectile position.
	ballX, ballY := int(math.Round(s.ballPos.X)), int(math.Round(s.ballPos.Y))
	for row := 0; row < splashBallRows; row++ {
		if !s.ballDone && row == ballY && ballX >= 0 && ballX < width-2 {
			b.WriteString(strings.Repeat(" ", ballX) + splashBall)
		}
		b.WriteString("\n")
	}

	// Wordmark: each letter clipped by its own spring offset.
	for row := 0; row < splashFontRows; row++ {
		for i := range letters {
			shade := lipgloss.NewStyle().Foreground(lipgloss.Color(letterShades[i%len(letterShades)])).Bold(true)
			src := row - int(math.Round(s.offsets[i]))
			cell := strings.Repeat(" ", lipgloss.Width(letters[i][0]))
			if src >= 0 && src < splashFontRows {
				cell = shade.Render(letters[i][src])
			}
			b.WriteString(cell + " ")
		}
		b.WriteString("\n")
	}

	b.WriteString("\n")
	if s.showUI {
		b.WriteString(splashTagline + "\n\n" + s.button() + "\n\n" + splashQuit)
	}

	// Center the whole block horizontally-ish.
	block := b.String()
	pad := (width - wordWidth) / 2
	if pad < 0 {
		pad = 0
	}
	topPad := (height - splashBallRows - splashFontRows - 4) / 3
	if topPad < 0 {
		topPad = 0
	}
	return strings.Repeat("\n", topPad) + indent(block, pad)
}
