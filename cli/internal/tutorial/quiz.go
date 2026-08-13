package tutorial

import (
	"fmt"
	"strings"

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
			*q = newQuiz()
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
