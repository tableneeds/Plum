package tutorial

import (
	"context"
	"errors"
	"fmt"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/ssh"
	"github.com/charmbracelet/wish"
	"github.com/charmbracelet/wish/activeterm"
	bm "github.com/charmbracelet/wish/bubbletea"
	"github.com/charmbracelet/wish/logging"
)

// Serve hosts the tour as an SSH app (charm's wish): anyone who can reach
// the port gets the full animated tutorial with zero install —
// `ssh -p 2222 your-server` and they're in. Sessions run only this
// bubbletea program; there is no shell, no exec, no file access, and any
// (or no) public key is accepted since the content is public anyway.
func Serve(addr, hostKeyPath string) error {
	chapters, err := Chapters()
	if err != nil {
		return err
	}

	srv, err := wish.NewServer(
		wish.WithAddress(addr),
		wish.WithHostKeyPath(hostKeyPath),
		wish.WithMiddleware(
			bm.Middleware(func(s ssh.Session) (tea.Model, []tea.ProgramOption) {
				// No way to query a remote terminal's background from
				// here; dark is the safe guess for people ssh-ing into
				// tutorials.
				return newModel(chapters, "dark", newProgress("")), []tea.ProgramOption{tea.WithAltScreen()}
			}),
			activeterm.Middleware(), // reject sessions with no pty (scp, port scans)
			logging.Middleware(),
		),
	)
	if err != nil {
		return err
	}

	done := make(chan os.Signal, 1)
	signal.Notify(done, os.Interrupt, syscall.SIGTERM)
	fmt.Printf("Serving the Plum tutorial on %s — try: ssh -p %s <this-host>\n", addr, portOf(addr))
	fmt.Println("Ctrl-C to stop.")

	go func() {
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, ssh.ErrServerClosed) {
			fmt.Fprintln(os.Stderr, "tutorial server: "+err.Error())
			done <- syscall.SIGTERM
		}
	}()
	<-done

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	return srv.Shutdown(ctx)
}

// DefaultHostKeyPath keeps the server's identity stable across restarts so
// returning visitors don't get scary host-key-changed warnings.
func DefaultHostKeyPath() string {
	base := os.Getenv("XDG_CONFIG_HOME")
	if base == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			return ".plum-tutorial-hostkey"
		}
		base = filepath.Join(home, ".config")
	}
	return filepath.Join(base, "plum", "tutorial_host_ed25519")
}

func portOf(addr string) string {
	for i := len(addr) - 1; i >= 0; i-- {
		if addr[i] == ':' {
			return addr[i+1:]
		}
	}
	return addr
}
