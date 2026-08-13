package tutorial

import (
	"encoding/json"
	"os"
	"path/filepath"
)

// Progress is the tour's save file: what you've read, watched, typed, and
// scored. It turns the tutorial from a pamphlet into a journey — chapters
// check off, XP accrues, ranks climb, and `plum tutorial` resumes where
// you left off.
type Progress struct {
	ChaptersRead map[string]bool `json:"chapters_read"`
	DemosWatched map[string]bool `json:"demos_watched"`
	TypingDone   map[string]bool `json:"typing_done"`
	QuizPassed   bool            `json:"quiz_passed"`
	HighScore    int             `json:"plum_drop_high_score"`
	LastChapter  int             `json:"last_chapter"`

	path string // empty = ephemeral (the SSH server's anonymous sessions)
}

// XP values: reading is easy, doing is worth more.
const (
	xpChapter = 10
	xpDemo    = 15
	xpTyping  = 25
	xpQuiz    = 50
)

// ranks climb the orchard. Thresholds are XP.
var ranks = []struct {
	at   int
	name string
}{
	{0, "Seedling"},
	{40, "Sprout"},
	{90, "Sapling"},
	{140, "Grower"},
	{195, "Orchardist"},
}

func newProgress(path string) *Progress {
	p := &Progress{
		ChaptersRead: map[string]bool{},
		DemosWatched: map[string]bool{},
		TypingDone:   map[string]bool{},
		path:         path,
	}
	if path == "" {
		return p
	}
	if raw, err := os.ReadFile(path); err == nil {
		_ = json.Unmarshal(raw, p) // a corrupt save file just starts over
		if p.ChaptersRead == nil {
			p.ChaptersRead = map[string]bool{}
		}
		if p.DemosWatched == nil {
			p.DemosWatched = map[string]bool{}
		}
		if p.TypingDone == nil {
			p.TypingDone = map[string]bool{}
		}
	}
	return p
}

// DefaultProgressPath sits beside the CLI's other per-user state.
func DefaultProgressPath() string {
	base := os.Getenv("XDG_CONFIG_HOME")
	if base == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			return ""
		}
		base = filepath.Join(home, ".config")
	}
	return filepath.Join(base, "plum", "tutorial.json")
}

// save is best-effort: a read-only disk should never break the tour.
func (p *Progress) save() {
	if p.path == "" {
		return
	}
	raw, err := json.MarshalIndent(p, "", "  ")
	if err != nil {
		return
	}
	_ = os.MkdirAll(filepath.Dir(p.path), 0o755)
	_ = os.WriteFile(p.path, raw, 0o644)
}

func (p *Progress) xp() int {
	total := 0
	for _, done := range p.ChaptersRead {
		if done {
			total += xpChapter
		}
	}
	for _, done := range p.DemosWatched {
		if done {
			total += xpDemo
		}
	}
	for _, done := range p.TypingDone {
		if done {
			total += xpTyping
		}
	}
	if p.QuizPassed {
		total += xpQuiz
	}
	return total
}

func (p *Progress) rank() string {
	xp := p.xp()
	name := ranks[0].name
	for _, r := range ranks {
		if xp >= r.at {
			name = r.name
		}
	}
	return name
}

func (p *Progress) markChapter(title string) {
	if title == quizTitle || p.ChaptersRead[title] {
		return
	}
	p.ChaptersRead[title] = true
	p.save()
}

func (p *Progress) markDemo(title string) {
	if p.DemosWatched[title] {
		return
	}
	p.DemosWatched[title] = true
	p.save()
}

func (p *Progress) markTyping(title string) {
	if p.TypingDone[title] {
		return
	}
	p.TypingDone[title] = true
	p.save()
}

func (p *Progress) markQuiz() {
	if p.QuizPassed {
		return
	}
	p.QuizPassed = true
	p.save()
}

func (p *Progress) rememberChapter(index int) {
	if p.LastChapter != index {
		p.LastChapter = index
		p.save()
	}
}

func (p *Progress) recordScore(score int) bool {
	if score > p.HighScore {
		p.HighScore = score
		p.save()
		return true
	}
	return false
}
