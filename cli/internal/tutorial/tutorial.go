// Package tutorial is `plum tutorial`: a built-in, full-screen guided tour
// of Plum and the CLI. Chapters are markdown embedded in the binary,
// rendered with glamour inside a bubbletea pager — nothing to install,
// nothing to browse to.
package tutorial

import (
	"embed"
	"fmt"
	"sort"
	"strings"
)

//go:embed chapters/*.md
var chaptersFS embed.FS

// Chapter is one screenful-ish page of the tour.
type Chapter struct {
	Title string // first heading, shown in the header
	Body  string // full markdown, heading included
}

// Chapters returns the tour in reading order (chapter files are numbered).
func Chapters() ([]Chapter, error) {
	entries, err := chaptersFS.ReadDir("chapters")
	if err != nil {
		return nil, err
	}
	names := make([]string, 0, len(entries))
	for _, e := range entries {
		if strings.HasSuffix(e.Name(), ".md") {
			names = append(names, e.Name())
		}
	}
	sort.Strings(names)

	chapters := make([]Chapter, 0, len(names))
	for _, name := range names {
		raw, err := chaptersFS.ReadFile("chapters/" + name)
		if err != nil {
			return nil, err
		}
		body := string(raw)
		chapters = append(chapters, Chapter{Title: firstHeading(body), Body: body})
	}
	if len(chapters) == 0 {
		return nil, fmt.Errorf("no tutorial chapters embedded")
	}
	return chapters, nil
}

func firstHeading(markdown string) string {
	for _, line := range strings.Split(markdown, "\n") {
		if strings.HasPrefix(line, "# ") {
			return strings.TrimSpace(strings.TrimPrefix(line, "# "))
		}
	}
	return "Untitled"
}
