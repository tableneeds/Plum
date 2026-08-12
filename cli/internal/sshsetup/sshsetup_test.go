package sshsetup

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestHasKeyFindsCommonNames(t *testing.T) {
	dir := t.TempDir()
	if _, found := HasKey(dir); found {
		t.Fatal("expected no key in an empty dir")
	}

	if err := os.WriteFile(filepath.Join(dir, "id_ed25519"), []byte("fake"), 0o600); err != nil {
		t.Fatal(err)
	}
	path, found := HasKey(dir)
	if !found || path != filepath.Join(dir, "id_ed25519") {
		t.Fatalf("expected to find the generated key, got %q %v", path, found)
	}
}

func TestDefaultAppPath(t *testing.T) {
	if got := DefaultAppPath("TableNeeds"); got != "/var/www/TableNeeds" {
		t.Fatalf("got %q", got)
	}
	if got := DefaultAppPath(""); got != "/var/www/app" {
		t.Fatalf("expected a fallback name, got %q", got)
	}
}

func TestAppendAliasCreatesFileAndSkipsDuplicates(t *testing.T) {
	dir := t.TempDir()
	configPath := filepath.Join(dir, "config")

	added, err := AppendAlias(configPath, "plum-production", "203.0.113.5", "deploy")
	if err != nil || !added {
		t.Fatalf("expected the alias to be added: %v %v", added, err)
	}
	info, err := os.Stat(configPath)
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode().Perm() != 0o600 {
		t.Fatalf("expected 0600 permissions on ssh config, got %v", info.Mode().Perm())
	}
	content, _ := os.ReadFile(configPath)
	if !strings.Contains(string(content), "Host plum-production") ||
		!strings.Contains(string(content), "HostName 203.0.113.5") ||
		!strings.Contains(string(content), "User deploy") {
		t.Fatalf("unexpected content:\n%s", content)
	}

	added, err = AppendAlias(configPath, "plum-production", "203.0.113.5", "deploy")
	if err != nil {
		t.Fatal(err)
	}
	if added {
		t.Fatal("expected a duplicate alias not to be re-added")
	}
}

func TestAppendAliasPreservesExistingEntries(t *testing.T) {
	dir := t.TempDir()
	configPath := filepath.Join(dir, "config")
	if err := os.WriteFile(configPath, []byte("Host github.com\n  User git\n"), 0o600); err != nil {
		t.Fatal(err)
	}

	added, err := AppendAlias(configPath, "plum-staging", "198.51.100.9", "root")
	if err != nil || !added {
		t.Fatalf("expected the alias to be added: %v %v", added, err)
	}

	content, _ := os.ReadFile(configPath)
	if !strings.Contains(string(content), "Host github.com") {
		t.Fatal("expected the pre-existing Host entry to survive")
	}
	if !strings.Contains(string(content), "Host plum-staging") {
		t.Fatal("expected the new Host entry to be appended")
	}
}

func TestHasAliasIsCaseInsensitiveAndMissingFileIsNotAnError(t *testing.T) {
	dir := t.TempDir()
	configPath := filepath.Join(dir, "does-not-exist")
	found, err := HasAlias(configPath, "anything")
	if err != nil || found {
		t.Fatalf("missing file should mean not found, no error: %v %v", found, err)
	}

	configPath2 := filepath.Join(dir, "config")
	os.WriteFile(configPath2, []byte("Host Plum-Production\n  HostName 1.2.3.4\n"), 0o600)
	found, err = HasAlias(configPath2, "plum-production")
	if err != nil || !found {
		t.Fatalf("expected a case-insensitive match: %v %v", found, err)
	}
}
