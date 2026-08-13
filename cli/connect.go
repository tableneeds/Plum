package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/tableneeds/Plum/cli/internal/config"
	"github.com/tableneeds/Plum/cli/internal/detect"
	"github.com/tableneeds/Plum/cli/internal/project"
	"github.com/tableneeds/Plum/cli/internal/sshsetup"
	"github.com/tableneeds/Plum/cli/internal/ui"
)

// cmdConnect is the guided setup `plum init` doesn't try to be: given just
// an IP or hostname, it makes sure a local SSH key exists, gets it onto the
// server, offers a ~/.ssh/config alias, and writes plum.yml — so nobody has
// to hand-edit YAML or remember ssh-keygen/ssh-copy-id flags to get started.
func cmdConnect(args []string) error {
	p := parseArgs(args)

	dir, err := connectDir(p.project)
	if err != nil {
		return err
	}

	// Re-runs shouldn't start from scratch: whatever the default remote in
	// an existing plum.yml already says becomes each prompt's default, so
	// Enter-through-everything reproduces the current setup.
	existing, existingName := existingRemote(dir)

	// Better yet: an already-configured project doesn't need the interview
	// at all. Bare `plum connect` there means "check my setup still works" —
	// the wizard only runs on first setup, with --reconfigure, or when a new
	// host is given explicitly.
	if existingName != "" && p.remote == "" && !p.flags["reconfigure"] {
		registerProject(dir) // configured-but-unregistered projects get picked up here
		return connectStatus(existingName, existing)
	}

	sshConfigPath := filepath.Join(homeOrDot(), ".ssh", "config")

	host := p.remote // parseArgs treats the first bare argument as `remote`; here that's the host/IP.
	if host == "" {
		if host, err = askHost(existing.Host, sshConfigPath); err != nil {
			return err
		}
		if host == "" {
			return fmt.Errorf("a server IP or hostname is required")
		}
	}

	defaultUser := existing.User
	if defaultUser == "" {
		defaultUser = "root"
	}
	user, err := ui.Input("SSH user", defaultUser)
	if err != nil {
		return err
	}

	ui.Blank()
	if err := ensureLocalSSHKey(); err != nil {
		return err
	}

	loginOK := ui.Check(fmt.Sprintf("Key-based login to %s@%s already works", user, host), func() bool {
		return canConnect(user, host)
	})
	if !loginOK {
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
				loginOK = true
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
	if existing.Via != "" {
		// What the user chose last time beats what the repo's files suggest.
		defaultVia = string(existing.Via)
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
		defaultPath := existing.Path
		if defaultPath == "" {
			defaultPath = sshsetup.DefaultAppPath(filepath.Base(absOrDot(dir)))
		}
		if path, err = ui.Input("Path to the Plum app on the server", defaultPath); err != nil {
			return err
		}
	case config.ViaOnce:
		if onceApp, err = askOnceApp(user, host, existing.OnceApp, loginOK); err != nil {
			return err
		}
		if onceApp == "" {
			return fmt.Errorf("via: once needs the app's hostname to run `once exec` against")
		}
	}

	ui.Blank()
	defaultName := existingName
	if defaultName == "" {
		defaultName = "production"
	}
	remoteName, err := ui.Input("Name for this remote", defaultName)
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
	registerProject(dir)

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

// connectDir decides which directory connect operates on. Connect means
// "set up THIS directory" — unlike pull/push/logs it must never fall back
// to the globally active project, or running it in a fresh repo would
// silently target (and reconfigure!) whatever project happens to be
// active. Only an explicit --project redirects it.
func connectDir(explicitProject string) (string, error) {
	if explicitProject == "" {
		return ".", nil
	}
	reg, err := project.Load()
	if err != nil {
		return "", err
	}
	_, dir, err := reg.Resolve(explicitProject)
	return dir, err
}

// connectStatus is what a bare `plum connect` does on an already-configured
// project: show what plum.yml says and verify it still works, instead of
// asking questions whose answers are already on disk. Reports every failed
// check but only errors when one fails, so CI can use it as a doctor.
func connectStatus(name string, rem config.Remote) error {
	desc := "via " + ui.Bold(string(viaOrSSH(rem.Via)))
	if rem.Host != "" {
		desc += ", host " + ui.Bold(rem.Host)
	}
	switch {
	case rem.OnceApp != "":
		desc += ", app " + ui.Bold(rem.OnceApp)
	case rem.Path != "":
		desc += ", path " + ui.Bold(rem.Path)
	}
	fmt.Printf("This project is already connected to %q (%s).\n", name, desc)
	fmt.Println(ui.Dim("Checking it still works — reconfigure with `plum connect --reconfigure`, or `plum connect <ip-or-host>` for a new server."))
	ui.Blank()

	if viaOrSSH(rem.Via) == config.ViaKamal {
		// Kamal remotes store no host — the only thing to verify locally is
		// that the kamal binary this transport shells out to exists.
		if _, err := exec.LookPath("kamal"); err != nil {
			if _, statErr := os.Stat(filepath.Join("bin", "kamal")); statErr != nil {
				ui.Warn("No kamal binary found locally — via: kamal shells out to it (`gem install kamal`).")
				return fmt.Errorf("kamal binary not found")
			}
		}
		ui.Success("kamal binary found — Kamal owns the server connection from config/deploy.yml.")
		return nil
	}

	target := rem.Host
	if rem.User != "" {
		target = rem.User + "@" + rem.Host
	}

	ok := ui.Check("Key-based SSH login to "+target, func() bool {
		return sshProbe(target, "true")
	})
	if !ok {
		fmt.Println(ui.Dim("Fix SSH access first (or `plum connect --reconfigure` to walk through it again)."))
		return fmt.Errorf("can't reach %s over SSH", target)
	}

	failed := false
	switch viaOrSSH(rem.Via) {
	case config.ViaOnce:
		if !ui.Check("Docker Engine installed", func() bool {
			return sshProbe(target, "docker --version >/dev/null 2>&1")
		}) {
			failed = true
		}
		if !ui.Check("once installed", func() bool {
			return sshProbe(target, onceBinOrDefault(rem)+" version >/dev/null 2>&1")
		}) {
			failed = true
		}
		if !ui.Check("once lists "+rem.OnceApp, func() bool {
			return sshProbe(target, onceBinOrDefault(rem)+" list 2>/dev/null | grep -qF "+shellQuote(rem.OnceApp))
		}) {
			failed = true
		}
	default: // plain ssh
		path := rem.Path
		if path == "" {
			path = "."
		}
		if !ui.Check("bin/rails exists at "+path, func() bool {
			return sshProbe(target, "test -x "+shellQuote(path+"/bin/rails"))
		}) {
			failed = true
		}
	}

	ui.Blank()
	if failed {
		ui.Warn("Some checks failed — see above. Reconfigure with `plum connect --reconfigure`.")
		return fmt.Errorf("connection checks failed for %q", name)
	}
	ui.Success("Everything looks good.")
	return nil
}

func viaOrSSH(v config.Via) config.Via {
	if v == "" {
		return config.ViaSSH
	}
	return v
}

func onceBinOrDefault(rem config.Remote) string {
	if rem.OnceBin != "" {
		return rem.OnceBin
	}
	return "once"
}

// askHost asks which server to connect to. A fresh project isn't really a
// blank slate: any plum-* aliases in ~/.ssh/config are servers this CLI
// already set up, so they're offered as a pick-list first. Reconfigures
// prefill the stored host instead.
func askHost(previous, sshConfigPath string) (string, error) {
	if previous != "" {
		return ui.Input("Server IP or hostname", previous)
	}
	aliases := sshsetup.KnownAliases(sshConfigPath)
	if len(aliases) == 0 {
		return ui.Input("Server IP or hostname", "")
	}

	const newServer = "new"
	choices := make([]ui.Choice, 0, len(aliases)+1)
	for _, alias := range aliases {
		choices = append(choices, ui.Choice{Label: alias, Value: alias})
	}
	choices = append(choices, ui.Choice{Label: "a new server (type its ip or hostname)", Value: newServer})
	picked, err := ui.Select("Which server?", choices, aliases[0])
	if err != nil {
		return "", err
	}
	if picked == newServer {
		return ui.Input("Server IP or hostname", "")
	}
	return picked, nil
}

// registerProject adds the just-connected directory to the global project
// registry under its basename, so `plum use <name>` and `--project <name>`
// work immediately — nobody should have to run `plum projects add` for a
// project they just walked through connect for. Best-effort: a registry
// problem never fails the connect that got this far.
func registerProject(dir string) {
	abs := absOrDot(dir)
	reg, err := project.Load()
	if err != nil {
		return
	}
	for _, p := range reg.Projects {
		if absOrDot(p.Path) == abs {
			return // already registered, under whatever name the user chose
		}
	}
	name := filepath.Base(abs)
	if _, taken := reg.Projects[name]; taken {
		return // name collision with a different path — leave it to `plum projects add`
	}
	if err := reg.Add(name, abs); err != nil {
		return
	}
	activated := ""
	if reg.Active == "" {
		if err := reg.SetActive(name); err == nil {
			activated = " and made it the active project"
		}
	}
	if err := reg.Save(); err != nil {
		return
	}
	ui.Success("Registered project %q%s %s", name, activated, ui.Dim("(plum use "+name+")"))
}

// existingRemote returns the default remote from an existing plum.yml (and
// its name) so re-running connect prefills instead of interrogating from
// scratch. A missing or unreadable file just means no defaults.
func existingRemote(dir string) (config.Remote, string) {
	cfg, err := config.LoadOrEmpty(dir)
	if err != nil || cfg.Default == "" {
		return config.Remote{}, ""
	}
	rem, ok := cfg.Remotes[cfg.Default]
	if !ok {
		return config.Remote{}, ""
	}
	return rem, cfg.Default
}

// askOnceApp resolves which once app this repo is. The server already knows
// the answer — `once list` names every deployed app — so when login works
// this asks the server and offers a pick-list instead of a blank prompt.
// Falls back to free text (prefilled from plum.yml) when the server can't
// be asked or runs nothing yet.
func askOnceApp(user, host, previous string, loginOK bool) (string, error) {
	var apps []string
	if loginOK {
		ui.Check("Asking the server which once apps it runs", func() bool {
			out, ok := sshCapture(user+"@"+host, "once list 2>/dev/null")
			if ok {
				apps = parseOnceList(out)
			}
			return len(apps) > 0
		})
	}

	if len(apps) == 0 {
		return ui.Input("App hostname (the --host you gave `once deploy`)", previous)
	}

	const other = "other" // no real app hostname is bare "other"; typed hostnames pass through anyway
	choices := make([]ui.Choice, 0, len(apps)+1)
	def := ""
	for _, app := range apps {
		choices = append(choices, ui.Choice{Label: app, Value: app})
		if app == previous {
			def = app
		}
	}
	if def == "" {
		def = apps[0]
	}
	choices = append(choices, ui.Choice{Label: "something else (type it in)", Value: other})
	picked, err := ui.Select("Which app is this repo?", choices, def)
	if err != nil {
		return "", err
	}
	if picked == other {
		return ui.Input("App hostname (the --host you gave `once deploy`)", previous)
	}
	return picked, nil
}

// parseOnceList extracts each app's primary hostname from `once list`
// output, which arrives dressed in color and OSC 8 hyperlink escapes:
//
//	\x1b]8;;https://finalwordsports.com\x1b\\\x1b[94mfinalwordsports.com,www.finalwordsports.com\x1b[m\x1b]8;;\x1b\\ (running)
//
// The app identifier once wants is any of its hostnames; the first in the
// comma list is the one the user passed to `once deploy --host`.
func parseOnceList(out string) []string {
	var apps []string
	for _, line := range strings.Split(stripTerminalEscapes(out), "\n") {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		hosts := strings.Fields(line)[0]
		app := strings.TrimSpace(strings.Split(hosts, ",")[0])
		if app != "" {
			apps = append(apps, app)
		}
	}
	return apps
}

// stripTerminalEscapes removes CSI sequences (colors) and OSC sequences
// (hyperlinks) so parsers see the plain text a human would.
func stripTerminalEscapes(s string) string {
	var b strings.Builder
	for i := 0; i < len(s); {
		if s[i] != 0x1b {
			b.WriteByte(s[i])
			i++
			continue
		}
		i++ // consume ESC
		if i >= len(s) {
			break
		}
		switch s[i] {
		case '[': // CSI ... final byte in @-~
			i++
			for i < len(s) && (s[i] < 0x40 || s[i] > 0x7e) {
				i++
			}
			i++ // final byte
		case ']': // OSC ... terminated by BEL or ESC \
			i++
			for i < len(s) {
				if s[i] == 0x07 {
					i++
					break
				}
				if s[i] == 0x1b && i+1 < len(s) && s[i+1] == '\\' {
					i += 2
					break
				}
				i++
			}
		case '\\': // stray string terminator
			i++
		default: // two-byte escape (ESC c etc.)
			i++
		}
	}
	return b.String()
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
