// Package detect guesses how a project is deployed by looking at files in
// its repo — used by `plum connect` to ask the right setup questions
// instead of always assuming plain SSH to a filesystem path.
package detect

import (
	"os"
	"path/filepath"
	"strings"

	"github.com/tableneeds/Plum/cli/internal/config"
)

type Result struct {
	Via      config.Via // config.ViaKamal, config.ViaOnce, or "" if unclear
	Evidence string     // human-readable reason, for the confirmation prompt
}

// Deployment inspects dir for the files that distinguish a Kamal deployment
// (config/deploy.yml — the definitive signal, since only Kamal reads it)
// from a merely Docker-based one that's more likely Once (a Dockerfile with
// no deploy.yml). Both are guesses to confirm with the user, not silent
// decisions — a bare Dockerfile could mean plain `docker run` with no
// orchestrator at all.
//
// A deploy.yml still carrying `kamal init` placeholder values counts as
// absent: `rails new` ships one by default, so an untouched scaffold says
// nothing about how the app actually deploys. (This mattered in practice —
// a repo deployed with Once but carrying the default scaffold got steered
// to a broken via: kamal remote.)
func Deployment(dir string) Result {
	deploy := filepath.Join(dir, "config", "deploy.yml")
	deployExists := exists(deploy)
	if deployExists && !looksLikeKamalScaffold(deploy) {
		return Result{Via: config.ViaKamal, Evidence: "config/deploy.yml"}
	}
	if exists(filepath.Join(dir, "Dockerfile")) {
		if deployExists {
			return Result{Via: config.ViaOnce, Evidence: "Dockerfile (config/deploy.yml looks like an unedited kamal scaffold)"}
		}
		return Result{Via: config.ViaOnce, Evidence: "Dockerfile (no config/deploy.yml)"}
	}
	return Result{}
}

// looksLikeKamalScaffold reports whether deploy.yml still contains the
// placeholder values `kamal init` / `rails new` generate — a server of
// 192.168.0.1 or a your-user/... image means nobody has pointed it at a
// real deployment yet.
func looksLikeKamalScaffold(path string) bool {
	raw, err := os.ReadFile(path)
	if err != nil {
		return false
	}
	content := string(raw)
	return strings.Contains(content, "192.168.0.1") || strings.Contains(content, "your-user/")
}

func exists(path string) bool {
	info, err := os.Stat(path)
	return err == nil && !info.IsDir()
}
