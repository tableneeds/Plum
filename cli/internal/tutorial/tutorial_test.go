package tutorial

import (
	"strings"
	"testing"

	tea "github.com/charmbracelet/bubbletea"
)

func TestChaptersLoadInOrderWithTitles(t *testing.T) {
	chapters, err := Chapters()
	if err != nil {
		t.Fatal(err)
	}
	if len(chapters) < 6 {
		t.Fatalf("expected a real tour, got %d chapters", len(chapters))
	}
	if chapters[0].Title != "Welcome to Plum" {
		t.Fatalf("expected the tour to open with the welcome chapter, got %q", chapters[0].Title)
	}
	seen := map[string]bool{}
	for _, ch := range chapters {
		if ch.Title == "" || ch.Title == "Untitled" {
			t.Fatalf("chapter missing a heading: %q...", ch.Body[:40])
		}
		if seen[ch.Title] {
			t.Fatalf("duplicate chapter title %q", ch.Title)
		}
		seen[ch.Title] = true
		if strings.TrimSpace(ch.Body) == "" {
			t.Fatalf("chapter %q has no body", ch.Title)
		}
	}
}

func TestTourCoversTheCoreCommands(t *testing.T) {
	chapters, err := Chapters()
	if err != nil {
		t.Fatal(err)
	}
	var all strings.Builder
	for _, ch := range chapters {
		all.WriteString(ch.Body)
	}
	for _, cmd := range []string{"plum connect", "plum pull", "plum push", "plum logs", "plum use"} {
		if !strings.Contains(all.String(), cmd) {
			t.Fatalf("the tour never mentions %q", cmd)
		}
	}
}

func TestChapterDigitParsesJumpKeys(t *testing.T) {
	if chapterDigit("3") != 3 || chapterDigit("9") != 9 {
		t.Fatal("digit keys should map to chapter numbers")
	}
	for _, k := range []string{"0", "a", "10", "enter"} {
		if chapterDigit(k) != 0 {
			t.Fatalf("%q should not be a chapter jump", k)
		}
	}
}

func TestModelNavigationAndQuit(t *testing.T) {
	chapters, err := Chapters()
	if err != nil {
		t.Fatal(err)
	}
	m := &model{chapters: chapters}
	m.Update(tea.WindowSizeMsg{Width: 80, Height: 24})
	if !m.ready {
		t.Fatal("window size should make the model ready")
	}

	key := func(r rune) tea.KeyMsg { return tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{r}} }

	m.Update(key('l'))
	if m.index != 1 {
		t.Fatalf("l should advance to chapter 2, index=%d", m.index)
	}
	m.Update(key('5'))
	if m.index != 4 {
		t.Fatalf("5 should jump to chapter 5, index=%d", m.index)
	}
	if view := m.View(); !strings.Contains(view, chapters[4].Title) {
		t.Fatalf("view should show the current chapter title %q", chapters[4].Title)
	}
	m.Update(key('h'))
	if m.index != 3 {
		t.Fatalf("h should go back a chapter, index=%d", m.index)
	}

	_, cmd := m.Update(key('q'))
	if cmd == nil {
		t.Fatal("q should quit")
	}
	if _, isQuit := cmd().(tea.QuitMsg); !isQuit {
		t.Fatal("q's command should be tea.Quit")
	}
}

func TestModelSurvivesZeroSizedTerminal(t *testing.T) {
	chapters, err := Chapters()
	if err != nil {
		t.Fatal(err)
	}
	m := &model{chapters: chapters}
	m.Update(tea.WindowSizeMsg{Width: 0, Height: 0})
	if view := m.View(); !strings.Contains(view, chapters[0].Title) {
		t.Fatal("a zero-sized pty should still render the chapter")
	}
}
