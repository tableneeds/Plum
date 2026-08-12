package config

import (
	"os"
	"path/filepath"
	"testing"
)

func loadFrom(t *testing.T, yaml string) (*Config, error) {
	t.Helper()
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, FileName), []byte(yaml), 0o644); err != nil {
		t.Fatal(err)
	}
	previous, _ := os.Getwd()
	t.Cleanup(func() { os.Chdir(previous) })
	os.Chdir(dir)
	return Load()
}

func TestResolveDefaultAndFallbacks(t *testing.T) {
	cfg, err := loadFrom(t, `
default: production
remotes:
  production:
    host: prod.example.com
    user: deploy
    path: /var/www/site
  staging:
    host: staging.example.com
`)
	if err != nil {
		t.Fatal(err)
	}

	name, remote, err := cfg.Resolve("")
	if err != nil || name != "production" || remote.Host != "prod.example.com" {
		t.Fatalf("default resolve failed: %v %v %v", name, remote, err)
	}
	if remote.Rails != "bin/rails" {
		t.Fatalf("expected rails default, got %q", remote.Rails)
	}

	if _, _, err := cfg.Resolve("nope"); err == nil {
		t.Fatal("expected error for unknown remote")
	}
}

func TestSingleRemoteNeedsNoDefault(t *testing.T) {
	cfg, err := loadFrom(t, `
remotes:
  only:
    host: local
`)
	if err != nil {
		t.Fatal(err)
	}
	name, remote, err := cfg.Resolve("")
	if err != nil || name != "only" {
		t.Fatalf("single-remote fallback failed: %v %v", name, err)
	}
	if !remote.IsLocal() {
		t.Fatal("host: local should be a local remote")
	}
}

func TestViaDefaultsToSSH(t *testing.T) {
	cfg, err := loadFrom(t, `
remotes:
  production:
    host: prod.example.com
`)
	if err != nil {
		t.Fatal(err)
	}
	_, remote, err := cfg.Resolve("production")
	if err != nil {
		t.Fatal(err)
	}
	if remote.Via != ViaSSH {
		t.Fatalf("expected default via ssh, got %q", remote.Via)
	}
}

func TestViaKamalNeedsNoHostAndDefaultsBinary(t *testing.T) {
	cfg, err := loadFrom(t, `
remotes:
  production:
    via: kamal
`)
	if err != nil {
		t.Fatal(err)
	}
	_, remote, err := cfg.Resolve("production")
	if err != nil {
		t.Fatal(err)
	}
	if remote.KamalBin == "" {
		t.Fatal("expected a default kamal_bin")
	}
	if remote.IsLocal() {
		t.Fatal("via: kamal should never be treated as the ssh local case")
	}
}

func TestViaOnceRequiresHostAndOnceApp(t *testing.T) {
	cfg, err := loadFrom(t, `
remotes:
  production:
    via: once
`)
	if err != nil {
		t.Fatal(err)
	}
	if _, _, err := cfg.Resolve("production"); err == nil {
		t.Fatal("expected via: once without host to error")
	}

	cfgNoApp, err := loadFrom(t, `
remotes:
  production:
    via: once
    host: plum-production
`)
	if err != nil {
		t.Fatal(err)
	}
	if _, _, err := cfgNoApp.Resolve("production"); err == nil {
		t.Fatal("expected via: once without once_app to error")
	}

	cfg2, err := loadFrom(t, `
remotes:
  production:
    via: once
    host: plum-production
    once_app: myapp.example.com
`)
	if err != nil {
		t.Fatal(err)
	}
	_, remote, err := cfg2.Resolve("production")
	if err != nil {
		t.Fatal(err)
	}
	if remote.OnceBin != "once" {
		t.Fatalf("expected default once_bin, got %q", remote.OnceBin)
	}
	if remote.Host == remote.OnceApp {
		t.Fatal("test fixture should use distinct host and once_app to guard against them being conflated again")
	}
}

func TestUnknownViaErrors(t *testing.T) {
	cfg, err := loadFrom(t, `
remotes:
  production:
    via: heroku
    host: x
`)
	if err != nil {
		t.Fatal(err)
	}
	if _, _, err := cfg.Resolve("production"); err == nil {
		t.Fatal("expected an unknown via to error")
	}
}

func TestLoadOrEmptyReturnsFreshConfigWhenMissing(t *testing.T) {
	dir := t.TempDir()
	cfg, err := LoadOrEmpty(dir)
	if err != nil {
		t.Fatal(err)
	}
	if len(cfg.Remotes) != 0 {
		t.Fatalf("expected an empty config, got %v", cfg.Remotes)
	}
}

func TestSaveAndReloadRoundTrips(t *testing.T) {
	dir := t.TempDir()
	cfg, err := LoadOrEmpty(dir)
	if err != nil {
		t.Fatal(err)
	}
	cfg.Remotes["production"] = Remote{Host: "plum-production", Path: "/var/www/site"}
	cfg.Default = "production"
	if err := cfg.Save(dir); err != nil {
		t.Fatal(err)
	}

	reloaded, err := LoadFrom(dir)
	if err != nil {
		t.Fatal(err)
	}
	name, remote, err := reloaded.Resolve("")
	if err != nil || name != "production" || remote.Host != "plum-production" {
		t.Fatalf("got (%q, %v, %v)", name, remote, err)
	}
}

func TestSavePreservesOtherRemotesWhenAddingOne(t *testing.T) {
	dir := t.TempDir()
	cfg, err := LoadOrEmpty(dir)
	if err != nil {
		t.Fatal(err)
	}
	cfg.Remotes["production"] = Remote{Host: "prod.example.com"}
	cfg.Default = "production"
	if err := cfg.Save(dir); err != nil {
		t.Fatal(err)
	}

	reloaded, err := LoadFrom(dir)
	if err != nil {
		t.Fatal(err)
	}
	reloaded.Remotes["staging"] = Remote{Host: "staging.example.com"}
	if err := reloaded.Save(dir); err != nil {
		t.Fatal(err)
	}

	final, err := LoadFrom(dir)
	if err != nil {
		t.Fatal(err)
	}
	if _, _, err := final.Resolve("production"); err != nil {
		t.Fatalf("expected production to survive: %v", err)
	}
	if _, _, err := final.Resolve("staging"); err != nil {
		t.Fatalf("expected staging to be added: %v", err)
	}
}

func TestMissingFileExplains(t *testing.T) {
	previous, _ := os.Getwd()
	t.Cleanup(func() { os.Chdir(previous) })
	os.Chdir(t.TempDir())
	if _, err := Load(); err == nil {
		t.Fatal("expected an error without plum.yml")
	}
}
