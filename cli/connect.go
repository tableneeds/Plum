package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/tableneeds/Plum/cli/internal/config"
	"github.com/tableneeds/Plum/cli/internal/detect"
	"github.com/tableneeds/Plum/cli/internal/sshsetup"
	"github.com/tableneeds/Plum/cli/internal/ui"
)

// cmdConnect is the guided setup `plum init` doesn't try to be: given just
// an IP or hostname, it makes sure a local SSH key exists, gets it onto the
// server, offers a ~/.ssh/config alias, and writes plum.yml — so nobody has
// to hand-edit YAML or remember ssh-keygen/ssh-copy-id flags to get started.
func cmdConnect(args []string) error {
	p := parseArgs(args)

	dir, err := projectDir(p.project)
	if err != nil {
		// connect is also how a brand-new project gets its first plum.yml —
		// "no plum.yml yet" here just means "use the current directory."
		dir = "."
	}

	host := p.remote // parseArgs treats the first bare argument as `remote`; here that's the host/IP.
	if host == "" {
		if host, err = ui.Input("Server IP or hostname", ""); err != nil {
			return err
		}
		if host == "" {
			return fmt.Errorf("a server IP or hostname is required")
		}
	}

	user, err := ui.Input("SSH user", "root")
	if err != nil {
		return err
	}

	ui.Blank()
	if err := ensureLocalSSHKey(); err != nil {
		return err
	}

	if !ui.Check(fmt.Sprintf("Key-based login to %s@%s already works", user, host), func() bool {
		return canConnect(user, host)
	}) {
		fmt.Println(ui.Dim("That's normal for a server you haven't connected to before."))
		copyKey, cerr := ui.Confirm("Copy your public key to the server now with ssh-copy-id? It'll ask for the server's password.", true)
		if cerr != nil {
			return cerr
		}
		if copyKey {
			if err := runInteractive("ssh-copy-id", "-o", "StrictHostKeyChecking=accept-new", user+"@"+host); err != nil {
				ui.Fail("ssh-copy-id failed: %v — you can copy the key manually and re-run `plum connect`.", err)
			} else if canConnect(user, host) {
				ui.Success("Key-based login now works.")
			} else {
				ui.Warn("Login still isn't passwordless — double check the server accepted the key.")
			}
		}
	}

	// Deployment shape decides which questions make sense: a plain ssh
	// remote needs a filesystem path, a once remote needs the app hostname
	// instead (the app lives in a container, not at a path), and a kamal
	// remote needs neither (config/deploy.yml already knows the servers).
	ui.Blank()
	detected := detect.Deployment(dir)
	defaultVia := string(config.ViaSSH)
	if detected.Via != "" {
		fmt.Println(ui.Dim(fmt.Sprintf("This repo has %s — that usually means a %s deployment.", detected.Evidence, detected.Via)))
		defaultVia = string(detected.Via)
	}
	viaAnswer, err := ui.Select("Deployment type", []ui.Choice{
		{Label: "ssh — the app lives at a path on the server", Value: "ssh"},
		{Label: "kamal — deployed with Kamal (config/deploy.yml)", Value: "kamal"},
		{Label: "once — deployed with 37signals Once", Value: "once"},
	}, defaultVia)
	if err != nil {
		return err
	}
	via := config.Via(strings.ToLower(viaAnswer))
	switch via {
	case config.ViaSSH, config.ViaKamal, config.ViaOnce:
	default:
		return fmt.Errorf("unknown deployment type %q (want ssh, kamal, or once)", via)
	}

	var path, onceApp string
	switch via {
	case config.ViaSSH:
		defaultPath := sshsetup.DefaultAppPath(filepath.Base(absOrDot(dir)))
		if path, err = ui.Input("Path to the Plum app on the server", defaultPath); err != nil {
			return err
		}
	case config.ViaOnce:
		if onceApp, err = ui.Input("App hostname (the --host you gave `once deploy`)", ""); err != nil {
			return err
		}
		if onceApp == "" {
			return fmt.Errorf("via: once needs the app's hostname to run `once exec` against")
		}
	}

	ui.Blank()
	sshConfigPath := filepath.Join(homeOrDot(), ".ssh", "config")
	remoteName, err := ui.Input("Name for this remote", "production")
	if err != nil {
		return err
	}
	alias := "plum-" + remoteName
	remoteHost, remoteUser := host, user
	addAlias, err := ui.Confirm(fmt.Sprintf("Add a %q alias to ~/.ssh/config so `ssh %s` also works?", alias, alias), true)
	if err != nil {
		return err
	}
	if addAlias {
		added, err := sshsetup.AppendAlias(sshConfigPath, alias, host, user)
		if err != nil {
			ui.Fail("couldn't write ~/.ssh/config: %v", err)
		} else if added {
			ui.Success("Added %q to %s", alias, sshConfigPath)
			remoteHost, remoteUser = alias, ""
		} else {
			ui.Warn("%q is already defined in %s — leaving it as-is.", alias, sshConfigPath)
			remoteHost, remoteUser = alias, ""
		}
	}

	cfg, err := config.LoadOrEmpty(dir)
	if err != nil {
		return err
	}
	newRemote := config.Remote{Host: remoteHost, User: remoteUser}
	switch via {
	case config.ViaSSH:
		newRemote.Path = path
	case config.ViaKamal:
		// Kamal owns its own connection through config/deploy.yml — plum.yml
		// records only the strategy. The host the user gave still matters
		// below, for checking/bootstrapping the server itself.
		newRemote = config.Remote{Via: config.ViaKamal}
	case config.ViaOnce:
		newRemote.Via = config.ViaOnce
		newRemote.OnceApp = onceApp
	}
	cfg.Remotes[remoteName] = newRemote
	if cfg.Default == "" {
		cfg.Default = remoteName
	}
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}
	if err := cfg.Save(dir); err != nil {
		return err
	}
	ui.Success("Wrote %s", filepath.Join(dir, config.FileName))

	target := remoteHost
	if remoteUser != "" {
		target = remoteUser + "@" + remoteHost
	}

	// Everything past this point talks to the server; if login doesn't work
	// yet, "docker isn't installed" would just be misreading a dead probe.
	if !sshProbe(target, "true") {
		ui.Warn("Can't reach the server over SSH yet, so skipping the server checks — re-run `plum connect` once login works.")
		ui.Blank()
		ui.Success("Done. Try: %s", ui.Bold("plum pull --project "+remoteName))
		return nil
	}

	if via != config.ViaSSH {
		if err := bootstrapServer(target, via); err != nil {
			return err
		}
	}

	ui.Blank()
	switch via {
	case config.ViaSSH:
		if !ui.Check("bin/rails exists at that path", func() bool {
			return sshProbe(target, "test -x "+shellQuote(path+"/bin/rails"))
		}) {
			fmt.Println(ui.Dim("Fine if you haven't deployed there yet — otherwise double-check the path."))
		}
	case config.ViaOnce:
		if !ui.Check(fmt.Sprintf("once lists %s", onceApp), func() bool {
			return sshProbe(target, "once list 2>/dev/null | grep -qF "+shellQuote(onceApp))
		}) {
			fmt.Println(ui.Dim(fmt.Sprintf("Deploy it with `once deploy <image> --host %s` and you're set.", onceApp)))
		}
	case config.ViaKamal:
		if _, err := exec.LookPath("kamal"); err != nil {
			if _, statErr := os.Stat(filepath.Join(dir, "bin", "kamal")); statErr != nil {
				ui.Warn("No kamal binary found locally — via: kamal shells out to it (`gem install kamal`).")
			}
		}
	}

	ui.Blank()
	ui.Success("Done. Try: %s %s", ui.Bold("plum pull --project "+remoteName), ui.Dim("(or just `plum pull` from "+dir+")"))
	return nil
}

func ensureLocalSSHKey() error {
	sshDir := filepath.Join(homeOrDot(), ".ssh")
	if path, found := sshsetup.HasKey(sshDir); found {
		ui.Success("Using existing SSH key %s", ui.Dim("("+path+")"))
		return nil
	}

	ui.Warn("No local SSH key found.")
	generate, err := ui.Confirm("Generate one now (ssh-keygen)?", true)
	if err != nil {
		return err
	}
	if !generate {
		return fmt.Errorf("an SSH key is required — generate one with ssh-keygen and re-run `plum connect`")
	}
	keyPath := sshsetup.DefaultKeyPath(sshDir)
	if err := os.MkdirAll(sshDir, 0o700); err != nil {
		return err
	}
	if err := runInteractive("ssh-keygen", "-t", "ed25519", "-f", keyPath); err != nil {
		return fmt.Errorf("ssh-keygen failed: %w", err)
	}
	ui.Success("Generated %s", keyPath)
	return nil
}

// bootstrapServer checks the server has the tooling its deployment shape
// needs — Docker Engine for both Kamal and Once, plus the once binary for
// Once — and offers to install what's missing. It never deploys the app
// itself: pushing images and registry credentials stay in the user's hands.
func bootstrapServer(target string, via config.Via) error {
	ui.Blank()
	ui.Step("Checking the server's tooling")

	var dockerVersion string
	if ui.Check("Docker Engine installed", func() bool {
		out, ok := sshCapture(target, "docker --version")
		dockerVersion = strings.TrimSpace(out)
		return ok
	}) {
		fmt.Println(ui.Dim("  " + dockerVersion))
	} else {
		ui.Warn("Docker isn't installed on the server — both Kamal and Once run apps as Docker containers.")
		install, err := ui.Confirm("Install Docker Engine now (runs `curl -fsSL https://get.docker.com | sh` on the server)?", true)
		if err != nil {
			return err
		}
		if install {
			if err := runInteractive("ssh", target, "curl -fsSL https://get.docker.com | sh"); err != nil {
				ui.Fail("Docker install failed: %v — install it manually and re-run `plum connect`.", err)
			} else {
				ui.Success("Docker installed.")
			}
		}
	}

	if via != config.ViaOnce {
		return nil
	}
	var onceVersion string
	if ui.Check("once installed", func() bool {
		out, ok := sshCapture(target, "once version")
		onceVersion = strings.TrimSpace(out)
		return ok
	}) {
		fmt.Println(ui.Dim("  " + onceVersion))
	} else {
		ui.Warn("The once binary isn't installed on the server.")
		install, err := ui.Confirm("Install it now (runs `curl https://get.once.com | sh` on the server)?", true)
		if err != nil {
			return err
		}
		if install {
			if err := runInteractive("ssh", target, "curl -fsSL https://get.once.com | sh"); err != nil {
				ui.Fail("once install failed: %v — install it manually and re-run `plum connect`.", err)
			} else {
				ui.Success("once installed.")
			}
		}
	}
	return nil
}

// canConnect probes key-based login without ever risking a password prompt
// (BatchMode=yes fails immediately instead of hanging or asking).
func canConnect(user, host string) bool {
	return sshProbe(user+"@"+host, "true")
}

func sshProbe(target, command string) bool {
	_, ok := sshCapture(target, command)
	return ok
}

func sshCapture(target, command string) (string, bool) {
	cmd := exec.Command("ssh",
		"-o", "BatchMode=yes",
		"-o", "ConnectTimeout=5",
		"-o", "StrictHostKeyChecking=accept-new",
		target, command)
	out, err := cmd.Output()
	return string(out), err == nil
}

func shellQuote(s string) string {
	if s == "" {
		return "''"
	}
	if !strings.ContainsAny(s, " \t\n'\"\\$&|;<>(){}[]*?~#`!") {
		return s
	}
	return "'" + strings.ReplaceAll(s, "'", `'\''`) + "'"
}

func runInteractive(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func homeOrDot() string {
	home, err := os.UserHomeDir()
	if err != nil {
		return "."
	}
	return home
}

func absOrDot(dir string) string {
	abs, err := filepath.Abs(dir)
	if err != nil {
		return dir
	}
	return abs
}
