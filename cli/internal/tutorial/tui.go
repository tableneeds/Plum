package tutorial

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/bubbles/viewport"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/glamour"
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
	m := &model{chapters: chapters, style: style}
	_, err = tea.NewProgram(m, tea.WithAltScreen()).Run()
	return err
}

var (
	plumColor   = lipgloss.AdaptiveColor{Light: "#8E4585", Dark: "#D183E8"}
	grayColor   = lipgloss.AdaptiveColor{Light: "#6B7280", Dark: "#7D8590"}
	headerStyle = lipgloss.NewStyle().Bold(true).Foreground(plumColor)
	dimText     = lipgloss.NewStyle().Foreground(grayColor)
	dotOn       = lipgloss.NewStyle().Foreground(plumColor).Render("●")
	dotOff      = lipgloss.NewStyle().Foreground(grayColor).Render("○")
)

type model struct {
	chapters []Chapter
	index    int
	viewport viewport.Model
	renderer *glamour.TermRenderer
	style    string // glamour style name, resolved before the program started
	width    int
	height   int
	ready    bool
}

func (m *model) Init() tea.Cmd { return nil }

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
		bodyHeight := m.height - 4 // header + blank + footer + blank
		if bodyHeight < 1 {
			bodyHeight = 1
		}
		if !m.ready {
			m.viewport = viewport.New(m.width, bodyHeight)
			m.ready = true
		} else {
			m.viewport.Width, m.viewport.Height = m.width, bodyHeight
		}
		m.rebuildRenderer()
		m.showChapter()
		return m, nil

	case tea.KeyMsg:
		switch msg.String() {
		case "q", "esc", "ctrl+c":
			return m, tea.Quit
		case "right", "l", "n", "tab", "enter":
			if m.index < len(m.chapters)-1 {
				m.index++
				m.showChapter()
			}
			return m, nil
		case "left", "h", "p", "shift+tab":
			if m.index > 0 {
				m.index--
				m.showChapter()
			}
			return m, nil
		case "g", "home":
			m.viewport.GotoTop()
			return m, nil
		case "G", "end":
			m.viewport.GotoBottom()
			return m, nil
		default:
			if n := chapterDigit(msg.String()); n > 0 && n <= len(m.chapters) {
				m.index = n - 1
				m.showChapter()
				return m, nil
			}
		}
	}

	var cmd tea.Cmd
	m.viewport, cmd = m.viewport.Update(msg)
	return m, cmd
}

func (m *model) View() string {
	if !m.ready {
		return "loading..."
	}
	title := headerStyle.Render(m.chapters[m.index].Title)
	place := dimText.Render(fmt.Sprintf("  chapter %d of %d", m.index+1, len(m.chapters)))
	header := " " + title + place

	dots := make([]string, len(m.chapters))
	for i := range m.chapters {
		if i == m.index {
			dots[i] = dotOn
		} else {
			dots[i] = dotOff
		}
	}
	footer := " " + strings.Join(dots, " ") + dimText.Render("   ←/→ chapters · ↑/↓ scroll · 1-9 jump · q quit")

	return header + "\n\n" + m.viewport.View() + "\n" + footer
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

func (m *model) showChapter() {
	body := m.chapters[m.index].Body
	if m.renderer != nil {
		if rendered, err := m.renderer.Render(body); err == nil {
			body = rendered
		}
	}
	m.viewport.SetContent(body)
	m.viewport.GotoTop()
}

func chapterDigit(key string) int {
	if len(key) == 1 && key[0] >= '1' && key[0] <= '9' {
		return int(key[0] - '0')
	}
	return 0
}
