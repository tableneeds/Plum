// Package detect guesses how a project is deployed by looking at files in
// its repo — used by `plum connect` to ask the right setup questions
// instead of always assuming plain SSH to a filesystem path.
package detect

import (
	"os"
	"path/filepath"

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
func Deployment(dir string) Result {
	if exists(filepath.Join(dir, "config", "deploy.yml")) {
		return Result{Via: config.ViaKamal, Evidence: "config/deploy.yml"}
	}
	if exists(filepath.Join(dir, "Dockerfile")) {
		return Result{Via: config.ViaOnce, Evidence: "Dockerfile (no config/deploy.yml)"}
	}
	return Result{}
}

func exists(path string) bool {
	info, err := os.Stat(path)
	return err == nil && !info.IsDir()
}
