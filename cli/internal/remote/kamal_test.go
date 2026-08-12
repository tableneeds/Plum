package remote

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/tableneeds/Plum/cli/internal/config"
)

// fakeBinary writes a shell script that records its argv (one per line) and
// echoes stdin, so strategy tests can assert on the exact command shape
// without needing a real kamal/once install or server.
func fakeBinary(t *testing.T, argsOut string) string {
	t.Helper()
	dir := t.TempDir()
	script := filepath.Join(dir, "fake")
	body := "#!/bin/sh\n" +
		"for a in \"$@\"; do printf '%s\\n' \"$a\" >> " + shellQuote(argsOut) + "; done\n" +
		"cat >/dev/null\n" // drain stdin so pipes never block, whether or not the test cares
	if err := os.WriteFile(script, []byte(body), 0o755); err != nil {
		t.Fatal(err)
	}
	return script
}

func TestKamalRunRailsBuildsExpectedArgv(t *testing.T) {
	dir := t.TempDir()
	argsOut := filepath.Join(dir, "args")
	bin := fakeBinary(t, argsOut)

	k := &kamalStrategy{remote: config.Remote{KamalBin: bin, Rails: "bin/rails"}}
	var out bytes.Buffer
	if err := k.runRails([]string{"plum:site:export", "ARCHIVE=/tmp/x.zip"}, &out); err != nil {
		t.Fatal(err)
	}

	got := readLines(t, argsOut)
	want := []string{"app", "exec", "--reuse", "--primary", "bin/rails plum:site:export ARCHIVE=/tmp/x.zip"}
	if !equalSlices(got, want) {
		t.Fatalf("argv mismatch\n got: %v\nwant: %v", got, want)
	}
}

func TestKamalRunRailsIncludesConfigAndDestination(t *testing.T) {
	dir := t.TempDir()
	argsOut := filepath.Join(dir, "args")
	bin := fakeBinary(t, argsOut)

	k := &kamalStrategy{remote: config.Remote{
		KamalBin: bin, Rails: "bin/rails",
		KamalConfig: "config/deploy.staging.yml", KamalDestination: "staging",
	}}
	if err := k.runRails([]string{"plum:config:check"}, &bytes.Buffer{}); err != nil {
		t.Fatal(err)
	}

	got := readLines(t, argsOut)
	if !contains(got, "--config-file=config/deploy.staging.yml") {
		t.Fatalf("expected --config-file in argv: %v", got)
	}
	if !contains(got, "--destination=staging") {
		t.Fatalf("expected --destination in argv: %v", got)
	}
}

func TestKamalUploadDirPassesStdinAndInteractiveFlag(t *testing.T) {
	dir := t.TempDir()
	argsOut := filepath.Join(dir, "args")
	bin := fakeBinary(t, argsOut)
	srcDir := t.TempDir()
	if err := os.WriteFile(filepath.Join(srcDir, "a.yml"), []byte("x: 1\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	k := &kamalStrategy{remote: config.Remote{KamalBin: bin}}
	if err := k.uploadDir(srcDir, "/tmp/plum-config"); err != nil {
		t.Fatal(err)
	}

	got := readLines(t, argsOut)
	if !contains(got, "--interactive") {
		t.Fatalf("expected --interactive when piping stdin: %v", got)
	}
	if !contains(got, "sh") {
		t.Fatalf("expected the compound command to go through sh -c: %v", got)
	}
}

func TestKamalLogsFollowAddsDashF(t *testing.T) {
	dir := t.TempDir()
	argsOut := filepath.Join(dir, "args")
	bin := fakeBinary(t, argsOut)

	k := &kamalStrategy{remote: config.Remote{KamalBin: bin}}
	if err := k.logs(true, &bytes.Buffer{}); err != nil {
		t.Fatal(err)
	}
	want := []string{"app", "logs", "-f"}
	if got := readLines(t, argsOut); !equalSlices(got, want) {
		t.Fatalf("got %v, want %v", got, want)
	}
}

func TestKamalLogsWithoutFollow(t *testing.T) {
	dir := t.TempDir()
	argsOut := filepath.Join(dir, "args")
	bin := fakeBinary(t, argsOut)

	k := &kamalStrategy{remote: config.Remote{KamalBin: bin}}
	if err := k.logs(false, &bytes.Buffer{}); err != nil {
		t.Fatal(err)
	}
	want := []string{"app", "logs"}
	if got := readLines(t, argsOut); !equalSlices(got, want) {
		t.Fatalf("got %v, want %v", got, want)
	}
}

func readLines(t *testing.T, path string) []string {
	t.Helper()
	content, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	return strings.Split(strings.TrimRight(string(content), "\n"), "\n")
}

func contains(haystack []string, needle string) bool {
	for _, s := range haystack {
		if strings.Contains(s, needle) {
			return true
		}
	}
	return false
}

func equalSlices(a, b []string) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}
