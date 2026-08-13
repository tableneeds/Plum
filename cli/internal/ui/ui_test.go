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

// The exact JSON shape thruster emits in front of a Rails app, taken from a
// real production `docker logs` line.
const thrusterRequestLine = `{"time":"2026-08-12T22:41:27.775905575Z","level":"INFO","msg":"Request","path":"/up","status":200,"dur":2,"method":"GET","req_content_length":0,"req_content_type":"","resp_content_length":73,"resp_content_type":"text/html; charset=utf-8","remote_addr":"127.0.0.1:58290","user_agent":"curl/7.88.1","cache":"miss","query":"","proto":"HTTP/1.1"}`

func TestRenderLogLineCompactsRequestLines(t *testing.T) {
	got := renderLogLine(thrusterRequestLine)
	for _, want := range []string{"GET", "/up", "200", "(2ms)"} {
		if !strings.Contains(got, want) {
			t.Fatalf("expected %q in rendered line, got %q", want, got)
		}
	}
	for _, noisy := range []string{"user_agent", "req_content_length", "remote_addr"} {
		if strings.Contains(got, noisy) {
			t.Fatalf("noisy field %q should be dropped, got %q", noisy, got)
		}
	}
}

func TestRenderLogLineKeepsExtrasOnNonRequestLines(t *testing.T) {
	line := `{"time":"2026-08-12T23:27:45.361Z","level":"ERROR","msg":"Auto-update failed","app":"the-final-word.f5be72","error":"pull failed"}`
	got := renderLogLine(line)
	for _, want := range []string{"ERROR", "Auto-update failed", "app=the-final-word.f5be72", "error=pull failed"} {
		if !strings.Contains(got, want) {
			t.Fatalf("expected %q in rendered line, got %q", want, got)
		}
	}
}

func TestRenderLogLinePassesPlainTextThrough(t *testing.T) {
	for _, line := range []string{
		"Started GET \"/\" for 127.0.0.1 at 2026-08-13",
		"{not json at all",
		`{"json":"but not a log line"}`,
		"",
	} {
		if got := renderLogLine(line); got != line {
			t.Fatalf("expected passthrough for %q, got %q", line, got)
		}
	}
}

func TestLogLineWriterHandlesSplitLines(t *testing.T) {
	var out strings.Builder
	w := &logLineWriter{w: &out}
	half := len(thrusterRequestLine) / 2
	if _, err := w.Write([]byte(thrusterRequestLine[:half])); err != nil {
		t.Fatal(err)
	}
	if _, err := w.Write([]byte(thrusterRequestLine[half:] + "\n")); err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(out.String(), "GET") || !strings.Contains(out.String(), "/up") {
		t.Fatalf("split JSON line was not reassembled and rendered: %q", out.String())
	}
}
