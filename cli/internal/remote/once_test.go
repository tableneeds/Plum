package remote

import (
	"bytes"
	"os"
	"path/filepath"
	"testing"

	"github.com/tableneeds/Plum/cli/internal/config"
)

// fakeSSH shadows the real `ssh` binary on PATH with a script that records
// its argv (one per line) — since once's own CLI runs on the server, every
// onceStrategy operation goes through a real `ssh` invocation, unlike the
// kamal/once-CLI-on-the-dev-machine model this replaced.
func fakeSSH(t *testing.T, argsOut string) {
	t.Helper()
	dir := t.TempDir()
	script := filepath.Join(dir, "ssh")
	body := "#!/bin/sh\n" +
		"for a in \"$@\"; do printf '%s\\n' \"$a\" >> " + shellQuote(argsOut) + "; done\n" +
		"cat >/dev/null\n"
	if err := os.WriteFile(script, []byte(body), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", dir+string(os.PathListSeparator)+os.Getenv("PATH"))
}

func TestOnceRunRailsGoesThroughSSHToTheOnceApp(t *testing.T) {
	dir := t.TempDir()
	argsOut := filepath.Join(dir, "args")
	fakeSSH(t, argsOut)

	o := &onceStrategy{remote: config.Remote{
		Host: "plum-production", User: "root", OnceApp: "finalwordsports.com", Rails: "bin/rails",
	}}
	if err := o.runRails([]string{"plum:site:export", "ARCHIVE=/tmp/x.zip"}, &bytes.Buffer{}); err != nil {
		t.Fatal(err)
	}

	got := readLines(t, argsOut)
	if len(got) != 2 {
		t.Fatalf("expected ssh target + remote command, got: %v", got)
	}
	if got[0] != "root@plum-production" {
		t.Fatalf("expected ssh to target the server (not the once app), got %q", got[0])
	}
	want := "once exec finalwordsports.com bin/rails plum:site:export ARCHIVE=/tmp/x.zip"
	if got[1] != want {
		t.Fatalf("remote command mismatch\n got: %q\nwant: %q", got[1], want)
	}
}

func TestOnceRunRailsUsesConfiguredOnceBinary(t *testing.T) {
	dir := t.TempDir()
	argsOut := filepath.Join(dir, "args")
	fakeSSH(t, argsOut)

	o := &onceStrategy{remote: config.Remote{
		Host: "prod", OnceApp: "app.example.com", OnceBin: "/opt/once/bin/once", Rails: "bin/rails",
	}}
	if err := o.runRails([]string{"plum:config:check"}, &bytes.Buffer{}); err != nil {
		t.Fatal(err)
	}

	got := readLines(t, argsOut)
	want := "/opt/once/bin/once exec app.example.com bin/rails plum:config:check"
	if got[len(got)-1] != want {
		t.Fatalf("got %q, want %q", got[len(got)-1], want)
	}
}

func TestOnceUploadDirWrapsInShAndTargetsTheOnceApp(t *testing.T) {
	dir := t.TempDir()
	argsOut := filepath.Join(dir, "args")
	fakeSSH(t, argsOut)
	srcDir := t.TempDir()
	if err := os.WriteFile(filepath.Join(srcDir, "a.yml"), []byte("x: 1\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	o := &onceStrategy{remote: config.Remote{Host: "plum-production", OnceApp: "finalwordsports.com"}}
	if err := o.uploadDir(srcDir, "/tmp/plum-config"); err != nil {
		t.Fatal(err)
	}

	got := readLines(t, argsOut)
	remoteCmd := got[len(got)-1]
	if !contains([]string{remoteCmd}, "once exec finalwordsports.com sh -c") {
		t.Fatalf("expected the compound command to go through once exec ... sh -c, got: %q", remoteCmd)
	}
	if !contains([]string{remoteCmd}, "tar xzf") {
		t.Fatalf("expected a tar extraction in the remote command, got: %q", remoteCmd)
	}
}

// Deployed once (v0.3.0) has no `logs` subcommand and the app container logs
// to Docker's stdout, so logs resolve the container by its `once` label and
// stream `docker logs` — not a once command at all.
func TestOnceLogsResolvesContainerByLabelAndFollows(t *testing.T) {
	dir := t.TempDir()
	argsOut := filepath.Join(dir, "args")
	fakeSSH(t, argsOut)

	o := &onceStrategy{remote: config.Remote{Host: "plum-production", OnceApp: "finalwordsports.com"}}
	if err := o.logs(true, &bytes.Buffer{}); err != nil {
		t.Fatal(err)
	}

	got := readLines(t, argsOut)
	remoteCmd := got[len(got)-1]
	for _, fragment := range []string{
		`docker ps --format '{{.Names}} {{.Label "once"}}'`,
		"grep -F finalwordsports.com",
		`docker logs --tail 200 -f "$c"`,
	} {
		if !contains([]string{remoteCmd}, fragment) {
			t.Fatalf("expected remote command to include %q, got: %q", fragment, remoteCmd)
		}
	}
}

func TestOnceLogsWithoutFollow(t *testing.T) {
	dir := t.TempDir()
	argsOut := filepath.Join(dir, "args")
	fakeSSH(t, argsOut)

	o := &onceStrategy{remote: config.Remote{Host: "plum-production", OnceApp: "finalwordsports.com"}}
	if err := o.logs(false, &bytes.Buffer{}); err != nil {
		t.Fatal(err)
	}

	got := readLines(t, argsOut)
	remoteCmd := got[len(got)-1]
	if !contains([]string{remoteCmd}, `docker logs --tail 200 "$c"`) {
		t.Fatalf("expected a non-follow docker logs command, got: %q", remoteCmd)
	}
	if contains([]string{remoteCmd}, "-f ") {
		t.Fatalf("did not expect -f without --follow, got: %q", remoteCmd)
	}
}

func TestOnceDownloadCatsThroughOnceExec(t *testing.T) {
	dir := t.TempDir()
	argsOut := filepath.Join(dir, "args")
	fakeSSH(t, argsOut)
	localPath := filepath.Join(dir, "out.zip")

	o := &onceStrategy{remote: config.Remote{Host: "plum-production", OnceApp: "finalwordsports.com"}}
	if err := o.download("/tmp/x.zip", localPath); err != nil {
		t.Fatal(err)
	}

	got := readLines(t, argsOut)
	want := "once exec finalwordsports.com cat /tmp/x.zip"
	if got[len(got)-1] != want {
		t.Fatalf("got %q, want %q", got[len(got)-1], want)
	}
	if _, err := os.Stat(localPath); err != nil {
		t.Fatalf("expected a local file to be created: %v", err)
	}
}
