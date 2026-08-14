package main

import (
	"fmt"
	"path/filepath"
	"strings"
	"time"

	"github.com/tableneeds/Plum/cli/internal/config"
	"github.com/tableneeds/Plum/cli/internal/ui"
)

// cmdPromote flips a preview into the real site, in place: the preview app
// — container, volume, every bit of content built during the preview —
// simply starts answering to the production domain. No rebuild, no data
// migration; `once update --host` re-homes the app and provisions TLS.
//
// plum.yml needs no edit afterwards: once_app has held the real domain
// all along, and after promotion that's exactly the hostname Once knows
// the app by.
func cmdPromote(args []string) error {
	p := parseArgs(args)
	r, dir, err := runner(p.project, p.remote)
	if err != nil {
		return err
	}
	rem := r.Remote
	if rem.Via != config.ViaOnce {
		return fmt.Errorf("plum promote currently supports via: once remotes (this one is via: %s)", viaOrSSH(rem.Via))
	}

	target := rem.Host
	if rem.User != "" {
		target = rem.User + "@" + rem.Host
	}

	previewHost := rem.PreviewHost
	if previewHost == "" {
		ip := serverPublicIP(target)
		if ip == "" {
			return fmt.Errorf("couldn't determine the server's IP to find the preview app — set preview_host in plum.yml")
		}
		previewHost = strings.ToLower(filepath.Base(absOrDot(dir))) + "." + ip + ".sslip.io"
	}

	listCmd := onceBinOrDefault(rem) + " list 2>/dev/null | grep -qF "
	if !sshProbe(target, listCmd+shellQuote(previewHost)) {
		return fmt.Errorf("no preview app at %s — deploy one first with `plum deploy --preview`", previewHost)
	}
	if sshProbe(target, listCmd+shellQuote(rem.OnceApp)) {
		return fmt.Errorf("%s is already deployed as its own app — promotion would collide; remove one first (`once remove` on the server)", rem.OnceApp)
	}

	if !dnsPointsAtServer(rem.OnceApp, target) {
		ui.Warn("%s doesn't resolve to this server yet — promotion re-homes the app under that domain, so DNS should point here first (TLS provisioning needs it).", rem.OnceApp)
		fmt.Println(ui.Dim("Proxied DNS (Cloudflare) legitimately resolves elsewhere and is fine to continue with."))
		proceed, cerr := ui.Confirm("Promote anyway?", false)
		if cerr != nil {
			return cerr
		}
		if !proceed {
			return fmt.Errorf("promotion stopped — point DNS at the server and re-run")
		}
	}

	ui.Step("Promoting %s → %s", previewHost, ui.Bold(rem.OnceApp))
	if err := sshRun(rem, target, onceBinOrDefault(rem)+" update "+shellQuote(previewHost)+" --host "+shellQuote(rem.OnceApp), nil); err != nil {
		return fmt.Errorf("once update failed: %w", err)
	}

	if !ui.Check("Serving on the production domain", func() bool {
		return waitHealthy(target, rem.OnceApp, 90*time.Second)
	}) {
		return fmt.Errorf("the app isn't answering on %s yet — check `plum logs %s`", rem.OnceApp, r.Name)
	}

	ui.Blank()
	ui.Success("Promoted. %s %s", ui.Bold("https://"+rem.OnceApp), ui.Dim("is the site your preview built — same app, same content. The preview URL no longer serves."))
	return nil
}
