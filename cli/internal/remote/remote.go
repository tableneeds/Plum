// Package remote executes commands on a configured remote. Every Plum
// capability lives in the Rails app as a rake task; this package is only
// transport, dispatched by the remote's Via strategy:
//
//   - ssh (default): the system ssh/scp, inheriting ~/.ssh/config, agents,
//     and jump hosts.
//   - kamal: shells out to a local Kamal binary (`kamal app exec`), which
//     owns its own connection to the servers in config/deploy.yml. No host
//     or path needed in plum.yml — Kamal is dev-machine tooling.
//   - once: 37signals' single-container deploy tool. Unlike Kamal, once's
//     own CLI runs ON THE SERVER — this strategy ssh-es in (reusing the
//     same host/user/ssh_args as via: ssh) and runs `once exec ...` there.
package remote

import (
	"io"
	"os"
	"strings"

	"github.com/tableneeds/Plum/cli/internal/config"
)

type Runner struct {
	Name   string
	Remote config.Remote
}

// RunRails runs the given rails task (with ENV=value arguments) on the
// remote, streaming output to stdout/stderr.
func (r *Runner) RunRails(taskAndEnv ...string) error {
	return r.RunRailsTo(os.Stdout, taskAndEnv...)
}

// RunRailsTo is RunRails with the stdout stream redirected — used by
// commands that frame remote output (spinners, gutters) instead of letting
// it interleave raw.
func (r *Runner) RunRailsTo(out io.Writer, taskAndEnv ...string) error {
	return r.strategy().runRails(taskAndEnv, out)
}

// CaptureRails is RunRails but returns stdout, for commands whose output the
// CLI needs to parse (e.g. backup archive paths).
func (r *Runner) CaptureRails(taskAndEnv ...string) (string, error) {
	var out strings.Builder
	err := r.strategy().runRails(taskAndEnv, &out)
	return out.String(), err
}

// Download copies a file from the remote to a local path.
func (r *Runner) Download(remotePath, localPath string) error {
	return r.strategy().download(remotePath, localPath)
}

// UploadDir copies a local directory to a path on the remote, replacing
// whatever is already there.
func (r *Runner) UploadDir(localDir, remotePath string) error {
	return r.strategy().uploadDir(localDir, remotePath)
}

// RemoveFile best-effort deletes a temp file or directory on the remote.
func (r *Runner) RemoveFile(path string) {
	r.strategy().removeFile(path)
}

// Logs streams the app's logs (following them when follow is true) until
// the process is interrupted or the connection drops.
func (r *Runner) Logs(follow bool) error {
	return r.LogsTo(os.Stdout, follow)
}

// LogsTo is Logs with the output stream redirected — used by the CLI to
// route log lines through its prettifier on a terminal.
func (r *Runner) LogsTo(out io.Writer, follow bool) error {
	return r.strategy().logs(follow, out)
}

// strategy is the interface each Via implements; runner.go dispatches to it.
type strategy interface {
	runRails(taskAndEnv []string, stdout io.Writer) error
	download(remotePath, localPath string) error
	uploadDir(localDir, remotePath string) error
	removeFile(path string)
	logs(follow bool, stdout io.Writer) error
}

func (r *Runner) strategy() strategy {
	switch r.Remote.Via {
	case config.ViaKamal:
		return &kamalStrategy{remote: r.Remote}
	case config.ViaOnce:
		return &onceStrategy{remote: r.Remote}
	default:
		return &sshStrategy{remote: r.Remote}
	}
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

func railsCommandString(rails string, taskAndEnv []string) string {
	parts := make([]string, 0, len(taskAndEnv)+1)
	parts = append(parts, rails)
	for _, arg := range taskAndEnv {
		parts = append(parts, shellQuote(arg))
	}
	return strings.Join(parts, " ")
}
