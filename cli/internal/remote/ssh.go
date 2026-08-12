package remote

import (
	"fmt"
	"io"
	"os"
	"os/exec"
	"strings"

	"github.com/tableneeds/Plum/cli/internal/config"
)

// sshStrategy runs commands over the system ssh/scp, or directly on this
// machine when the remote is "local".
type sshStrategy struct {
	remote config.Remote
}

func (s *sshStrategy) runRails(taskAndEnv []string, stdout io.Writer) error {
	cmd := fmt.Sprintf("cd %s && %s", shellQuote(s.appPath()), railsCommandString(s.remote.Rails, taskAndEnv))
	return s.run(cmd, stdout)
}

func (s *sshStrategy) download(remotePath, localPath string) error {
	if s.remote.IsLocal() {
		return command("cp", s.absolute(remotePath), localPath).Run()
	}
	args := append(append([]string{}, s.remote.SSHArgs...), s.sshTarget()+":"+remotePath, localPath)
	return command("scp", args...).Run()
}

func (s *sshStrategy) uploadDir(localDir, remotePath string) error {
	if s.remote.IsLocal() {
		if err := command("rm", "-rf", s.absolute(remotePath)).Run(); err != nil {
			return err
		}
		return command("cp", "-r", localDir, s.absolute(remotePath)).Run()
	}
	args := append(append([]string{}, s.remote.SSHArgs...), "-r", localDir, s.sshTarget()+":"+remotePath)
	return command("scp", args...).Run()
}

// logs tails the Rails production log directly — there's no process
// supervisor assumption for plain ssh remotes, so this is the one universal
// thing every Rails deploy has: a log file under the app's log/ directory.
func (s *sshStrategy) logs(follow bool, stdout io.Writer) error {
	logPath := s.absolute("log/production.log")
	flag := ""
	if follow {
		flag = "-f "
	}
	return s.run("tail -n 200 "+flag+shellQuote(logPath), stdout)
}

func (s *sshStrategy) removeFile(path string) {
	if s.remote.IsLocal() {
		os.RemoveAll(s.absolute(path))
		return
	}
	_ = s.run("rm -rf "+shellQuote(path), os.Stdout)
}

func (s *sshStrategy) run(shellCommand string, stdout io.Writer) error {
	return sshExec(s.remote, shellCommand, os.Stdin, stdout)
}

// sshExec runs shellCommand on the remote over ssh (or locally, via bash -c,
// when the remote is "local") — the shared low-level transport underneath
// both sshStrategy and onceStrategy, since once's own CLI runs *on* the
// server: reaching it means ssh-ing in and running `once exec ...` there,
// not shelling out to a local once binary. See once.go.
func sshExec(remote config.Remote, shellCommand string, stdin io.Reader, stdout io.Writer) error {
	var cmd *exec.Cmd
	if remote.IsLocal() {
		cmd = exec.Command("bash", "-c", shellCommand)
	} else {
		target := remote.Host
		if remote.User != "" {
			target = remote.User + "@" + remote.Host
		}
		args := append(append([]string{}, remote.SSHArgs...), target, shellCommand)
		cmd = exec.Command("ssh", args...)
	}
	cmd.Stdout = stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = stdin
	return cmd.Run()
}

func (s *sshStrategy) sshTarget() string {
	if s.remote.User != "" {
		return s.remote.User + "@" + s.remote.Host
	}
	return s.remote.Host
}

func (s *sshStrategy) appPath() string {
	if s.remote.Path != "" {
		return s.remote.Path
	}
	return "."
}

// absolute resolves a path for local-remote file operations; temp paths are
// already absolute, app-relative ones are not.
func (s *sshStrategy) absolute(path string) string {
	if strings.HasPrefix(path, "/") {
		return path
	}
	return s.appPath() + "/" + path
}

func command(name string, args ...string) *exec.Cmd {
	cmd := exec.Command(name, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd
}
