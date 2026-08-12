package detect

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/tableneeds/Plum/cli/internal/config"
)

func touch(t *testing.T, path string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(""), 0o644); err != nil {
		t.Fatal(err)
	}
}

func TestDetectsKamalFromDeployYML(t *testing.T) {
	dir := t.TempDir()
	touch(t, filepath.Join(dir, "config", "deploy.yml"))
	touch(t, filepath.Join(dir, "Dockerfile")) // both present: deploy.yml wins, it's the definitive signal

	got := Deployment(dir)
	if got.Via != config.ViaKamal {
		t.Fatalf("expected kamal, got %q", got.Via)
	}
}

func TestDetectsOnceFromBareDockerfile(t *testing.T) {
	dir := t.TempDir()
	touch(t, filepath.Join(dir, "Dockerfile"))

	got := Deployment(dir)
	if got.Via != config.ViaOnce {
		t.Fatalf("expected once, got %q", got.Via)
	}
}

func TestNoSignalWhenNeitherPresent(t *testing.T) {
	got := Deployment(t.TempDir())
	if got.Via != "" {
		t.Fatalf("expected no detection, got %q", got.Via)
	}
}

// `rails new` ships a placeholder config/deploy.yml — an unedited scaffold
// must not outrank the Dockerfile (regression: a repo deployed with Once got
// steered to a broken via: kamal remote).
func TestUneditedKamalScaffoldDoesNotOutrankDockerfile(t *testing.T) {
	dir := t.TempDir()
	write(t, filepath.Join(dir, "config", "deploy.yml"),
		"service: my-app\nimage: your-user/my-app\nservers:\n  web:\n    - 192.168.0.1\n")
	touch(t, filepath.Join(dir, "Dockerfile"))

	got := Deployment(dir)
	if got.Via != config.ViaOnce {
		t.Fatalf("expected once (scaffold deploy.yml ignored), got %q", got.Via)
	}
}

func TestScaffoldDeployYMLAloneGivesNoSignal(t *testing.T) {
	dir := t.TempDir()
	write(t, filepath.Join(dir, "config", "deploy.yml"), "servers:\n  web:\n    - 192.168.0.1\n")

	got := Deployment(dir)
	if got.Via != "" {
		t.Fatalf("expected no detection for a bare scaffold, got %q", got.Via)
	}
}

func TestCustomizedDeployYMLStillMeansKamal(t *testing.T) {
	dir := t.TempDir()
	write(t, filepath.Join(dir, "config", "deploy.yml"),
		"service: my-app\nimage: ghcr.io/me/my-app\nservers:\n  web:\n    - 203.0.113.5\n")
	touch(t, filepath.Join(dir, "Dockerfile"))

	got := Deployment(dir)
	if got.Via != config.ViaKamal {
		t.Fatalf("expected kamal for a customized deploy.yml, got %q", got.Via)
	}
}

func write(t *testing.T, path, content string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
}
