// Package project is the CLI's global, cross-directory memory — the
// Firebase-CLI-style `firebase use` model. Each Plum project directory
// already has its own plum.yml; this package just remembers *where* those
// directories are and which one is "active", so a fleet of sites can be
// managed from anywhere on the dev machine without `cd`-ing into each one.
package project

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"

	"gopkg.in/yaml.v3"
)

type Entry struct {
	Path string `yaml:"path"`
}

type Registry struct {
	Active   string           `yaml:"active"`
	Projects map[string]Entry `yaml:"projects"`

	path string // where this registry was loaded from / will be saved to
}

// Dir returns the directory the registry lives in
// (respects $XDG_CONFIG_HOME on Linux; the OS default elsewhere).
func Dir() (string, error) {
	base, err := os.UserConfigDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(base, "plum"), nil
}

func filePath() (string, error) {
	dir, err := Dir()
	if err != nil {
		return "", err
	}
	return filepath.Join(dir, "config.yml"), nil
}

// Load reads the global registry, returning an empty (not nil) Registry if
// none has been created yet — having no registered projects is the normal
// starting state, not an error.
func Load() (*Registry, error) {
	path, err := filePath()
	if err != nil {
		return nil, err
	}

	reg := &Registry{Projects: map[string]Entry{}, path: path}
	raw, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return reg, nil
		}
		return nil, err
	}
	if err := yaml.Unmarshal(raw, reg); err != nil {
		return nil, fmt.Errorf("%s: %w", path, err)
	}
	reg.path = path
	if reg.Projects == nil {
		reg.Projects = map[string]Entry{}
	}
	return reg, nil
}

func (r *Registry) Save() error {
	if err := os.MkdirAll(filepath.Dir(r.path), 0o755); err != nil {
		return err
	}
	raw, err := yaml.Marshal(r)
	if err != nil {
		return err
	}
	return os.WriteFile(r.path, raw, 0o644)
}

// Add registers a project directory under name. The directory must already
// contain a plum.yml — registering a placeholder invites a confusing
// "unknown project" failure later instead of a clear one now.
func (r *Registry) Add(name, dir string) error {
	abs, err := filepath.Abs(dir)
	if err != nil {
		return err
	}
	if _, err := os.Stat(filepath.Join(abs, "plum.yml")); err != nil {
		return fmt.Errorf("%s has no plum.yml — run `plum init` there first", abs)
	}
	r.Projects[name] = Entry{Path: abs}
	return nil
}

func (r *Registry) Remove(name string) error {
	if _, ok := r.Projects[name]; !ok {
		return fmt.Errorf("no registered project named %q", name)
	}
	delete(r.Projects, name)
	if r.Active == name {
		r.Active = ""
	}
	return nil
}

func (r *Registry) SetActive(name string) error {
	if _, ok := r.Projects[name]; !ok {
		return fmt.Errorf("no registered project named %q; run `plum projects add %s <path>` first", name, name)
	}
	r.Active = name
	return nil
}

func (r *Registry) Names() []string {
	names := make([]string, 0, len(r.Projects))
	for name := range r.Projects {
		names = append(names, name)
	}
	sort.Strings(names)
	return names
}

// Resolve picks the directory a command should load plum.yml from:
//
//  1. explicitProject (the --project flag), if given — must be registered.
//  2. The current directory, if it has a plum.yml — this is what lets
//     `cd ~/Work/Plum && plum pull` keep working with zero global state,
//     exactly like being "inside" a firebase project folder.
//  3. The registered active project (`plum use <name>`) — this is what
//     lets a fleet be managed from anywhere without cd-ing in first.
//
// Returns the project name for display (empty when resolved via the local
// plum.yml rather than the registry) and the directory to load it from.
func (r *Registry) Resolve(explicitProject string) (name string, dir string, err error) {
	if explicitProject != "" {
		entry, ok := r.Projects[explicitProject]
		if !ok {
			return "", "", fmt.Errorf("no registered project named %q; known projects: %v", explicitProject, r.Names())
		}
		return explicitProject, entry.Path, nil
	}

	if _, err := os.Stat("plum.yml"); err == nil {
		return "", ".", nil
	}

	if r.Active != "" {
		entry, ok := r.Projects[r.Active]
		if !ok {
			return "", "", fmt.Errorf("active project %q is no longer registered; run `plum use <name>`", r.Active)
		}
		return r.Active, entry.Path, nil
	}

	return "", "", fmt.Errorf(
		"no plum.yml here and no active project — run `plum init`, or `plum projects add <name> <path>` then `plum use <name>`",
	)
}
