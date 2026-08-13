package ui

import (
	"errors"
	"strings"
	"testing"
)

// Tests run without a TTY, so the styled paths that matter here are the
// pieces with real logic: the gutter writer's line framing (constructed
// directly, since StreamWriter would bypass it unstyled) and the plain
// fallbacks every pipe/CI run gets.

func TestGutterWriterFramesWholeLines(t *testing.T) {
	var out strings.Builder
	w := &gutterWriter{w: &out}

	if _, err := w.Write([]byte("first\nsecond\n")); err != nil {
		t.Fatal(err)
	}

	lines := strings.Split(strings.TrimRight(out.String(), "\n"), "\n")
	if len(lines) != 2 {
		t.Fatalf("expected 2 lines, got %d: %q", len(lines), out.String())
	}
	for _, line := range lines {
		if !strings.Contains(line, "│") {
			t.Fatalf("expected a gutter on every line, got %q", line)
		}
	}
}

func TestGutterWriterDoesNotRepeatGutterMidLine(t *testing.T) {
	var out strings.Builder
	w := &gutterWriter{w: &out}

	// A line delivered in two writes must get exactly one gutter.
	if _, err := w.Write([]byte("partial")); err != nil {
		t.Fatal(err)
	}
	if _, err := w.Write([]byte(" line\nnext\n")); err != nil {
		t.Fatal(err)
	}

	if got := strings.Count(out.String(), "│"); got != 2 {
		t.Fatalf("expected 2 gutters (one per logical line), got %d in %q", got, out.String())
	}
	if !strings.Contains(out.String(), "partial line\n") {
		t.Fatalf("split line was not reassembled: %q", out.String())
	}
}

func TestUnstyledHelpersAreIdentity(t *testing.T) {
	if Styled() {
		t.Skip("test environment unexpectedly has a TTY")
	}
	for _, s := range []string{"plain", ""} {
		if Dim(s) != s || Bold(s) != s || Accent(s) != s {
			t.Fatalf("unstyled helpers must not decorate %q", s)
		}
	}
}

func TestSpinUnstyledRunsFunctionAndPropagatesError(t *testing.T) {
	if Styled() {
		t.Skip("test environment unexpectedly has a TTY")
	}
	ran := false
	if err := Spin("working", func() error { ran = true; return nil }); err != nil {
		t.Fatal(err)
	}
	if !ran {
		t.Fatal("Spin never ran its function")
	}
	want := errors.New("boom")
	if err := Spin("failing", func() error { return want }); !errors.Is(err, want) {
		t.Fatalf("expected the function's error back, got %v", err)
	}
}

func TestFallbackSelectMatchesCaseInsensitively(t *testing.T) {
	choices := []Choice{{Label: "SSH", Value: "ssh"}, {Label: "Once", Value: "once"}}
	if got := matchChoice("ONCE", choices); got != "once" {
		t.Fatalf("expected case-insensitive match, got %q", got)
	}
	if got := matchChoice("unknown", choices); got != "unknown" {
		t.Fatalf("expected unknown answers passed through, got %q", got)
	}
}
