// Package config loads plum.yml, the project file that names the servers
// ("remotes") a Plum site can talk to.
package config

import (
	"fmt"
	"os"
	"path/filepath"

	"gopkg.in/yaml.v3"
)

// Via selects how a remote's commands actually reach the server. The CLI's
// job is transport, not behavior — every strategy below ends up running the
// exact same `bin/rails plum:...` task, just through a different door.
type Via string

const (
	// ViaSSH runs commands over the system ssh/scp — the default. Works
	// against any server; requires host/user/path.
	ViaSSH Via = "ssh"
	// ViaKamal shells out to a local Kamal binary (`kamal app exec`), which
	// handles its own SSH connection using config/deploy.yml. No host/path
	// needed in plum.yml — Kamal already knows where the app lives.
	ViaKamal Via = "kamal"
	// ViaOnce reaches an app deployed with Once, 37signals' single-container
	// deploy tool built on kamal-proxy. Once's CLI runs ON THE SERVER, not
	// on your dev machine — this strategy ssh-es in (like ViaSSH: host,
	// user, ssh_args) and runs `once exec <once_app> ...` there.
	ViaOnce Via = "once"
)

type Remote struct {
	// Via selects the transport. Default: ssh.
	Via Via `yaml:"via,omitempty"`

	// --- via: ssh ---
	// Host is the SSH host. The special value "local" (or empty, with Via
	// unset/ssh) runs commands on this machine instead of over SSH.
	Host string `yaml:"host,omitempty"`
	User string `yaml:"user,omitempty"`
	// Path is the application root on the server (where bin/rails lives).
	Path string `yaml:"path,omitempty"`
	// Rails is how to invoke rails inside Path. Defaults to "bin/rails".
	Rails string `yaml:"rails,omitempty"`
	// SSHArgs are extra arguments passed to ssh/scp (port, identity, ...).
	SSHArgs []string `yaml:"ssh_args,omitempty"`

	// --- via: kamal ---
	// KamalBin is the kamal executable to run locally. Default: "bin/kamal"
	// if it exists in the working directory, else "kamal" on PATH.
	KamalBin string `yaml:"kamal_bin,omitempty"`
	// KamalConfig points at a non-default deploy config
	// (kamal app exec --config-file=...).
	KamalConfig string `yaml:"kamal_config,omitempty"`
	// KamalDestination selects a destination file, e.g. "staging" for
	// config/deploy.staging.yml (kamal app exec --destination=...).
	KamalDestination string `yaml:"kamal_destination,omitempty"`

	// --- via: once ---
	// Reuses Host/User/SSHArgs above to reach the server. OnceApp is the
	// app's Once-registered hostname — the value passed to
	// `once deploy --host ...` when the app was installed — which is often
	// different from Host (an SSH alias/IP for the box itself).
	OnceApp string `yaml:"once_app,omitempty"`

	// PreviewHost, when set, is where `plum deploy --preview` ships —
	// e.g. client.preview.your-agency.com behind a wildcard A record.
	// Left empty, previews auto-derive <app>.<server-ip>.sslip.io.
	PreviewHost string `yaml:"preview_host,omitempty"`
	// OnceBin is the once executable's name/path ON THE SERVER (not local).
	// Default: "once".
	OnceBin string `yaml:"once_bin,omitempty"`
}

type Config struct {
	Default string            `yaml:"default,omitempty"`
	Remotes map[string]Remote `yaml:"remotes"`
}

const FileName = "plum.yml"

// Load reads plum.yml from the current directory.
func Load() (*Config, error) {
	return LoadFrom(".")
}

// LoadFrom reads plum.yml from a specific directory — used when a command's
// project comes from the global registry (`plum use`) rather than the
// working directory. See internal/project.
func LoadFrom(dir string) (*Config, error) {
	path := filepath.Join(dir, FileName)
	raw, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, fmt.Errorf("no %s — run `plum init` in %s to create one", path, dir)
		}
		return nil, err
	}
	return Parse(raw)
}

// LoadOrEmpty is LoadFrom, but a missing plum.yml returns a fresh empty
// Config instead of an error — for commands like `plum connect` that create
// or add to plum.yml rather than requiring it to already exist.
func LoadOrEmpty(dir string) (*Config, error) {
	cfg, err := LoadFrom(dir)
	if err == nil {
		return cfg, nil
	}
	if _, statErr := os.Stat(filepath.Join(dir, FileName)); os.IsNotExist(statErr) {
		return &Config{Remotes: map[string]Remote{}}, nil
	}
	return nil, err
}

// Save writes the config back to plum.yml in dir. Comments and formatting in
// a hand-edited file are not preserved — callers that create plum.yml
// programmatically (`plum connect`) accept that trade for not requiring
// manual YAML editing; callers that want a commented starter file write one
// directly instead (see cmdInit).
func (c *Config) Save(dir string) error {
	raw, err := yaml.Marshal(c)
	if err != nil {
		return err
	}
	return os.WriteFile(filepath.Join(dir, FileName), raw, 0o644)
}

func Parse(raw []byte) (*Config, error) {
	cfg := &Config{}
	if err := yaml.Unmarshal(raw, cfg); err != nil {
		return nil, fmt.Errorf("%s: %w", FileName, err)
	}
	if len(cfg.Remotes) == 0 {
		return nil, fmt.Errorf("%s defines no remotes", FileName)
	}
	return cfg, nil
}

// Resolve picks the remote by name, falling back to the configured default,
// falling back to the only remote if exactly one is defined, and fills in
// per-strategy defaults.
func (c *Config) Resolve(name string) (string, Remote, error) {
	if name == "" {
		name = c.Default
	}
	if name == "" && len(c.Remotes) == 1 {
		for only := range c.Remotes {
			name = only
		}
	}
	if name == "" {
		return "", Remote{}, fmt.Errorf("multiple remotes defined; pass one of %v or set `default:` in %s", c.Names(), FileName)
	}
	remote, ok := c.Remotes[name]
	if !ok {
		return "", Remote{}, fmt.Errorf("unknown remote %q; defined remotes: %v", name, c.Names())
	}

	switch remote.Via {
	case "":
		remote.Via = ViaSSH
	case ViaSSH, ViaKamal, ViaOnce:
		// valid
	default:
		return "", Remote{}, fmt.Errorf("remote %q: unknown via %q (want ssh, kamal, or once)", name, remote.Via)
	}

	switch remote.Via {
	case ViaSSH:
		if remote.Rails == "" {
			remote.Rails = "bin/rails"
		}
	case ViaKamal:
		if remote.KamalBin == "" {
			remote.KamalBin = defaultKamalBin()
		}
	case ViaOnce:
		if remote.OnceBin == "" {
			remote.OnceBin = "once"
		}
		if remote.Host == "" {
			return "", Remote{}, fmt.Errorf("remote %q: via: once requires `host:` (how to ssh into the server running once)", name)
		}
		if remote.OnceApp == "" {
			return "", Remote{}, fmt.Errorf("remote %q: via: once requires `once_app:` (the hostname passed to `once deploy --host ...`)", name)
		}
	}

	return name, remote, nil
}

func defaultKamalBin() string {
	if info, err := os.Stat("bin/kamal"); err == nil && !info.IsDir() {
		return "bin/kamal"
	}
	return "kamal"
}

func (c *Config) Names() []string {
	names := make([]string, 0, len(c.Remotes))
	for name := range c.Remotes {
		names = append(names, name)
	}
	return names
}

// IsLocal is only meaningful for via: ssh — kamal/once always shell out to a
// local binary that itself reaches the remote server.
func (r Remote) IsLocal() bool {
	return r.Via == ViaSSH && (r.Host == "" || r.Host == "local")
}
