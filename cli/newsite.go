package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"

	"github.com/tableneeds/Plum/cli/internal/ui"
)

// cmdNew scaffolds a deploy-ready Plum site: rails new, the plum-cms gem,
// the install generator mounted at "/", a prepared database, and a git
// history — one command from empty directory to `bin/rails server`.
//
// It bootstraps its own toolchain the same way connect bootstraps a
// server: if Ruby or Rails are missing it offers to install them (via
// mise, installing mise itself first if needed), each step gated on
// explicit confirmation.
func cmdNew(args []string) error {
	p := parseArgs(args)
	name := p.remote // first bare argument
	if name == "" {
		return fmt.Errorf("usage: plum new NAME")
	}
	if _, err := os.Stat(name); err == nil {
		return fmt.Errorf("%s already exists", name)
	}
	if app := enclosingRailsApp(); app != "" {
		return fmt.Errorf("you're inside a Rails app (%s) — run plum new from a parent directory", app)
	}

	tc, err := ensureRailsToolchain()
	if err != nil {
		return err
	}

	ui.Blank()
	ui.Step("Creating a new Rails app: %s", name)
	if err := tc.stream("", "rails", "new", name); err != nil {
		return fmt.Errorf("rails new failed: %w", err)
	}

	ui.Step("Adding the plum-cms gem")
	if err := tc.stream(name, "bundle", "add", "plum-cms"); err != nil {
		return err
	}

	ui.Step("Installing Plum (mounted at /)")
	if err := tc.stream(name, "bin/rails", "generate", "plum:install", "--mount_path=/"); err != nil {
		return err
	}

	if err := ui.Spin("Preparing the database", func() error {
		return tc.run(name, "bin/rails", "db:prepare")
	}); err != nil {
		return err
	}

	// rails new made the first commit; Plum's installation is the second.
	// Commits are best-effort — a machine without a git identity shouldn't
	// fail the scaffold, just say so.
	if err := tc.run(name, "git", "add", "-A"); err == nil {
		if err := tc.run(name, "git", "commit", "-m", "Install Plum"); err != nil {
			ui.Warn("Couldn't commit (is your git identity set?) — the files are all there, commit when ready.")
		}
	}

	registerProject(name)

	abs := absOrDot(name)
	ui.Blank()
	ui.Success("Your Plum site is ready in %s", ui.Bold(abs))
	fmt.Println(ui.Dim("  Next steps:") + "\n" +
		"    " + ui.Accent("cd "+name) + ui.Dim("             # then bin/rails server → http://localhost:3000 (/cp is the control panel)") + "\n" +
		"    " + ui.Accent("plum connect <ip>") + ui.Dim("     # point it at a server (installs Docker + Once for you)") + "\n" +
		"    " + ui.Accent("plum deploy") + ui.Dim("           # build locally, ship over SSH — no registry needed"))
	return nil
}

// toolchain runs Ruby-ecosystem commands, optionally through `mise x --`
// when the tools were installed by us this session and aren't on PATH yet.
type toolchain struct {
	prefix []string
}

func (t *toolchain) command(dir string, name string, args ...string) *exec.Cmd {
	full := append(append([]string{}, t.prefix...), name)
	full = append(full, args...)
	cmd := exec.Command(full[0], full[1:]...)
	if dir != "" {
		cmd.Dir = dir
	}
	return cmd
}

// stream runs the command with its output framed in the dim gutter.
func (t *toolchain) stream(dir, name string, args ...string) error {
	cmd := t.command(dir, name, args...)
	out := ui.StreamWriter(os.Stdout)
	cmd.Stdout = out
	cmd.Stderr = out
	return cmd.Run()
}

// run executes quietly, for steps whose output nobody needs.
func (t *toolchain) run(dir, name string, args ...string) error {
	cmd := t.command(dir, name, args...)
	cmd.Stdout = nil
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func (t *toolchain) ok(name string, args ...string) bool {
	cmd := t.command("", name, args...)
	cmd.Stdout, cmd.Stderr = nil, nil
	return cmd.Run() == nil
}

// ensureRailsToolchain makes sure ruby + rails exist, offering installs
// (mise → ruby → rails) when they don't.
func ensureRailsToolchain() (*toolchain, error) {
	tc := &toolchain{}

	if !ui.Check("Ruby installed", func() bool { return tc.ok("ruby", "--version") }) {
		misePath, miseOK := findMise()
		if !miseOK {
			ui.Warn("No Ruby, and no mise (the toolchain manager) to install one with.")
			installMise, err := ui.Confirm("Install mise now? (runs `curl -fsSL https://mise.run | sh`)", true)
			if err != nil {
				return nil, err
			}
			if !installMise {
				return nil, fmt.Errorf("plum new needs Ruby — install it and re-run")
			}
			if err := runInteractive("sh", "-c", "curl -fsSL https://mise.run | sh"); err != nil {
				return nil, fmt.Errorf("mise install failed: %w", err)
			}
			misePath, miseOK = findMise()
			if !miseOK {
				return nil, fmt.Errorf("mise installed but not found — open a new shell and re-run `plum new`")
			}
			ui.Success("mise installed.")
		}

		installRuby, err := ui.Confirm("Install Ruby with mise? (runs `mise use -g ruby@3.4`)", true)
		if err != nil {
			return nil, err
		}
		if !installRuby {
			return nil, fmt.Errorf("plum new needs Ruby — install it and re-run")
		}
		if err := runInteractive(misePath, "use", "-g", "ruby@3.4"); err != nil {
			return nil, fmt.Errorf("ruby install failed: %w", err)
		}
		// The fresh Ruby isn't on this shell's PATH; run everything through
		// mise from here on.
		tc.prefix = []string{misePath, "x", "--"}
		if !tc.ok("ruby", "--version") {
			return nil, fmt.Errorf("ruby installed but not runnable via mise — open a new shell and re-run")
		}
		ui.Success("Ruby installed.")
	}

	if !ui.Check("Rails installed", func() bool { return tc.ok("rails", "--version") }) {
		installRails, err := ui.Confirm("Install Rails? (runs `gem install rails`)", true)
		if err != nil {
			return nil, err
		}
		if !installRails {
			return nil, fmt.Errorf("plum new needs Rails — `gem install rails` and re-run")
		}
		if err := ui.Spin("Installing Rails", func() error {
			return tc.run("", "gem", "install", "rails")
		}); err != nil {
			return nil, err
		}
	}
	return tc, nil
}

// enclosingRailsApp walks up from the working directory looking for a
// Rails app root — `rails new` refuses to nest apps, and its error is
// cryptic enough to be worth preempting.
func enclosingRailsApp() string {
	dir, err := os.Getwd()
	if err != nil {
		return ""
	}
	for {
		if _, err := os.Stat(filepath.Join(dir, "config", "application.rb")); err == nil {
			return dir
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			return ""
		}
		dir = parent
	}
}

// findMise looks on PATH and in mise's default install location.
func findMise() (string, bool) {
	if path, err := exec.LookPath("mise"); err == nil {
		return path, true
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return "", false
	}
	candidate := filepath.Join(home, ".local", "bin", "mise")
	if info, err := os.Stat(candidate); err == nil && !info.IsDir() && info.Mode()&0o111 != 0 {
		return candidate, true
	}
	return "", false
}
