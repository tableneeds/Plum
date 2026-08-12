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
