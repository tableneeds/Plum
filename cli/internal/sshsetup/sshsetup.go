// Package sshsetup contains the pure, testable pieces of `plum connect`'s
// guided setup: picking sensible defaults and editing ~/.ssh/config. The
// interactive parts (prompting, shelling out to ssh-keygen/ssh-copy-id/ssh)
// live in cmdConnect itself, since they're not meaningfully unit-testable
// without a real terminal and a real server.
package sshsetup

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// commonKeyNames are checked in the order ssh itself prefers.
var commonKeyNames = []string{"id_ed25519", "id_ecdsa", "id_rsa"}

// HasKey reports whether any common private key already exists under dir
// (typically ~/.ssh), returning its path if so.
func HasKey(dir string) (path string, found bool) {
	for _, name := range commonKeyNames {
		candidate := filepath.Join(dir, name)
		if info, err := os.Stat(candidate); err == nil && !info.IsDir() {
			return candidate, true
		}
	}
	return "", false
}

// DefaultKeyPath is where a newly generated key should go.
func DefaultKeyPath(sshDir string) string {
	return filepath.Join(sshDir, "id_ed25519")
}

// DefaultAppPath guesses a plausible deploy path from the local project
// directory's name — just a starting point for the prompt, not a real guess
// at what's on the server.
func DefaultAppPath(projectDirName string) string {
	name := strings.TrimSpace(projectDirName)
	if name == "" || name == "." || name == "/" {
		name = "app"
	}
	return "/var/www/" + name
}

// AliasBlock renders a ~/.ssh/config Host entry.
func AliasBlock(alias, host, user string) string {
	var b strings.Builder
	fmt.Fprintf(&b, "Host %s\n", alias)
	fmt.Fprintf(&b, "  HostName %s\n", host)
	if user != "" {
		fmt.Fprintf(&b, "  User %s\n", user)
	}
	return b.String()
}

// HasAlias reports whether ~/.ssh/config already defines the given Host.
func HasAlias(configPath, alias string) (bool, error) {
	raw, err := os.ReadFile(configPath)
	if err != nil {
		if os.IsNotExist(err) {
			return false, nil
		}
		return false, err
	}
	target := "host " + strings.ToLower(alias)
	for _, line := range strings.Split(string(raw), "\n") {
		if strings.ToLower(strings.TrimSpace(line)) == target {
			return true, nil
		}
	}
	return false, nil
}

// AppendAlias adds a Host block to ~/.ssh/config, creating the file (and its
// directory) with the permissions ssh requires if it doesn't exist yet.
// Returns false without writing if the alias is already defined.
func AppendAlias(configPath, alias, host, user string) (added bool, err error) {
	exists, err := HasAlias(configPath, alias)
	if err != nil {
		return false, err
	}
	if exists {
		return false, nil
	}

	if err := os.MkdirAll(filepath.Dir(configPath), 0o700); err != nil {
		return false, err
	}

	block := AliasBlock(alias, host, user)
	current, err := os.ReadFile(configPath)
	if err != nil && !os.IsNotExist(err) {
		return false, err
	}
	separator := ""
	if len(current) > 0 && !strings.HasSuffix(string(current), "\n\n") {
		separator = "\n"
		if !strings.HasSuffix(string(current), "\n") {
			separator = "\n\n"
		}
	}

	file, err := os.OpenFile(configPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o600)
	if err != nil {
		return false, err
	}
	defer file.Close()
	if _, err := file.WriteString(separator + block); err != nil {
		return false, err
	}
	return true, nil
}
