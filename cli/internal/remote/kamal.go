package remote

import (
	"fmt"
	"io"
	"os"

	"github.com/tableneeds/Plum/cli/internal/config"
)

// kamalStrategy shells out to a local Kamal binary. Kamal owns its own SSH
// connection via config/deploy.yml, so plum.yml needs no host or path — only
// `via: kamal` (and optionally kamal_bin/kamal_config/kamal_destination).
//
// The container's WORKDIR is the app root already (that's how the bundled
// deploy.yml's own aliases work — see `console: app exec --reuse "bin/rails
// console"`), so unlike ssh there's no `cd` to do.
type kamalStrategy struct {
	remote config.Remote
}

func (k *kamalStrategy) runRails(taskAndEnv []string, stdout io.Writer) error {
	rails := k.remote.Rails
	if rails == "" {
		rails = "bin/rails"
	}
	return k.exec(railsCommandString(rails, taskAndEnv), false, nil, stdout)
}

func (k *kamalStrategy) download(remotePath, localPath string) error {
	out, err := os.Create(localPath)
	if err != nil {
		return err
	}
	defer out.Close()
	return k.exec("cat "+shellQuote(remotePath), false, nil, out)
}

func (k *kamalStrategy) uploadDir(localDir, remotePath string) error {
	pr, pw := io.Pipe()
	go func() {
		pw.CloseWithError(tarDir(localDir, pw))
	}()
	remoteCmd := fmt.Sprintf("sh -c %s", shellQuote(fmt.Sprintf(
		"rm -rf %s && mkdir -p %s && tar xzf - -C %s", shellQuote(remotePath), shellQuote(remotePath), shellQuote(remotePath),
	)))
	return k.exec(remoteCmd, true, pr, os.Stdout)
}

// logs mirrors this repo's own deploy.yml alias (`logs: app logs -f`) —
// unlike other operations it deliberately does not add --primary, since you
// generally want every host's logs, not just one.
func (k *kamalStrategy) logs(follow bool, stdout io.Writer) error {
	args := []string{"app", "logs"}
	if follow {
		args = append(args, "-f")
	}
	if k.remote.KamalConfig != "" {
		args = append(args, "--config-file="+k.remote.KamalConfig)
	}
	if k.remote.KamalDestination != "" {
		args = append(args, "--destination="+k.remote.KamalDestination)
	}
	return runLocal(k.remote.KamalBin, args, nil, stdout)
}

func (k *kamalStrategy) removeFile(path string) {
	_ = k.exec("rm -rf "+shellQuote(path), false, nil, os.Stdout)
}

// exec runs `kamal app exec [flags] <remoteCmd>`. stdin is passed through
// (with -i) only when a caller supplies one, since -i changes how kamal/
// docker handle the exec (interactive keeps stdin open) and isn't needed —
// or safe to enable by default — for plain streamed commands.
func (k *kamalStrategy) exec(remoteCmd string, withStdin bool, stdin io.Reader, stdout io.Writer) error {
	args := []string{"app", "exec", "--reuse", "--primary"}
	if withStdin {
		args = append(args, "--interactive")
	}
	if k.remote.KamalConfig != "" {
		args = append(args, "--config-file="+k.remote.KamalConfig)
	}
	if k.remote.KamalDestination != "" {
		args = append(args, "--destination="+k.remote.KamalDestination)
	}
	args = append(args, remoteCmd)

	var in io.Reader
	if withStdin {
		in = stdin
	}
	return runLocal(k.remote.KamalBin, args, in, stdout)
}
