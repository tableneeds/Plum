package ui

import (
	"fmt"
	"time"

	"github.com/charmbracelet/huh/spinner"
)

// Spin runs fn behind an animated spinner and settles into a ✓/✗ result
// line with the elapsed time. Only wrap *silent* work in it (downloads,
// probes) — anything that writes to stdout mid-flight would fight the
// animation; stream that under a Step instead.
//
// Unstyled it prints "label... done" / "label... failed" around the work,
// keeping CI logs sequential and boring.
func Spin(label string, fn func() error) error {
	if !Styled() {
		fmt.Printf("%s... ", label)
		if err := fn(); err != nil {
			fmt.Println("failed")
			return err
		}
		fmt.Println("done")
		return nil
	}

	start := time.Now()
	var err error
	if runErr := spinner.New().
		Type(spinner.Dots).
		Title(" " + label).
		Action(func() { err = fn() }).
		Run(); runErr != nil && err == nil {
		err = runErr
	}
	elapsed := time.Since(start).Round(100 * time.Millisecond)
	if err != nil {
		Fail("%s %s", label, Dim(fmt.Sprintf("(%s)", elapsed)))
		return err
	}
	Success("%s %s", label, Dim(fmt.Sprintf("(%s)", elapsed)))
	return nil
}

// Check runs a yes/no probe behind a spinner — unlike Spin, a "no" is an
// answer, not a failure, so it settles into a neutral ▸ line instead of ✗.
// The caller prints what the answer means.
func Check(label string, fn func() bool) bool {
	if !Styled() {
		fmt.Printf("%s... ", label)
		ok := fn()
		if ok {
			fmt.Println("yes")
		} else {
			fmt.Println("no")
		}
		return ok
	}

	var ok bool
	_ = spinner.New().
		Type(spinner.Dots).
		Title(" " + label).
		Action(func() { ok = fn() }).
		Run()
	if ok {
		Success("%s", label)
	} else {
		Warn("%s — no", label)
	}
	return ok
}
