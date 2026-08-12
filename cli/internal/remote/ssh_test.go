package remote

import (
	"bytes"
	"os"
	"path/filepath"
	"testing"

	"github.com/tableneeds/Plum/cli/internal/config"
)

func TestSSHLogsTailsProductionLogLocally(t *testing.T) {
	dir := t.TempDir()
	logDir := filepath.Join(dir, "log")
	if err := os.MkdirAll(logDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(logDir, "production.log"), []byte("hello from the log\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	s := &sshStrategy{remote: config.Remote{Via: config.ViaSSH, Host: "local", Path: dir}}
	var out bytes.Buffer
	if err := s.logs(false, &out); err != nil {
		t.Fatal(err)
	}
	if !bytes.Contains(out.Bytes(), []byte("hello from the log")) {
		t.Fatalf("expected the log content to be tailed, got: %q", out.String())
	}
}

func TestSSHLogsRemoteCommandShapeFollowsFlag(t *testing.T) {
	dir := t.TempDir()
	argsOut := filepath.Join(dir, "args")
	fakeSSH(t, argsOut)

	s := &sshStrategy{remote: config.Remote{Host: "prod", Path: "/var/www/app"}}
	if err := s.logs(true, &bytes.Buffer{}); err != nil {
		t.Fatal(err)
	}

	got := readLines(t, argsOut)
	want := "tail -n 200 -f /var/www/app/log/production.log"
	if got[len(got)-1] != want {
		t.Fatalf("got %q, want %q", got[len(got)-1], want)
	}
}
