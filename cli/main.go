// plum — the Plum CMS command line.
//
// Every command wraps a rake task that ships with the Plum engine; the CLI
// is transport (SSH + file copies) and ergonomics, never behavior. Servers
// for one site are defined in that site's plum.yml (see `plum init`).
// Managing many sites from one dev machine — without cd-ing into each repo
// — is what the global project registry (`plum use`, `plum projects`) is
// for; see internal/project.
package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/tableneeds/Plum/cli/internal/config"
	"github.com/tableneeds/Plum/cli/internal/project"
	"github.com/tableneeds/Plum/cli/internal/remote"
	"github.com/tableneeds/Plum/cli/internal/tutorial"
	"github.com/tableneeds/Plum/cli/internal/ui"
)

const version = "0.1.0"

type usageEntry struct{ invocation, description string }

var siteCommands = []usageEntry{
	{"plum tutorial", "Interactive guided tour of Plum and this CLI"},
	{"plum connect [ip-or-host]", "Guided setup: SSH key, server access, plum.yml"},
	{"plum init", "Create a starter plum.yml here (manual editing)"},
	{"plum pull [remote] [--yes]", "Replace your local site with the remote's"},
	{"plum push [remote] [--prune] [--force]", "Push plum/ config files to the remote"},
	{"plum check [remote]", "Fail if the remote drifted from plum/ files"},
	{"plum backup [remote]", "Create a timestamped site backup remotely"},
	{"plum logs [remote] [--follow]", "Show recent logs (--follow to tail)"},
	{"plum run [remote] -- TASK ...", "Run any rake task on the remote"},
}

var fleetCommands = []usageEntry{
	{"plum projects add NAME [path]", "Register a project (default path: .)"},
	{"plum projects list", "List registered projects"},
	{"plum projects remove NAME", "Forget a registered project"},
	{"plum use [NAME]", "Show or set the active project"},
}

func renderUsage() string {
	width := 0
	for _, e := range append(append([]usageEntry{}, siteCommands...), fleetCommands...) {
		if len(e.invocation) > width {
			width = len(e.invocation)
		}
	}
	section := func(b *strings.Builder, title, hint string, entries []usageEntry) {
		b.WriteString(ui.Bold(title) + " " + ui.Dim(hint) + "\n")
		for _, e := range entries {
			// Pad before styling: ANSI codes would break %-*s width math.
			padded := fmt.Sprintf("%-*s", width, e.invocation)
			b.WriteString("  " + ui.Accent(padded) + "  " + e.description + "\n")
		}
	}

	var b strings.Builder
	b.WriteString(ui.Bold("plum") + " " + ui.Dim(version) + " — the Plum CMS command line\n\n")
	section(&b, "Site commands", "(run from a project directory, or use --project / plum use)", siteCommands)
	b.WriteString("\n")
	section(&b, "Fleet commands", "(work from anywhere on this machine)", fleetCommands)
	b.WriteString("\n" + ui.Dim(`Every command accepts --project NAME to target a registered project without
switching the active one. Remotes are named in each project's plum.yml;
omit the remote name to use its default (or its only remote).`) + "\n")
	return b.String()
}

func main() {
	if len(os.Args) < 2 {
		fmt.Print(renderUsage())
		os.Exit(2)
	}

	var err error
	switch os.Args[1] {
	case "tutorial", "learn":
		err = cmdTutorial()
	case "connect":
		err = cmdConnect(os.Args[2:])
	case "init":
		err = cmdInit()
	case "pull":
		err = cmdPull(os.Args[2:])
	case "push":
		err = cmdPush(os.Args[2:])
	case "sync": // the old name for push; kept working, quietly steered
		fmt.Println(ui.Dim("(plum sync is now plum push — same command, clearer name)"))
		err = cmdPush(os.Args[2:])
	case "check":
		err = cmdCheck(os.Args[2:])
	case "backup":
		err = cmdBackup(os.Args[2:])
	case "logs":
		err = cmdLogs(os.Args[2:])
	case "run":
		err = cmdRun(os.Args[2:])
	case "use":
		err = cmdUse(os.Args[2:])
	case "projects":
		err = cmdProjects(os.Args[2:])
	case "version", "--version", "-v":
		fmt.Println("plum " + version)
	case "help", "--help", "-h":
		fmt.Print(renderUsage())
	default:
		fmt.Fprintf(os.Stderr, "unknown command %q\n\n", os.Args[1])
		fmt.Print(renderUsage())
		os.Exit(2)
	}

	if err != nil {
		if exit, ok := err.(*exec.ExitError); ok {
			os.Exit(exit.ExitCode())
		}
		if ui.Aborted(err) {
			os.Exit(130) // user hit Ctrl-C at a prompt; nothing to explain
		}
		ui.Error(err)
		os.Exit(1)
	}
}

type parsedArgs struct {
	remote  string
	project string
	flags   map[string]bool
	rest    []string
}

// parseArgs separates a remote name, an optional --project value, boolean
// flags, and (after "--") raw passthrough arguments. The first non-flag
// argument is taken as the remote name.
func parseArgs(args []string) parsedArgs {
	p := parsedArgs{flags: map[string]bool{}}
	afterDashes := false
	for i := 0; i < len(args); i++ {
		arg := args[i]
		switch {
		case arg == "--":
			afterDashes = true
		case afterDashes:
			p.rest = append(p.rest, arg)
		case arg == "--project" && i+1 < len(args):
			i++
			p.project = args[i]
		case strings.HasPrefix(arg, "--project="):
			p.project = strings.TrimPrefix(arg, "--project=")
		case strings.HasPrefix(arg, "--"):
			p.flags[strings.TrimPrefix(arg, "--")] = true
		case p.remote == "":
			p.remote = arg
		default:
			p.rest = append(p.rest, arg)
		}
	}
	return p
}

// projectDir resolves which directory's plum.yml a command should use:
// --project, then a local plum.yml, then the globally active project
// (`plum use`). See project.Registry.Resolve for the precedence rationale.
func projectDir(explicitProject string) (string, error) {
	reg, err := project.Load()
	if err != nil {
		return "", err
	}
	_, dir, err := reg.Resolve(explicitProject)
	return dir, err
}

func runner(explicitProject, remoteName string) (*remote.Runner, string, error) {
	dir, err := projectDir(explicitProject)
	if err != nil {
		return nil, "", err
	}
	cfg, err := config.LoadFrom(dir)
	if err != nil {
		return nil, "", err
	}
	name, rem, err := cfg.Resolve(remoteName)
	if err != nil {
		return nil, "", err
	}
	return &remote.Runner{Name: name, Remote: rem}, dir, nil
}

// cmdTutorial runs the full-screen tour on a terminal; piped, it prints
// the chapters as plain markdown so the content is still reachable.
func cmdTutorial() error {
	if !ui.Interactive() {
		chapters, err := tutorial.Chapters()
		if err != nil {
			return err
		}
		for i, ch := range chapters {
			if i > 0 {
				fmt.Print("\n---\n\n")
			}
			fmt.Println(strings.TrimSpace(ch.Body))
		}
		return nil
	}
	return tutorial.Run()
}

func cmdInit() error {
	if _, err := os.Stat(config.FileName); err == nil {
		return fmt.Errorf("%s already exists", config.FileName)
	}
	starter := `# Plum CLI configuration. Each remote is a server running your Plum app.
default: production

remotes:
  production:
    host: your-server.example.com
    user: deploy
    path: /var/www/your-site
    # rails: bin/rails                    # or a custom invocation

    # --- alternative transports (pick one instead of host/user/path/rails) ---
    # via: kamal                          # shells out to a local Kamal binary,
    #                                      # which already knows your servers
    #                                      # from config/deploy.yml
    # via: once                           # 37signals Once — its CLI runs ON
    # host: my-vps                        #  the server, so host is how to ssh
    # once_app: your-app.example.com      #  in and once_app is the hostname
    #                                      #  given to 'once deploy --host'

    # ssh_args: ["-p", "2222"]
`
	if err := os.WriteFile(config.FileName, []byte(starter), 0o644); err != nil {
		return err
	}
	ui.Success("Wrote %s — edit it to point at your server", config.FileName)
	fmt.Println(ui.Dim("Tip: `plum projects add <name>` registers this directory so `plum use <name>` works from anywhere."))
	return nil
}

// cmdPull replaces the local site with the remote's: export there, download,
// plum:site:replace here — "here" being the resolved project directory, not
// necessarily the current working directory.
func cmdPull(args []string) error {
	p := parseArgs(args)
	r, dir, err := runner(p.project, p.remote)
	if err != nil {
		return err
	}

	if !p.flags["yes"] {
		ok, cerr := ui.Confirm(fmt.Sprintf("Replace the local site in %s with the one on %q? All local content is overwritten.", dir, r.Name), false)
		if cerr != nil {
			return cerr
		}
		if !ok {
			return fmt.Errorf("aborted")
		}
	}

	stamp := time.Now().UTC().Format("20060102150405")
	remoteArchive := "/tmp/plum-pull-" + stamp + ".plum.zip"
	localArchive := os.TempDir() + "/plum-pull-" + stamp + "-local.plum.zip"
	defer r.RemoveFile(remoteArchive)
	defer os.Remove(localArchive)

	ui.Step("Exporting site on %s", r.Name)
	if err := r.RunRailsTo(ui.StreamWriter(os.Stdout), "plum:site:export", "ARCHIVE="+remoteArchive); err != nil {
		return err
	}
	if err := ui.Spin("Downloading archive", func() error {
		return r.Download(remoteArchive, localArchive)
	}); err != nil {
		return err
	}
	ui.Step("Replacing local site")
	local := &remote.Runner{Name: "local", Remote: config.Remote{Via: config.ViaSSH, Host: "local", Rails: "bin/rails", Path: dir}}
	if err := local.RunRailsTo(ui.StreamWriter(os.Stdout), "plum:site:replace", "ARCHIVE="+localArchive); err != nil {
		return err
	}
	ui.Success("Your local site now matches %s", r.Name)
	return nil
}

// cmdPush uploads the project's plum/ config directory and applies it
// remotely — push structure up, pull content down, the same asymmetry as
// "push code, pull data". The engine task keeps its plum:config:sync name;
// renaming the CLI verb doesn't change what runs on the server.
func cmdPush(args []string) error {
	p := parseArgs(args)
	return withUploadedConfig(p.project, p.remote, func(r *remote.Runner, remoteDir string) error {
		taskArgs := []string{"plum:config:sync", "DIR=" + remoteDir}
		if p.flags["prune"] {
			taskArgs = append(taskArgs, "PRUNE=1")
		}
		if p.flags["force"] {
			taskArgs = append(taskArgs, "FORCE=1")
		}
		ui.Step("Applying plum/ config on %s", r.Name)
		if err := r.RunRailsTo(ui.StreamWriter(os.Stdout), taskArgs...); err != nil {
			return err
		}
		ui.Success("Config applied on %s", r.Name)
		return nil
	})
}

// cmdCheck uploads plum/ and runs the drift check; the rake task's exit code
// (nonzero on drift) is propagated for CI.
func cmdCheck(args []string) error {
	p := parseArgs(args)
	return withUploadedConfig(p.project, p.remote, func(r *remote.Runner, remoteDir string) error {
		ui.Step("Checking config drift on %s", r.Name)
		if err := r.RunRailsTo(ui.StreamWriter(os.Stdout), "plum:config:check", "DIR="+remoteDir); err != nil {
			return err
		}
		ui.Success("No drift — %s matches plum/", r.Name)
		return nil
	})
}

func withUploadedConfig(explicitProject, remoteName string, apply func(*remote.Runner, string) error) error {
	r, dir, err := runner(explicitProject, remoteName)
	if err != nil {
		return err
	}
	localConfigDir := filepath.Join(dir, "plum")
	if _, err := os.Stat(localConfigDir); err != nil {
		return fmt.Errorf("no plum/ config directory in %s — run `bin/rails plum:config:export` there first", dir)
	}

	remoteDir := "/tmp/plum-config-" + time.Now().UTC().Format("20060102150405")
	if err := ui.Spin(fmt.Sprintf("Uploading plum/ to %s", r.Name), func() error {
		return r.UploadDir(localConfigDir, remoteDir)
	}); err != nil {
		return err
	}
	defer r.RemoveFile(remoteDir)
	return apply(r, remoteDir)
}

func cmdBackup(args []string) error {
	p := parseArgs(args)
	r, _, err := runner(p.project, p.remote)
	if err != nil {
		return err
	}
	ui.Step("Backing up site on %s", r.Name)
	return r.RunRailsTo(ui.StreamWriter(os.Stdout), "plum:backup:create")
}

func cmdLogs(args []string) error {
	p := parseArgs(args)
	r, _, err := runner(p.project, p.remote)
	if err != nil {
		return err
	}
	follow := p.flags["follow"] || p.flags["tail"]
	if follow {
		fmt.Println(ui.Dim(fmt.Sprintf("Streaming logs from %s — Ctrl-C to stop", r.Name)))
	}
	return r.LogsTo(ui.LogWriter(os.Stdout), follow)
}

func cmdRun(args []string) error {
	p := parseArgs(args)
	if len(p.rest) == 0 {
		return fmt.Errorf("usage: plum run [remote] [--project NAME] -- TASK [ENV=value ...]")
	}
	r, _, err := runner(p.project, p.remote)
	if err != nil {
		return err
	}
	return r.RunRails(p.rest...)
}

// cmdUse sets the globally active project, the Firebase-CLI-style default
// used whenever a command runs somewhere with no local plum.yml.
func cmdUse(args []string) error {
	if len(args) == 0 {
		reg, err := project.Load()
		if err != nil {
			return err
		}
		if reg.Active == "" {
			fmt.Println("No active project." + ui.Dim(" Set one with `plum use NAME` — see `plum projects list`."))
			return nil
		}
		fmt.Println(ui.Accent("● ") + ui.Bold(reg.Active) + "  " + ui.Dim(reg.Projects[reg.Active].Path))
		return nil
	}

	reg, err := project.Load()
	if err != nil {
		return err
	}
	if err := reg.SetActive(args[0]); err != nil {
		return err
	}
	if err := reg.Save(); err != nil {
		return err
	}
	ui.Success("Now using %q %s", args[0], ui.Dim("("+reg.Projects[args[0]].Path+")"))
	return nil
}

func cmdProjects(args []string) error {
	sub := "list"
	if len(args) > 0 {
		sub = args[0]
		args = args[1:]
	}

	reg, err := project.Load()
	if err != nil {
		return err
	}

	switch sub {
	case "list":
		if len(reg.Projects) == 0 {
			fmt.Println("No registered projects. Add one with `plum projects add NAME [path]`.")
			return nil
		}
		width := 0
		for _, name := range reg.Names() {
			if len(name) > width {
				width = len(name)
			}
		}
		for _, name := range reg.Names() {
			// Pad before styling: ANSI codes would break %-*s width math.
			padded := fmt.Sprintf("%-*s", width, name)
			if name == reg.Active {
				fmt.Println(ui.Accent("● ") + ui.Bold(padded) + "  " + ui.Dim(reg.Projects[name].Path))
			} else {
				fmt.Println("  " + padded + "  " + ui.Dim(reg.Projects[name].Path))
			}
		}
		return nil

	case "add":
		if len(args) == 0 {
			return fmt.Errorf("usage: plum projects add NAME [path]")
		}
		name := args[0]
		path := "."
		if len(args) > 1 {
			path = args[1]
		}
		if err := reg.Add(name, path); err != nil {
			return err
		}
		if err := reg.Save(); err != nil {
			return err
		}
		ui.Success("Registered %q → %s", name, reg.Projects[name].Path)
		return nil

	case "remove", "rm":
		if len(args) == 0 {
			return fmt.Errorf("usage: plum projects remove NAME")
		}
		if err := reg.Remove(args[0]); err != nil {
			return err
		}
		if err := reg.Save(); err != nil {
			return err
		}
		ui.Success("Removed %q", args[0])
		return nil

	default:
		return fmt.Errorf("unknown `plum projects` subcommand %q (want: list, add, remove)", sub)
	}
}
