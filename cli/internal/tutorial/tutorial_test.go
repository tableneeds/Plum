package tutorial

import (
	"path/filepath"
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
	m := newModel(chapters, "dark", newProgress(""))
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
	m := newModel(chapters, "dark", newProgress(""))
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
	m := newModel(chapters, "dark", newProgress(""))
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
	m := newModel(chapters, "dark", newProgress(""))
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
		t.Fatalf("finishing should start the confetti rain (finished=%v particles=%d)", q.finished, len(q.confetti))
	}
	if !strings.Contains(q.view(), "✦") && !strings.Contains(q.view(), "●") {
		t.Fatal("confetti should be visible in the finale view")
	}
	// The rain is continuous while the finale is up — particles keep
	// falling and respawning, bounded by the budget.
	for i := 0; i < 500; i++ {
		q.tick()
		if len(q.confetti) > 60 {
			t.Fatalf("confetti budget blown: %d particles", len(q.confetti))
		}
	}
	if len(q.confetti) == 0 {
		t.Fatal("the finale rain should keep falling, not peter out")
	}
	// Retaking the quiz turns the rain off.
	q.handle("r")
	if q.confettiOn || len(q.confetti) != 0 {
		t.Fatal("restarting the quiz should stop the confetti")
	}
}

func TestProgressRoundTripsAndRanks(t *testing.T) {
	path := filepath.Join(t.TempDir(), "tutorial.json")
	p := newProgress(path)
	if p.xp() != 0 || p.rank() != "Seedling" {
		t.Fatalf("fresh progress should be a Seedling with 0xp, got %s %dxp", p.rank(), p.xp())
	}
	p.markChapter("Welcome to Plum")
	p.markChapter("Welcome to Plum") // idempotent
	p.markDemo("Everyday commands")
	p.markTyping("Everyday commands")
	p.markQuiz()
	p.rememberChapter(5)
	if !p.recordScore(42) {
		t.Fatal("first score should be a new best")
	}
	if p.recordScore(10) {
		t.Fatal("a lower score is not a new best")
	}

	want := xpChapter + xpDemo + xpTyping + xpQuiz // 10+15+25+50 = 100
	if p.xp() != want {
		t.Fatalf("expected %dxp, got %d", want, p.xp())
	}
	if p.rank() != "Sapling" {
		t.Fatalf("100xp should rank Sapling, got %s", p.rank())
	}

	reloaded := newProgress(path)
	if reloaded.xp() != want || reloaded.LastChapter != 5 || reloaded.HighScore != 42 || !reloaded.QuizPassed {
		t.Fatalf("progress did not survive the round trip: %+v", reloaded)
	}
}

func TestTypingChallengeStrictInput(t *testing.T) {
	c := &typeChallenge{target: "plum pull"}
	for _, k := range []string{"p", "l", "u", "m", " "} {
		if c.key(k) {
			t.Fatal("challenge finished early")
		}
	}
	if c.typed != 5 {
		t.Fatalf("expected 5 correct chars, got %d", c.typed)
	}
	c.key("x") // wrong: rejected, counted, flashed
	if c.typed != 5 || c.misses != 1 || c.flash == 0 {
		t.Fatalf("wrong key should be rejected with a flash: typed=%d misses=%d", c.typed, c.misses)
	}
	c.key("backspace")
	if c.typed != 4 {
		t.Fatalf("backspace should rewind, typed=%d", c.typed)
	}
	done := false
	for _, k := range []string{" ", "p", "u", "l", "l"} {
		done = c.key(k)
	}
	if !done || !c.done {
		t.Fatal("finishing the command should complete the challenge")
	}
	if !strings.Contains(c.view(), "rolling the demo") {
		t.Fatal("completion should promise the demo")
	}
}

func TestTypingTargetsMatchDemoChapters(t *testing.T) {
	d := demos()
	for title := range typingTargets() {
		if _, ok := d[title]; !ok {
			t.Fatalf("typing chapter %q has no demo to roll afterwards", title)
		}
	}
}

func TestPlumDropIsEndless(t *testing.T) {
	g := newPlumDrop(60, 20)
	// Run long enough to spawn and resolve plenty of plums with the basket
	// chasing the nearest one — some get caught.
	for i := 0; i < 3000; i++ {
		if len(g.plums) > 0 {
			target := g.plums[0].pos.X
			if g.basketX < target {
				g.move(1.5)
			} else {
				g.move(-1.5)
			}
		}
		g.tick()
	}
	if g.caught == 0 {
		t.Fatal("a basket chasing plums should catch at least one")
	}
	// Park the basket in a corner and let everything drop: the game keeps
	// going forever — misses only break the streak.
	g2 := newPlumDrop(60, 20)
	for i := 0; i < 5000; i++ {
		g2.move(-99)
		g2.tick()
	}
	if g2.misses == 0 {
		t.Fatal("an abandoned basket should be dropping plums")
	}
	if g2.combo != 0 {
		t.Fatal("misses should break the combo")
	}
	if !strings.Contains(g2.view(0), "dropped") {
		t.Fatal("the header should own up to the dropped plums")
	}
}

func TestModelWiringForGameAndTyping(t *testing.T) {
	chapters, err := Chapters()
	if err != nil {
		t.Fatal(err)
	}
	m := newModel(chapters, "dark", newProgress(""))
	m.Update(tea.WindowSizeMsg{Width: 80, Height: 24})

	// p on the title screen opens the arcade; q concedes back to it.
	m.handleKey(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{'p'}})
	if m.mode != modeGame || m.game == nil {
		t.Fatal("p on the splash should start Plum Drop")
	}
	m.game.score = 7 // leaving the game must bank the run's score
	m.handleKey(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{'q'}})
	if m.mode != modeSplash {
		t.Fatal("q in the game should return to the title screen")
	}
	if m.prog.HighScore != 7 {
		t.Fatalf("quitting the game should bank the high score, got %d", m.prog.HighScore)
	}

	// t on a typing chapter starts the challenge; typing it out lands in
	// the demo and banks the XP.
	m.endSplash()
	for i, ch := range m.chapters {
		if ch.Title == "Everyday commands" {
			m.gotoChapter(i)
		}
	}
	m.handleKey(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{'t'}})
	if m.mode != modeType || m.typing == nil {
		t.Fatal("t should start the typing challenge")
	}
	for _, r := range "plum pull" {
		if r == ' ' {
			m.handleKey(tea.KeyMsg{Type: tea.KeySpace})
		} else {
			m.handleKey(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{r}})
		}
	}
	if !m.prog.TypingDone["Everyday commands"] {
		t.Fatal("completing the challenge should bank typing progress")
	}
	for i := 0; i < 60 && m.mode == modeType; i++ {
		m.Update(frameMsg{})
	}
	if m.mode != modeDemo {
		t.Fatal("the victory lap should roll into the demo")
	}
}
