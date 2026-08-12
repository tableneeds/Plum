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
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/tableneeds/Plum/cli/internal/config"
	"github.com/tableneeds/Plum/cli/internal/project"
	"github.com/tableneeds/Plum/cli/internal/remote"
)

const version = "0.1.0"

const usage = `plum %s — the Plum CMS command line

Site commands (run from a project directory, or use --project/plum use):
  plum connect [ip-or-host]       Guided setup: SSH key, server access, plum.yml
  plum init                       Create a starter plum.yml here (manual editing)
  plum pull [remote] [--yes]      Replace your local site with the remote's
  plum sync [remote] [--prune] [--force]
                                  Apply plum/ config files to the remote
  plum check [remote]             Fail if the remote drifted from plum/ files
  plum backup [remote]            Create a timestamped site backup remotely
  plum logs [remote] [--follow]   Show recent logs (--follow to tail)
  plum run [remote] -- TASK ...   Run any rake task on the remote

Fleet commands (work from anywhere on this machine):
  plum projects add NAME [path]   Register a project (default path: .)
  plum projects list              List registered projects
  plum projects remove NAME       Forget a registered project
  plum use NAME                   Set the active project

Every command accepts --project NAME to target a registered project without
switching the active one. Remotes are named in each project's plum.yml;
omit the remote name to use its default (or its only remote).
`

func main() {
	if len(os.Args) < 2 {
		fmt.Printf(usage, version)
		os.Exit(2)
	}

	var err error
	switch os.Args[1] {
	case "connect":
		err = cmdConnect(os.Args[2:])
	case "init":
		err = cmdInit()
	case "pull":
		err = cmdPull(os.Args[2:])
	case "sync":
		err = cmdSync(os.Args[2:])
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
		fmt.Printf(usage, version)
	default:
		fmt.Fprintf(os.Stderr, "unknown command %q\n\n", os.Args[1])
		fmt.Printf(usage, version)
		os.Exit(2)
	}

	if err != nil {
		if exit, ok := err.(*exec.ExitError); ok {
			os.Exit(exit.ExitCode())
		}
		fmt.Fprintln(os.Stderr, "plum: "+err.Error())
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
    # via: once                           # shells out to a local 'once' binary
    # host: your-app.example.com          # (once addresses apps by hostname)

    # ssh_args: ["-p", "2222"]
`
	if err := os.WriteFile(config.FileName, []byte(starter), 0o644); err != nil {
		return err
	}
	fmt.Println("Wrote " + config.FileName + " — edit it to point at your server")
	fmt.Println("Tip: `plum projects add <name>` registers this directory so `plum use <name>` works from anywhere.")
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
		fmt.Printf("Replace the local site in %s with the one on %q? All local content is overwritten. [y/N] ", dir, r.Name)
		reader := bufio.NewReader(os.Stdin)
		answer, _ := reader.ReadString('\n')
		if !strings.HasPrefix(strings.ToLower(strings.TrimSpace(answer)), "y") {
			return fmt.Errorf("aborted")
		}
	}

	stamp := time.Now().UTC().Format("20060102150405")
	remoteArchive := "/tmp/plum-pull-" + stamp + ".plum.zip"
	localArchive := os.TempDir() + "/plum-pull-" + stamp + "-local.plum.zip"
	defer r.RemoveFile(remoteArchive)
	defer os.Remove(localArchive)

	fmt.Printf("==> Exporting site on %s\n", r.Name)
	if err := r.RunRails("plum:site:export", "ARCHIVE="+remoteArchive); err != nil {
		return err
	}
	fmt.Println("==> Downloading archive")
	if err := r.Download(remoteArchive, localArchive); err != nil {
		return err
	}
	fmt.Println("==> Replacing local site")
	local := &remote.Runner{Name: "local", Remote: config.Remote{Via: config.ViaSSH, Host: "local", Rails: "bin/rails", Path: dir}}
	if err := local.RunRails("plum:site:replace", "ARCHIVE="+localArchive); err != nil {
		return err
	}
	fmt.Println("==> Done — your local site now matches " + r.Name)
	return nil
}

// cmdSync uploads the project's plum/ config directory and applies it
// remotely.
func cmdSync(args []string) error {
	p := parseArgs(args)
	return withUploadedConfig(p.project, p.remote, func(r *remote.Runner, remoteDir string) error {
		taskArgs := []string{"plum:config:sync", "DIR=" + remoteDir}
		if p.flags["prune"] {
			taskArgs = append(taskArgs, "PRUNE=1")
		}
		if p.flags["force"] {
			taskArgs = append(taskArgs, "FORCE=1")
		}
		return r.RunRails(taskArgs...)
	})
}

// cmdCheck uploads plum/ and runs the drift check; the rake task's exit code
// (nonzero on drift) is propagated for CI.
func cmdCheck(args []string) error {
	p := parseArgs(args)
	return withUploadedConfig(p.project, p.remote, func(r *remote.Runner, remoteDir string) error {
		return r.RunRails("plum:config:check", "DIR="+remoteDir)
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
	fmt.Printf("==> Uploading plum/ to %s\n", r.Name)
	if err := r.UploadDir(localConfigDir, remoteDir); err != nil {
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
	fmt.Printf("==> Backing up site on %s\n", r.Name)
	out, err := r.CaptureRails("plum:backup:create")
	fmt.Print(out)
	return err
}

func cmdLogs(args []string) error {
	p := parseArgs(args)
	r, _, err := runner(p.project, p.remote)
	if err != nil {
		return err
	}
	return r.Logs(p.flags["follow"] || p.flags["tail"])
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
			fmt.Println("No active project. Usage: plum use NAME")
			return nil
		}
		fmt.Println(reg.Active)
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
	fmt.Printf("Now using %q (%s)\n", args[0], reg.Projects[args[0]].Path)
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
		for _, name := range reg.Names() {
			marker := "  "
			if name == reg.Active {
				marker = "* "
			}
			fmt.Printf("%s%s\t%s\n", marker, name, reg.Projects[name].Path)
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
		fmt.Printf("Registered %q -> %s\n", name, reg.Projects[name].Path)
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
		fmt.Printf("Removed %q\n", args[0])
		return nil

	default:
		return fmt.Errorf("unknown `plum projects` subcommand %q (want: list, add, remove)", sub)
	}
}
