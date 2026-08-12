package main

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/tableneeds/Plum/cli/internal/config"
	"github.com/tableneeds/Plum/cli/internal/detect"
	"github.com/tableneeds/Plum/cli/internal/sshsetup"
)

// cmdConnect is the guided setup `plum init` doesn't try to be: given just
// an IP or hostname, it makes sure a local SSH key exists, gets it onto the
// server, offers a ~/.ssh/config alias, and writes plum.yml — so nobody has
// to hand-edit YAML or remember ssh-keygen/ssh-copy-id flags to get started.
func cmdConnect(args []string) error {
	p := parseArgs(args)
	in := bufio.NewReader(os.Stdin)

	dir, err := projectDir(p.project)
	if err != nil {
		// connect is also how a brand-new project gets its first plum.yml —
		// "no plum.yml yet" here just means "use the current directory."
		dir = "."
	}

	host := p.remote // parseArgs treats the first bare argument as `remote`; here that's the host/IP.
	if host == "" {
		host = ask(in, "Server IP or hostname: ", "")
		if host == "" {
			return fmt.Errorf("a server IP or hostname is required")
		}
	}

	user := ask(in, "SSH user", "root")

	fmt.Println()
	if err := ensureLocalSSHKey(in); err != nil {
		return err
	}

	fmt.Printf("\nChecking whether key-based login to %s@%s already works...\n", user, host)
	if canConnect(user, host) {
		fmt.Println("✓ It does.")
	} else {
		fmt.Println("Not yet — that's normal for a server you haven't connected to before.")
		if confirm(in, "Copy your public key to the server now with ssh-copy-id? It'll ask for the server's password.", true) {
			if err := runInteractive("ssh-copy-id", "-o", "StrictHostKeyChecking=accept-new", user+"@"+host); err != nil {
				fmt.Fprintf(os.Stderr, "ssh-copy-id failed: %v\nYou can copy the key manually and re-run `plum connect`.\n", err)
			} else if canConnect(user, host) {
				fmt.Println("✓ Key-based login now works.")
			} else {
				fmt.Println("Login still isn't passwordless — double check the server accepted the key.")
			}
		}
	}

	// Deployment shape decides which questions make sense: a plain ssh
	// remote needs a filesystem path, a once remote needs the app hostname
	// instead (the app lives in a container, not at a path), and a kamal
	// remote needs neither (config/deploy.yml already knows the servers).
	fmt.Println()
	detected := detect.Deployment(dir)
	defaultVia := string(config.ViaSSH)
	if detected.Via != "" {
		fmt.Printf("This repo has %s — that usually means a %s deployment.\n", detected.Evidence, detected.Via)
		defaultVia = string(detected.Via)
	}
	via := config.Via(strings.ToLower(ask(in, "Deployment type (ssh, kamal, once)", defaultVia)))
	switch via {
	case config.ViaSSH, config.ViaKamal, config.ViaOnce:
	default:
		return fmt.Errorf("unknown deployment type %q (want ssh, kamal, or once)", via)
	}

	var path, onceApp string
	switch via {
	case config.ViaSSH:
		fmt.Println()
		defaultPath := sshsetup.DefaultAppPath(filepath.Base(absOrDot(dir)))
		path = ask(in, "Path to the Plum app on the server", defaultPath)
	case config.ViaOnce:
		fmt.Println()
		onceApp = ask(in, "App hostname (the --host you gave `once deploy`)", "")
		if onceApp == "" {
			return fmt.Errorf("via: once needs the app's hostname to run `once exec` against")
		}
	}

	fmt.Println()
	sshConfigPath := filepath.Join(homeOrDot(), ".ssh", "config")
	remoteName := ask(in, "Name for this remote", "production")
	alias := "plum-" + remoteName
	remoteHost, remoteUser := host, user
	if confirm(in, fmt.Sprintf("Add a %q alias to ~/.ssh/config so `ssh %s` also works?", alias, alias), true) {
		added, err := sshsetup.AppendAlias(sshConfigPath, alias, host, user)
		if err != nil {
			fmt.Fprintf(os.Stderr, "couldn't write ~/.ssh/config: %v\n", err)
		} else if added {
			fmt.Printf("✓ Added %q to %s\n", alias, sshConfigPath)
			remoteHost, remoteUser = alias, ""
		} else {
			fmt.Printf("%q is already defined in %s — leaving it as-is.\n", alias, sshConfigPath)
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
	fmt.Printf("\n✓ Wrote %s\n", filepath.Join(dir, config.FileName))

	target := remoteHost
	if remoteUser != "" {
		target = remoteUser + "@" + remoteHost
	}

	// Everything past this point talks to the server; if login doesn't work
	// yet, "docker isn't installed" would just be misreading a dead probe.
	if !sshProbe(target, "true") {
		fmt.Println("\nCan't reach the server over SSH yet, so skipping the server checks — re-run `plum connect` once login works.")
		fmt.Printf("\nDone. Try: plum pull --project %s (or just `plum pull` from %s)\n", remoteName, dir)
		return nil
	}

	if via != config.ViaSSH {
		bootstrapServer(in, target, via)
	}

	switch via {
	case config.ViaSSH:
		fmt.Println("\nChecking for a Plum app at that path...")
		if sshProbe(target, "test -x "+shellQuote(path+"/bin/rails")) {
			fmt.Println("✓ Found bin/rails there.")
		} else {
			fmt.Println("Couldn't confirm bin/rails at that path yet — fine if you haven't deployed there yet, otherwise double-check the path.")
		}
	case config.ViaOnce:
		fmt.Println("\nChecking once knows about that app...")
		if sshProbe(target, "once list 2>/dev/null | grep -qF "+shellQuote(onceApp)) {
			fmt.Printf("✓ once lists %s.\n", onceApp)
		} else {
			fmt.Printf("once doesn't list %s yet — deploy it with `once deploy <image> --host %s` and you're set.\n", onceApp, onceApp)
		}
	case config.ViaKamal:
		if _, err := exec.LookPath("kamal"); err != nil {
			if _, statErr := os.Stat(filepath.Join(dir, "bin", "kamal")); statErr != nil {
				fmt.Println("\nNote: no kamal binary found locally — via: kamal shells out to it (`gem install kamal`).")
			}
		}
	}

	fmt.Printf("\nDone. Try: plum pull --project %s (or just `plum pull` from %s)\n", remoteName, dir)
	return nil
}

// bootstrapServer checks the server has the tooling its deployment shape
// needs — Docker Engine for both Kamal and Once, plus the once binary for
// Once — and offers to install what's missing. It never deploys the app
// itself: pushing images and registry credentials stay in the user's hands.
func bootstrapServer(in *bufio.Reader, target string, via config.Via) {
	fmt.Println("\nChecking the server's tooling...")

	if out, ok := sshCapture(target, "docker --version"); ok {
		fmt.Printf("✓ Docker: %s\n", strings.TrimSpace(out))
	} else {
		fmt.Println("Docker isn't installed on the server — both Kamal and Once run apps as Docker containers.")
		if confirm(in, "Install Docker Engine now (runs `curl -fsSL https://get.docker.com | sh` on the server)?", true) {
			if err := runInteractive("ssh", target, "curl -fsSL https://get.docker.com | sh"); err != nil {
				fmt.Fprintf(os.Stderr, "Docker install failed: %v\nInstall it manually and re-run `plum connect`.\n", err)
			} else {
				fmt.Println("✓ Docker installed.")
			}
		}
	}

	if via != config.ViaOnce {
		return
	}
	if out, ok := sshCapture(target, "once version"); ok {
		fmt.Printf("✓ once: %s\n", strings.TrimSpace(out))
	} else {
		fmt.Println("The once binary isn't installed on the server.")
		if confirm(in, "Install it now (runs `curl https://get.once.com | sh` on the server)?", true) {
			if err := runInteractive("ssh", target, "curl -fsSL https://get.once.com | sh"); err != nil {
				fmt.Fprintf(os.Stderr, "once install failed: %v\nInstall it manually and re-run `plum connect`.\n", err)
			} else {
				fmt.Println("✓ once installed.")
			}
		}
	}
}

func ensureLocalSSHKey(in *bufio.Reader) error {
	sshDir := filepath.Join(homeOrDot(), ".ssh")
	if path, found := sshsetup.HasKey(sshDir); found {
		fmt.Printf("Using existing SSH key: %s\n", path)
		return nil
	}

	fmt.Println("No local SSH key found.")
	if !confirm(in, "Generate one now (ssh-keygen)?", true) {
		return fmt.Errorf("an SSH key is required — generate one with ssh-keygen and re-run `plum connect`")
	}
	keyPath := sshsetup.DefaultKeyPath(sshDir)
	if err := os.MkdirAll(sshDir, 0o700); err != nil {
		return err
	}
	if err := runInteractive("ssh-keygen", "-t", "ed25519", "-f", keyPath); err != nil {
		return fmt.Errorf("ssh-keygen failed: %w", err)
	}
	fmt.Printf("✓ Generated %s\n", keyPath)
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

func ask(in *bufio.Reader, prompt, def string) string {
	if def != "" {
		fmt.Printf("%s [%s]: ", prompt, def)
	} else {
		fmt.Printf("%s: ", prompt)
	}
	line, _ := in.ReadString('\n')
	line = strings.TrimSpace(line)
	if line == "" {
		return def
	}
	return line
}

func confirm(in *bufio.Reader, prompt string, def bool) bool {
	suffix := "[Y/n]"
	if !def {
		suffix = "[y/N]"
	}
	fmt.Printf("%s %s: ", prompt, suffix)
	line, _ := in.ReadString('\n')
	line = strings.ToLower(strings.TrimSpace(line))
	if line == "" {
		return def
	}
	return line == "y" || line == "yes"
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
