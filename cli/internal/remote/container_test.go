package remote

import (
	"archive/tar"
	"bytes"
	"compress/gzip"
	"io"
	"os"
	"path/filepath"
	"testing"
)

func TestTarDirRoundTrips(t *testing.T) {
	dir := t.TempDir()
	if err := os.MkdirAll(filepath.Join(dir, "nested"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "a.yml"), []byte("a: 1\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "nested", "b.yml"), []byte("b: 2\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	var buf bytes.Buffer
	if err := tarDir(dir, &buf); err != nil {
		t.Fatal(err)
	}

	gz, err := gzip.NewReader(&buf)
	if err != nil {
		t.Fatal(err)
	}
	tr := tar.NewReader(gz)
	found := map[string]string{}
	for {
		header, err := tr.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			t.Fatal(err)
		}
		if header.Typeflag == tar.TypeReg {
			content, err := io.ReadAll(tr)
			if err != nil {
				t.Fatal(err)
			}
			found[header.Name] = string(content)
		}
	}

	if found["a.yml"] != "a: 1\n" {
		t.Fatalf("missing or wrong a.yml: %q", found["a.yml"])
	}
	if found["nested/b.yml"] != "b: 2\n" {
		t.Fatalf("missing or wrong nested/b.yml: %q", found["nested/b.yml"])
	}
}

func TestRunLocalMissingBinaryExplains(t *testing.T) {
	err := runLocal("plum-cli-definitely-not-a-real-binary", nil, nil, io.Discard)
	if err == nil {
		t.Fatal("expected an error for a missing binary")
	}
	if !bytes.Contains([]byte(err.Error()), []byte("not found on PATH")) {
		t.Fatalf("expected a helpful not-found message, got: %v", err)
	}
}
