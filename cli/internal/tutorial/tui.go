package tutorial

import (
	"fmt"
	"math"
	"strings"
	"time"

	"github.com/charmbracelet/bubbles/progress"
	"github.com/charmbracelet/bubbles/viewport"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/glamour"
	"github.com/charmbracelet/harmonica"
	"github.com/charmbracelet/lipgloss"
)

// Run plays the tour full-screen until the user quits.
func Run() error {
	chapters, err := Chapters()
	if err != nil {
		return err
	}
	// Detect the terminal background once, *before* bubbletea takes over
	// stdin — querying mid-program (glamour.WithAutoStyle) would race the
	// event loop for the terminal's reply and hang.
	style := "light"
	if lipgloss.HasDarkBackground() {
		style = "dark"
	}
	m := newModel(chapters, style, newProgress(DefaultProgressPath()))
	_, err = tea.NewProgram(m, tea.WithAltScreen()).Run()
	return err
}

var (
	plumColor   = lipgloss.AdaptiveColor{Light: "#8E4585", Dark: "#D183E8"}
	grayColor   = lipgloss.AdaptiveColor{Light: "#6B7280", Dark: "#7D8590"}
	headerStyle = lipgloss.NewStyle().Bold(true).Foreground(plumColor)
	dimText     = lipgloss.NewStyle().Foreground(grayColor)
)

const (
	frameInterval = 30 * time.Millisecond
	slideStart    = 16.0 // columns the incoming chapter slides across
	quizTitle     = "Pop quiz"
)

type frameMsg time.Time

type mode int

const (
	modeSplash mode = iota
	modeRead
	modeDemo
	modeQuiz
	modeType
	modeGame
)

type model struct {
	chapters []Chapter
	demos    map[string]demo
	index    int
	mode     mode

	viewport viewport.Model
	renderer *glamour.TermRenderer
	rendered string // current chapter, glamour-rendered, before slide indent
	style    string

	spring   harmonica.Spring
	slidePos float64
	slideVel float64
	sliding  bool

	progress progress.Model
	player   *demoPlayer
	quiz     quizState
	splash   *splash
	prog     *Progress
	typing   *typeChallenge
	targets  map[string]string
	game     *plumDrop

	width  int
	height int
	ready  bool
}

func newModel(chapters []Chapter, style string, prog *Progress) *model {
	chapters = append(chapters, Chapter{Title: quizTitle})
	bar := progress.New(
		progress.WithGradient("#8E4585", "#D183E8"),
		progress.WithoutPercentage(),
	)
	sp := newSplash()
	if prog.xp() > 0 || prog.LastChapter > 0 {
		sp.buttonLabel = "Continue the tutorial  ↵"
	}
	return &model{
		chapters: chapters,
		demos:    demos(),
		targets:  typingTargets(),
		style:    style,
		spring:   harmonica.NewSpring(harmonica.FPS(int(time.Second/frameInterval)), 7.0, 0.8),
		progress: bar,
		quiz:     newQuiz(),
		splash:   sp,
		prog:     prog,
		mode:     modeSplash,
	}
}

func (m *model) Init() tea.Cmd { return frameTick() }

func frameTick() tea.Cmd {
	return tea.Tick(frameInterval, func(t time.Time) tea.Msg { return frameMsg(t) })
}

func (m *model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
		// A degenerate pty (CI, script(1)) can report 0x0; render for a
		// classic 80x24 rather than collapsing to nothing.
		if m.width <= 0 {
			m.width = 80
		}
		if m.height <= 0 {
			m.height = 24
		}
		bodyHeight := m.height - 4
		if bodyHeight < 1 {
			bodyHeight = 1
		}
		if !m.ready {
			m.viewport = viewport.New(m.width, bodyHeight)
			m.ready = true
		} else {
			m.viewport.Width, m.viewport.Height = m.width, bodyHeight
		}
		m.progress.Width = min(m.width-4, 40)
		m.quiz.width = min(m.width, 100)
		m.rebuildRenderer()
		m.showChapter(false)
		return m, m.progress.SetPercent(m.progressValue())

	case frameMsg:
		cmds := []tea.Cmd{frameTick()}
		if m.mode == modeSplash {
			m.splash.tick()
			return m, tea.Batch(cmds...)
		}
		if m.mode == modeQuiz {
			m.quiz.tick()
		}
		if m.mode == modeGame && m.game != nil {
			m.game.tick()
			// Celebrate (and bank) records the moment they happen — an
			// endless game has no final screen to do it on.
			if m.game.score > m.game.startingBest {
				m.game.newBest = true
				m.prog.recordScore(m.game.score)
			}
		}
		if m.mode == modeType && m.typing != nil {
			if !m.typing.tick() {
				// victory lap over — reward with the demo
				m.mode = modeDemo
				m.player = newDemoPlayer(m.demos[m.chapters[m.index].Title])
			}
		}
		if m.sliding {
			m.slidePos, m.slideVel = m.spring.Update(m.slidePos, m.slideVel, 0)
			if math.Abs(m.slidePos) < 0.5 && math.Abs(m.slideVel) < 0.5 {
				m.slidePos, m.sliding = 0, false
			}
			m.applySlide()
		}
		if m.mode == modeDemo && m.player != nil {
			wasDone := m.player.done
			m.player.tick()
			if m.player.done && !wasDone {
				m.prog.markDemo(m.chapters[m.index].Title)
			}
			m.viewport.SetContent("\n" + m.player.view())
		}
		return m, tea.Batch(cmds...)

	case progress.FrameMsg:
		bar, cmd := m.progress.Update(msg)
		m.progress = bar.(progress.Model)
		return m, cmd

	case tea.KeyMsg:
		return m.handleKey(msg)
	}

	var cmd tea.Cmd
	m.viewport, cmd = m.viewport.Update(msg)
	return m, cmd
}

func (m *model) handleKey(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	key := msg.String()

	if key == "ctrl+c" {
		return m, tea.Quit
	}

	// Plum Drop owns its keys: arrows steer, q/esc returns to the title
	// screen whenever you've had enough — the game itself never ends.
	if m.mode == modeGame {
		switch {
		case m.game == nil:
			m.mode = modeSplash
		case key == "left" || key == "h":
			m.game.move(-3)
		case key == "right" || key == "l":
			m.game.move(3)
		case key == "q" || key == "esc":
			m.prog.recordScore(m.game.score)
			m.mode = modeSplash
			m.game = nil
		}
		return m, nil
	}

	// A typing challenge eats printable keys; esc backs out to the chapter.
	if m.mode == modeType && m.typing != nil {
		if key == "esc" {
			m.mode = modeRead
			m.typing = nil
			m.showChapter(false)
			return m, nil
		}
		if m.typing.key(key) {
			m.prog.markTyping(m.chapters[m.index].Title)
		}
		return m, nil
	}

	if key == "q" || key == "esc" {
		return m, tea.Quit
	}

	// The splash is a title screen: it holds until the start button is
	// pressed (enter/space); p opens the arcade. Everything else just
	// enjoys the show.
	if m.mode == modeSplash {
		switch key {
		case "enter", " ":
			m.endSplash()
		case "p":
			m.mode = modeGame
			m.game = newPlumDrop(m.width, m.height)
			m.game.startingBest = m.prog.HighScore
		}
		return m, nil
	}

	// Demo playback: d replays, everything else returns to reading.
	if m.mode == modeDemo {
		if key == "d" {
			m.player = newDemoPlayer(m.demos[m.chapters[m.index].Title])
			return m, nil
		}
		m.mode = modeRead
		m.showChapter(false)
		return m, nil
	}

	// The quiz consumes its own keys (arrows, enter, r) but chapter
	// navigation still works so nobody gets trapped in school.
	if m.mode == modeQuiz {
		wasFinished := m.quiz.finished
		if m.quiz.handle(key) {
			if m.quiz.finished && !wasFinished {
				m.prog.markQuiz()
			}
			return m, nil
		}
	}

	switch key {
	case "right", "l", "n", "tab", "enter":
		return m.gotoChapter(m.index + 1)
	case "left", "h", "p", "shift+tab":
		return m.gotoChapter(m.index - 1)
	case "d":
		if _, ok := m.demos[m.chapters[m.index].Title]; ok {
			m.mode = modeDemo
			m.player = newDemoPlayer(m.demos[m.chapters[m.index].Title])
			return m, nil
		}
	case "t":
		if target, ok := m.targets[m.chapters[m.index].Title]; ok {
			m.mode = modeType
			m.typing = &typeChallenge{title: m.chapters[m.index].Title, target: target}
			return m, nil
		}
	case "g", "home":
		m.viewport.GotoTop()
		return m, nil
	case "G", "end":
		m.viewport.GotoBottom()
		return m, nil
	default:
		if n := chapterDigit(key); n > 0 && n <= len(m.chapters) {
			return m.gotoChapter(n - 1)
		}
	}

	var cmd tea.Cmd
	m.viewport, cmd = m.viewport.Update(msg)
	return m, cmd
}

// endSplash drops out of the intro — into chapter one on a fresh save,
// or back to wherever the last session left off.
func (m *model) endSplash() {
	m.splash.done = true
	target := m.prog.LastChapter
	if target < 0 || target >= len(m.chapters) {
		target = 0
	}
	m.index = target
	if m.chapters[m.index].Title == quizTitle {
		m.mode = modeQuiz
	} else {
		m.mode = modeRead
	}
	m.prog.markChapter(m.chapters[m.index].Title)
	m.showChapter(true)
}

func (m *model) gotoChapter(index int) (tea.Model, tea.Cmd) {
	if index < 0 || index >= len(m.chapters) || index == m.index {
		return m, nil
	}
	m.index = index
	m.player = nil
	m.typing = nil
	if m.chapters[m.index].Title == quizTitle {
		m.mode = modeQuiz
	} else {
		m.mode = modeRead
	}
	m.prog.markChapter(m.chapters[m.index].Title)
	m.prog.rememberChapter(m.index)
	m.showChapter(true)
	return m, m.progress.SetPercent(m.progressValue())
}

func (m *model) progressValue() float64 {
	if len(m.chapters) <= 1 {
		return 1
	}
	return float64(m.index) / float64(len(m.chapters)-1)
}

func (m *model) View() string {
	if !m.ready {
		return "loading..."
	}
	if m.mode == modeSplash {
		return m.padToWindow(m.splash.view(m.width, m.height))
	}
	if m.mode == modeGame && m.game != nil {
		return m.padToWindow(m.game.view(m.prog.HighScore))
	}

	title := headerStyle.Render(m.chapters[m.index].Title)
	place := dimText.Render(fmt.Sprintf("  chapter %d of %d", m.index+1, len(m.chapters)))
	read := ""
	if m.prog.ChaptersRead[m.chapters[m.index].Title] || m.chapters[m.index].Title == quizTitle && m.prog.QuizPassed {
		read = quizRight.Render(" ✓")
	}
	standing := dimText.Render("  ·  ") + headerStyle.Render(m.prog.rank()) + dimText.Render(fmt.Sprintf(" %dxp", m.prog.xp()))
	header := " " + title + place + read + standing

	body := m.viewport.View()
	switch m.mode {
	case modeQuiz:
		offset := 2 + int(math.Round(m.slidePos)) + int(math.Round(m.quiz.shakePos))
		body = m.padToViewport("\n" + indent(m.quiz.view(), max(0, offset)))
	case modeType:
		if m.typing != nil {
			body = m.padToViewport("\n" + indent(m.typing.view(), 2))
		}
	}

	hints := "←/→ chapters · ↑/↓ scroll · 1-9 jump · q quit"
	if m.mode == modeRead {
		title := m.chapters[m.index].Title
		if _, ok := m.targets[title]; ok {
			hints = "t type it yourself · " + hints
		}
		if _, ok := m.demos[title]; ok {
			hints = "d watch it run · " + hints
		}
	}
	footer := " " + m.progress.View() + dimText.Render("  "+hints)

	return header + "\n\n" + body + "\n" + footer
}

// padToWindow fills the whole terminal so the splash owns the screen.
func (m *model) padToWindow(body string) string {
	lines := strings.Split(body, "\n")
	for len(lines) < m.height {
		lines = append(lines, "")
	}
	if len(lines) > m.height {
		lines = lines[:m.height]
	}
	return strings.Join(lines, "\n")
}

// padToViewport gives non-viewport bodies (the quiz) the same height as the
// viewport so the footer doesn't jump around.
func (m *model) padToViewport(body string) string {
	lines := strings.Split(body, "\n")
	for len(lines) < m.viewport.Height {
		lines = append(lines, "")
	}
	if len(lines) > m.viewport.Height {
		lines = lines[:m.viewport.Height]
	}
	return strings.Join(lines, "\n")
}

func (m *model) rebuildRenderer() {
	width := m.width - 2
	if width < 20 {
		width = 20
	}
	if width > 100 {
		width = 100 // prose lines longer than ~100 columns get hard to read
	}
	style := m.style
	if style == "" {
		style = "dark"
	}
	renderer, err := glamour.NewTermRenderer(
		glamour.WithStandardStyle(style),
		glamour.WithWordWrap(width),
	)
	if err == nil {
		m.renderer = renderer
	}
}

// showChapter renders the current chapter; animate starts the spring
// slide-in for chapter changes (resizes re-render in place).
func (m *model) showChapter(animate bool) {
	if m.mode != modeRead {
		if animate {
			m.slidePos, m.slideVel, m.sliding = slideStart, 0, true
		}
		return
	}
	body := m.chapters[m.index].Body
	if m.renderer != nil {
		if rendered, err := m.renderer.Render(body); err == nil {
			body = rendered
		}
	}
	m.rendered = body
	if animate {
		m.slidePos, m.slideVel, m.sliding = slideStart, 0, true
	} else {
		m.slidePos, m.sliding = 0, false
	}
	m.applySlide()
	m.viewport.GotoTop()
}

func (m *model) applySlide() {
	offset := int(math.Round(m.slidePos))
	if offset < 0 {
		offset = 0
	}
	m.viewport.SetContent(indent(m.rendered, offset))
}

func indent(s string, columns int) string {
	if columns <= 0 {
		return s
	}
	pad := strings.Repeat(" ", columns)
	lines := strings.Split(s, "\n")
	for i, line := range lines {
		if line != "" {
			lines[i] = pad + line
		}
	}
	return strings.Join(lines, "\n")
}

func chapterDigit(key string) int {
	if len(key) == 1 && key[0] >= '1' && key[0] <= '9' {
		return int(key[0] - '0')
	}
	return 0
}
