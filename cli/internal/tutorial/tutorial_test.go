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
	m := newModel(chapters, "dark")
	m.Update(tea.WindowSizeMsg{Width: 80, Height: 24})
	if !m.ready {
		t.Fatal("window size should make the model ready")
	}
	m.endSplash() // the intro swallows its first keypress; skip it for nav tests

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
	m := newModel(chapters, "dark")
	m.Update(tea.WindowSizeMsg{Width: 0, Height: 0})
	m.endSplash()
	if view := m.View(); !strings.Contains(view, chapters[0].Title) {
		t.Fatal("a zero-sized pty should still render the chapter")
	}
}

func TestDemosAttachToRealChapters(t *testing.T) {
	chapters, err := Chapters()
	if err != nil {
		t.Fatal(err)
	}
	titles := map[string]bool{}
	for _, ch := range chapters {
		titles[ch.Title] = true
	}
	for title := range demos() {
		if !titles[title] {
			t.Fatalf("demo attached to nonexistent chapter %q", title)
		}
	}
}

func TestDemoPlayerPlaysToCompletion(t *testing.T) {
	for title, d := range demos() {
		p := newDemoPlayer(d)
		for i := 0; i < 10000 && !p.done; i++ {
			p.tick()
		}
		if !p.done {
			t.Fatalf("demo %q never finishes", title)
		}
		final := p.view()
		if !strings.Contains(final, d.command) {
			t.Fatalf("demo %q final frame missing its command", title)
		}
		if !strings.Contains(final, "demo over") {
			t.Fatalf("demo %q final frame missing the replay hint", title)
		}
	}
}

func TestQuizAnswerFlow(t *testing.T) {
	q := newQuiz()
	// Wrong answer: cursor starts on option 0, correct is 1 everywhere.
	q.handle("enter")
	if q.right {
		t.Fatal("option 0 should be wrong")
	}
	q.handle("enter") // acknowledges, back to choosing
	q.handle("down")
	q.handle("enter")
	if !q.right {
		t.Fatal("option 1 should be right")
	}
	q.handle("enter") // next question
	if q.index != 1 {
		t.Fatalf("expected question 2, got %d", q.index+1)
	}
	for i := 0; i < 2; i++ {
		q.handle("down")
		q.handle("enter")
		q.handle("enter")
	}
	if !q.finished {
		t.Fatal("answering all three should finish the quiz")
	}
	if !strings.Contains(q.view(), "plum connect") {
		t.Fatal("the finale should point at plum connect")
	}
	q.handle("r")
	if q.finished || q.index != 0 {
		t.Fatal("r should restart the quiz")
	}
}

func TestQuizIsTheFinalChapter(t *testing.T) {
	chapters, err := Chapters()
	if err != nil {
		t.Fatal(err)
	}
	m := newModel(chapters, "dark")
	m.Update(tea.WindowSizeMsg{Width: 80, Height: 24})
	m.endSplash()
	m.gotoChapter(len(m.chapters) - 1)
	if m.mode != modeQuiz {
		t.Fatal("last chapter should enter quiz mode")
	}
	if view := m.View(); !strings.Contains(view, "question 1 of") {
		t.Fatal("quiz view should render the first question")
	}
	// Navigation must still rescue people from the quiz.
	m.handleKey(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{'h'}})
	if m.mode != modeRead {
		t.Fatal("h should leave the quiz for the previous chapter")
	}
}

func TestSplashHoldsAsATitleScreen(t *testing.T) {
	s := newSplash()
	for i := 0; i < 1000; i++ {
		s.tick()
	}
	if s.done {
		t.Fatal("the splash must not end on its own — it's a title screen")
	}
	view := s.view(80, 24)
	if !strings.Contains(view, "content like code") {
		t.Fatalf("settled splash should show the tagline: %q", view)
	}
	if !strings.Contains(view, "Start the tutorial") {
		t.Fatalf("settled splash should show the start button: %q", view)
	}
	// The show loops: after settling, the plum relaunches for another run.
	sawBallAgain := false
	for i := 0; i < 200; i++ {
		s.tick()
		if !s.ballDone {
			sawBallAgain = true
			break
		}
	}
	if !sawBallAgain {
		t.Fatal("the bouncing plum should relaunch while the title screen waits")
	}
}

func TestSplashOnlyEnterStartsTheTour(t *testing.T) {
	chapters, err := Chapters()
	if err != nil {
		t.Fatal(err)
	}
	m := newModel(chapters, "dark")
	m.Update(tea.WindowSizeMsg{Width: 80, Height: 24})
	if m.mode != modeSplash {
		t.Fatal("the tour should open on the splash")
	}
	m.handleKey(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{'x'}})
	if m.mode != modeSplash {
		t.Fatal("random keys must not leave the title screen")
	}
	m.handleKey(tea.KeyMsg{Type: tea.KeyEnter})
	if m.mode != modeRead || m.index != 0 {
		t.Fatal("enter should press the start button into chapter 1")
	}
}

func TestQuizPhysics(t *testing.T) {
	q := newQuiz()
	q.width = 80
	q.handle("enter") // wrong answer (cursor 0, correct 1)
	if !q.shaking {
		t.Fatal("a wrong answer should kick the shake spring")
	}
	moved := false
	for i := 0; i < 200 && q.shaking; i++ {
		q.tick()
		if q.shakePos != 0 {
			moved = true
		}
	}
	if !moved {
		t.Fatal("the shake spring never moved")
	}
	if q.shaking {
		t.Fatal("the shake should settle")
	}

	// Answer everything right; the finale bursts confetti that gravity clears.
	q.handle("enter")
	for i := 0; i < 3; i++ {
		q.handle("down")
		q.handle("enter")
		q.handle("enter")
	}
	if !q.finished || len(q.confetti) == 0 {
		t.Fatalf("finishing should burst confetti (finished=%v particles=%d)", q.finished, len(q.confetti))
	}
	if !strings.Contains(q.view(), "✦") && !strings.Contains(q.view(), "●") {
		t.Fatal("confetti should be visible in the finale view")
	}
	for i := 0; i < 2000 && len(q.confetti) > 0; i++ {
		q.tick()
	}
	if len(q.confetti) != 0 {
		t.Fatal("gravity should eventually clear the confetti")
	}
}
