package project

import (
	"os"
	"path/filepath"
	"testing"
)

func isolatedHome(t *testing.T) {
	t.Helper()
	t.Setenv("XDG_CONFIG_HOME", t.TempDir())
}

func projectDir(t *testing.T) string {
	t.Helper()
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, "plum.yml"), []byte("remotes:\n  prod:\n    host: x\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	return dir
}

func TestAddRequiresPlumYML(t *testing.T) {
	isolatedHome(t)
	reg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if err := reg.Add("bare", t.TempDir()); err == nil {
		t.Fatal("expected Add to reject a directory without plum.yml")
	}
}

func TestAddSaveLoadRoundTrips(t *testing.T) {
	isolatedHome(t)
	dir := projectDir(t)

	reg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if err := reg.Add("table-needs", dir); err != nil {
		t.Fatal(err)
	}
	if err := reg.SetActive("table-needs"); err != nil {
		t.Fatal(err)
	}
	if err := reg.Save(); err != nil {
		t.Fatal(err)
	}

	reloaded, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if reloaded.Active != "table-needs" {
		t.Fatalf("expected active project to persist, got %q", reloaded.Active)
	}
	if reloaded.Projects["table-needs"].Path != dir {
		t.Fatalf("expected path %q, got %q", dir, reloaded.Projects["table-needs"].Path)
	}
}

func TestSetActiveRequiresRegisteredProject(t *testing.T) {
	isolatedHome(t)
	reg, _ := Load()
	if err := reg.SetActive("ghost"); err == nil {
		t.Fatal("expected an error activating an unregistered project")
	}
}

func TestRemoveClearsActiveIfItWasTheRemovedProject(t *testing.T) {
	isolatedHome(t)
	dir := projectDir(t)
	reg, _ := Load()
	reg.Add("only", dir)
	reg.SetActive("only")

	if err := reg.Remove("only"); err != nil {
		t.Fatal(err)
	}
	if reg.Active != "" {
		t.Fatalf("expected active to clear after removing it, got %q", reg.Active)
	}
}

func TestResolvePrefersExplicitProjectOverEverything(t *testing.T) {
	isolatedHome(t)
	dir := projectDir(t)
	reg, _ := Load()
	reg.Add("named", dir)
	reg.SetActive("named")

	name, resolved, err := reg.Resolve("named")
	if err != nil {
		t.Fatal(err)
	}
	if name != "named" || resolved != dir {
		t.Fatalf("got (%q, %q)", name, resolved)
	}

	if _, _, err := reg.Resolve("nonexistent"); err == nil {
		t.Fatal("expected an error for an unregistered --project name")
	}
}

func TestResolveFallsBackToLocalPlumYMLThenActiveProject(t *testing.T) {
	isolatedHome(t)
	previous, _ := os.Getwd()
	t.Cleanup(func() { os.Chdir(previous) })

	// No local plum.yml, no active project: error.
	os.Chdir(t.TempDir())
	reg, _ := Load()
	if _, _, err := reg.Resolve(""); err == nil {
		t.Fatal("expected an error with nothing configured")
	}

	// An active project is used when the cwd has no plum.yml.
	activeDir := projectDir(t)
	reg.Add("fleet-member", activeDir)
	reg.SetActive("fleet-member")
	name, resolved, err := reg.Resolve("")
	if err != nil {
		t.Fatal(err)
	}
	if name != "fleet-member" || resolved != activeDir {
		t.Fatalf("got (%q, %q)", name, resolved)
	}

	// A local plum.yml wins even when a different project is active.
	localDir := projectDir(t)
	os.Chdir(localDir)
	name, resolved, err = reg.Resolve("")
	if err != nil {
		t.Fatal(err)
	}
	if name != "" || resolved != "." {
		t.Fatalf("expected local plum.yml to win, got (%q, %q)", name, resolved)
	}
}
