package remote

import (
	"archive/tar"
	"compress/gzip"
	"fmt"
	"io"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
)

// runLocal runs a local binary (kamal, once, ...) with the given args,
// streaming stdout to the given writer and stdin from the given reader.
// Used by the kamal/once strategies, which shell out locally and let that
// tool own the actual connection to the server.
func runLocal(bin string, args []string, stdin io.Reader, stdout io.Writer) error {
	cmd := exec.Command(bin, args...)
	cmd.Stdin = stdin
	cmd.Stdout = stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		if _, ok := err.(*exec.Error); ok {
			return fmt.Errorf("%s: not found on PATH — install it or set the *_bin option in plum.yml (%w)", bin, err)
		}
		return err
	}
	return nil
}

// tarDir streams a gzipped tar of dir's contents (not the dir itself) into w
// — used to upload plum/ config directories through an exec-based transport
// that has no native file-copy primitive.
func tarDir(dir string, w io.Writer) error {
	gz := gzip.NewWriter(w)
	tw := tar.NewWriter(gz)

	err := filepath.WalkDir(dir, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		rel, err := filepath.Rel(dir, path)
		if err != nil {
			return err
		}
		if rel == "." {
			return nil
		}
		info, err := d.Info()
		if err != nil {
			return err
		}
		header, err := tar.FileInfoHeader(info, "")
		if err != nil {
			return err
		}
		header.Name = filepath.ToSlash(rel)
		if err := tw.WriteHeader(header); err != nil {
			return err
		}
		if d.IsDir() {
			return nil
		}
		file, err := os.Open(path)
		if err != nil {
			return err
		}
		defer file.Close()
		_, err = io.Copy(tw, file)
		return err
	})
	if err != nil {
		return err
	}
	if err := tw.Close(); err != nil {
		return err
	}
	return gz.Close()
}
