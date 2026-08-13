package main

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/tableneeds/Plum/cli/internal/config"
)

// The exact shape `once list` v0.3.0 emits on Ben's server: OSC 8
// hyperlinks around a color-coded comma list of hostnames, then a status.
const onceListSample = "\x1b]8;;https://finalwordsports.com\x1b\\\x1b[94mfinalwordsports.com,www.finalwordsports.com\x1b[m\x1b]8;;\x1b\\ (running)\n" +
	"\x1b]8;;https://plumcms.org\x1b\\\x1b[94mplumcms.org,www.plumcms.org\x1b[m\x1b]8;;\x1b\\ (running)\n"

func TestParseOnceListExtractsPrimaryHostnames(t *testing.T) {
	apps := parseOnceList(onceListSample)
	want := []string{"finalwordsports.com", "plumcms.org"}
	if len(apps) != len(want) {
		t.Fatalf("expected %v, got %v", want, apps)
	}
	for i := range want {
		if apps[i] != want[i] {
			t.Fatalf("expected %v, got %v", want, apps)
		}
	}
}

func TestParseOnceListHandlesPlainAndEmptyOutput(t *testing.T) {
	if apps := parseOnceList("example.com (stopped)\n"); len(apps) != 1 || apps[0] != "example.com" {
		t.Fatalf("plain output should parse too, got %v", apps)
	}
	if apps := parseOnceList(""); len(apps) != 0 {
		t.Fatalf("empty output should yield no apps, got %v", apps)
	}
}

func TestStripTerminalEscapesLeavesPlainTextAlone(t *testing.T) {
	plain := "no escapes here, just text"
	if got := stripTerminalEscapes(plain); got != plain {
		t.Fatalf("got %q", got)
	}
}

func TestExistingRemotePrefillsFromDefault(t *testing.T) {
	dir := t.TempDir()
	yml := "default: production\nremotes:\n    production:\n        via: once\n        host: plum-production\n        once_app: finalwordsports.com\n"
	if err := os.WriteFile(filepath.Join(dir, config.FileName), []byte(yml), 0o644); err != nil {
		t.Fatal(err)
	}

	rem, name := existingRemote(dir)
	if name != "production" {
		t.Fatalf("expected the default remote's name, got %q", name)
	}
	if rem.Via != config.ViaOnce || rem.Host != "plum-production" || rem.OnceApp != "finalwordsports.com" {
		t.Fatalf("expected the stored remote back, got %+v", rem)
	}
}

func TestExistingRemoteIsEmptyWithoutConfig(t *testing.T) {
	rem, name := existingRemote(t.TempDir())
	if name != "" || rem.Host != "" || rem.Via != "" {
		t.Fatalf("expected zero values, got %q %+v", name, rem)
	}
}

// A configured project's bare `plum connect` is a health check, not an
// interview: with every ssh probe succeeding it must pass without reading
// a single prompt answer (stdin is empty here — any prompt would EOF into
// defaults and change behavior, so success proves no questions were asked).
func TestConnectStatusChecksWithoutPrompting(t *testing.T) {
	dir := t.TempDir()
	script := filepath.Join(dir, "ssh")
	if err := os.WriteFile(script, []byte("#!/bin/sh\nexit 0\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", dir+string(os.PathListSeparator)+os.Getenv("PATH"))

	rem := config.Remote{Via: config.ViaOnce, Host: "plum-production", OnceApp: "finalwordsports.com"}
	if err := connectStatus("production", rem); err != nil {
		t.Fatalf("expected all checks to pass, got %v", err)
	}
}

func TestConnectStatusFailsWhenServerUnreachable(t *testing.T) {
	dir := t.TempDir()
	script := filepath.Join(dir, "ssh")
	if err := os.WriteFile(script, []byte("#!/bin/sh\nexit 255\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", dir+string(os.PathListSeparator)+os.Getenv("PATH"))

	rem := config.Remote{Via: config.ViaOnce, Host: "gone", OnceApp: "app.example.com"}
	if err := connectStatus("production", rem); err == nil {
		t.Fatal("expected an error when SSH is unreachable")
	}
}
