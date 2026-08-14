package main

import (
	"compress/gzip"
	"fmt"
	"io"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/tableneeds/Plum/cli/internal/config"
	"github.com/tableneeds/Plum/cli/internal/ui"
)

// cmdDeploy ships the site with no registry, no CI, and no accounts:
// build the image locally, stream it over the SSH connection you already
// have (docker save | docker load), and hand it to Once on the server.
// The entire dependency list is the server plus local Docker — deploys
// are explicit, and auto-update is switched off for these apps because
// there's no registry for the server to poll.
func cmdDeploy(args []string) error {
	p := parseArgs(args)
	r, dir, err := runner(p.project, p.remote)
	if err != nil {
		return err
	}
	return runDeploy(r.Remote, r.Name, dir)
}

// runDeploy is the deploy machinery, callable from cmdDeploy or chained
// from the end of a connect that found the app not deployed yet.
func runDeploy(rem config.Remote, remoteName, dir string) error {
	if rem.Via != config.ViaOnce {
		return fmt.Errorf("plum deploy currently supports via: once remotes (this one is via: %s)", viaOrSSH(rem.Via))
	}
	if _, err := os.Stat(filepath.Join(dir, "Dockerfile")); err != nil {
		return fmt.Errorf("no Dockerfile in %s — plum deploy builds the image your app's Dockerfile describes", dir)
	}
	if _, err := exec.LookPath("docker"); err != nil {
		return fmt.Errorf("plum deploy needs Docker locally — install Docker Engine or Docker Desktop and re-run")
	}

	target := rem.Host
	if rem.User != "" {
		target = rem.User + "@" + rem.Host
	}

	// Once's first-deploy verification curls https://<once_app> from the
	// server — if DNS doesn't route there yet, the deploy builds, ships,
	// boots healthy... and then gets torn down at the finish line. Check
	// up front instead of after 200MB. (Proxied DNS — Cloudflare — resolves
	// elsewhere but still routes correctly, hence a confirm, not a block.)
	firstDeploy := !sshProbe(target, onceBinOrDefault(rem)+" list 2>/dev/null | grep -qF "+shellQuote(rem.OnceApp))
	if firstDeploy && !dnsPointsAtServer(rem.OnceApp, target) {
		ui.Warn("%s doesn't resolve to this server yet — Once verifies https://%s at the end of a first deploy and will roll it back.", rem.OnceApp, rem.OnceApp)
		fmt.Println(ui.Dim("Point the domain's A record at the server first (or use a staging hostname you control). Proxied DNS (Cloudflare) is fine to continue with."))
		proceed, cerr := ui.Confirm("Deploy anyway?", false)
		if cerr != nil {
			return cerr
		}
		if !proceed {
			return fmt.Errorf("deploy stopped — point DNS at the server and re-run")
		}
	}

	appName := filepath.Base(absOrDot(dir))
	image := fmt.Sprintf("%s:plum-%s", strings.ToLower(appName), time.Now().UTC().Format("20060102-150405"))

	// Rails images must match the server's architecture, not the laptop's.
	ui.Step("Building %s %s", ui.Bold(image), ui.Dim("(linux/amd64)"))
	build := exec.Command("docker", "build", "--platform", "linux/amd64", "-t", image, ".")
	build.Dir = dir
	out := ui.StreamWriter(os.Stdout)
	build.Stdout, build.Stderr = out, out
	if err := build.Run(); err != nil {
		return fmt.Errorf("docker build failed: %w", err)
	}

	var shipped int64
	if err := ui.Spin(fmt.Sprintf("Shipping image to %s", remoteName), func() error {
		var shipErr error
		shipped, shipErr = shipImage(rem, target, image)
		return shipErr
	}); err != nil {
		return err
	}
	fmt.Println(ui.Dim(fmt.Sprintf("  %dMB over the wire — no registry accounts involved", shipped/1024/1024)))

	// Once insists on pulling before it deploys — it won't use an image
	// that's merely loaded in the daemon. So the server keeps a loopback-
	// only registry:2 container (~10MB, bound to 127.0.0.1, invisible to
	// the internet) as the handoff point: tag the shipped image into it,
	// push server-side (instant), and give Once a ref it can pull.
	localRef := "127.0.0.1:5000/" + image
	if err := ui.Spin("Staging image for Once", func() error {
		script := "docker inspect plum-registry >/dev/null 2>&1 || docker run -d --name plum-registry --restart unless-stopped -p 127.0.0.1:5000:5000 registry:2 >/dev/null; " +
			"docker tag " + shellQuote(image) + " " + shellQuote(localRef) + " && docker push -q " + shellQuote(localRef) + " >/dev/null"
		return sshRun(rem, target, script, nil)
	}); err != nil {
		return fmt.Errorf("staging the image on the server failed: %w", err)
	}

	if !firstDeploy {
		ui.Step("Rolling %s to the new image", rem.OnceApp)
		if err := sshRun(rem, target, onceBinOrDefault(rem)+" update "+shellQuote(rem.OnceApp)+" --image "+shellQuote(localRef)+" --auto-update=false", nil); err != nil {
			return fmt.Errorf("once update failed: %w", err)
		}
	} else {
		ui.Step("First deploy of %s", rem.OnceApp)
		if err := sshRun(rem, target, onceBinOrDefault(rem)+" deploy "+shellQuote(localRef)+" --host "+shellQuote(rem.OnceApp)+" --auto-update=false", nil); err != nil {
			return fmt.Errorf("once deploy failed: %w", err)
		}
	}

	if !ui.Check("App healthy", func() bool { return waitHealthy(target, rem.OnceApp, 120*time.Second) }) {
		return fmt.Errorf("the app never reported healthy — try `plum logs %s` to see why", remoteName)
	}

	ui.Blank()
	ui.Success("Deployed %s to %s %s", ui.Bold(image), rem.OnceApp, ui.Dim("(plum logs --follow to watch it)"))
	return nil
}

// shipImage streams `docker save` through gzip over ssh into the server's
// docker daemon; returns compressed bytes sent.
func shipImage(rem config.Remote, target, image string) (int64, error) {
	save := exec.Command("docker", "save", image)
	saveOut, err := save.StdoutPipe()
	if err != nil {
		return 0, err
	}
	save.Stderr = os.Stderr

	pr, pw := io.Pipe()
	counter := &countingWriter{}
	go func() {
		gz := gzip.NewWriter(io.MultiWriter(pw, counter))
		_, copyErr := io.Copy(gz, saveOut)
		if closeErr := gz.Close(); copyErr == nil {
			copyErr = closeErr
		}
		pw.CloseWithError(copyErr)
	}()

	if err := save.Start(); err != nil {
		return 0, err
	}
	if err := sshRun(rem, target, "gunzip | docker load", pr); err != nil {
		_ = save.Wait()
		return counter.n, fmt.Errorf("streaming the image to the server failed: %w", err)
	}
	return counter.n, save.Wait()
}

type countingWriter struct{ n int64 }

func (c *countingWriter) Write(p []byte) (int, error) {
	c.n += int64(len(p))
	return len(p), nil
}

// sshRun executes a remote command with optional stdin, quietly (the
// caller narrates; docker load's chatter isn't worth showing).
func sshRun(rem config.Remote, target, command string, stdin io.Reader) error {
	args := append(append([]string{}, rem.SSHArgs...), target, command)
	cmd := exec.Command("ssh", args...)
	cmd.Stdin = stdin
	cmd.Stdout = nil
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

// dnsPointsAtServer reports whether host's A records intersect the
// server's addresses — the "will Once's verification even reach us?"
// preflight. Unresolvable answers false; proxied DNS answers false too,
// which is why callers confirm rather than refuse.
func dnsPointsAtServer(host, target string) bool {
	ips, err := net.LookupHost(host)
	if err != nil || len(ips) == 0 {
		return false
	}
	var serverIPs strings.Builder
	cmd := exec.Command("ssh", target, "hostname -I")
	cmd.Stdout = &serverIPs
	if cmd.Run() != nil {
		return true // can't tell; don't nag on a probe failure
	}
	serverSet := map[string]bool{}
	for _, ip := range strings.Fields(serverIPs.String()) {
		serverSet[ip] = true
	}
	for _, ip := range ips {
		if serverSet[ip] {
			return true
		}
	}
	return false
}

// waitHealthy polls docker's health status for the app's container (found
// by the `once` label, same trick as plum logs) until it reports healthy.
func waitHealthy(target, onceApp string, patience time.Duration) bool {
	script := `c="$(docker ps --format '{{.Names}} {{.Label "once"}}' | grep -F ` + shellQuote(onceApp) + ` | head -n 1 | cut -d' ' -f1)"; ` +
		`[ -n "$c" ] && docker inspect --format '{{.State.Health.Status}}' "$c" 2>/dev/null | grep -q healthy`
	deadline := time.Now().Add(patience)
	for time.Now().Before(deadline) {
		if sshProbe(target, script) {
			return true
		}
		time.Sleep(4 * time.Second)
	}
	return false
}
