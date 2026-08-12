package remote

import (
	"io"
	"os"
	"strings"

	"github.com/tableneeds/Plum/cli/internal/config"
)

// onceStrategy reaches the app through Once (37signals' single-container
// deploy tool, built on kamal-proxy). Once itself runs *on* the server —
// there is no local once binary to shell out to — so this strategy ssh-es
// into the server (reusing the same host/user/ssh_args as via: ssh) and
// runs `once exec <app> <command>` there, once for every operation.
//
// The app is identified separately from the SSH target: `host` is how you
// reach the box (often an SSH config alias), `once_app` is the hostname you
// passed to `once deploy --host ...` when the app was installed. These are
// commonly different values — e.g. an SSH alias pointing at a bare IP vs.
// the app's real public DNS hostname.
//
// Per the once binary's own usage text ("exec <host> <command> [args...]"),
// the command and each argument are separate positional args to once, not a
// single shell string like Kamal's — but since the whole thing still has to
// travel as one ssh remote-command string, each token is shell-quoted here.
type onceStrategy struct {
	remote config.Remote
}

func (o *onceStrategy) runRails(taskAndEnv []string, stdout io.Writer) error {
	rails := o.remote.Rails
	if rails == "" {
		rails = "bin/rails"
	}
	tokens := append([]string{rails}, taskAndEnv...)
	return sshExec(o.remote, o.execCommand(tokens...), os.Stdin, stdout)
}

func (o *onceStrategy) download(remotePath, localPath string) error {
	out, err := os.Create(localPath)
	if err != nil {
		return err
	}
	defer out.Close()
	return sshExec(o.remote, o.execCommand("cat", remotePath), nil, out)
}

func (o *onceStrategy) uploadDir(localDir, remotePath string) error {
	pr, pw := io.Pipe()
	go func() {
		pw.CloseWithError(tarDir(localDir, pw))
	}()
	script := "rm -rf " + shellQuote(remotePath) + " && mkdir -p " + shellQuote(remotePath) +
		" && tar xzf - -C " + shellQuote(remotePath)
	return sshExec(o.remote, o.execCommand("sh", "-c", script), pr, os.Stdout)
}

func (o *onceStrategy) removeFile(path string) {
	_ = sshExec(o.remote, o.execCommand("rm", "-rf", path), nil, os.Stdout)
}

// logs streams the app container's `docker logs`. Deployed once (v0.3.0)
// has no logs subcommand, and the Rails image logs to the container's
// stdout — there is no log/production.log inside it — so the one place the
// logs exist is the Docker daemon once itself drives. Once labels each app
// container with a `once` label whose JSON carries the app's hostnames;
// grepping that label for once_app finds the right container even when the
// server runs several apps.
func (o *onceStrategy) logs(follow bool, stdout io.Writer) error {
	flag := ""
	if follow {
		flag = " -f"
	}
	script := `c="$(docker ps --format '{{.Names}} {{.Label "once"}}' | grep -F ` + shellQuote(o.remote.OnceApp) + ` | head -n 1 | cut -d' ' -f1)"; ` +
		`if [ -n "$c" ]; then docker logs --tail 200` + flag + ` "$c" 2>&1; ` +
		`else echo ` + shellQuote("plum: no running once app matching "+o.remote.OnceApp) + ` >&2; exit 1; fi`
	return sshExec(o.remote, script, nil, stdout)
}

// execCommand builds `<once_bin> exec <once_app> <tokens...>` as one
// shell-quoted string suitable for handing to ssh as its remote command.
func (o *onceStrategy) execCommand(tokens ...string) string {
	bin := o.remote.OnceBin
	if bin == "" {
		bin = "once"
	}
	parts := append([]string{bin, "exec", shellQuote(o.remote.OnceApp)}, quoteAll(tokens)...)
	return strings.Join(parts, " ")
}

func quoteAll(tokens []string) []string {
	quoted := make([]string, len(tokens))
	for i, t := range tokens {
		quoted[i] = shellQuote(t)
	}
	return quoted
}
