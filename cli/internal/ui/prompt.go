package ui

import (
	"bufio"
	"errors"
	"fmt"
	"os"
	"strings"

	"github.com/charmbracelet/huh"
)

// Aborted reports whether err came from the user cancelling a prompt
// (Ctrl-C / Esc) — callers exit quietly instead of printing an error.
func Aborted(err error) bool {
	return errors.Is(err, huh.ErrUserAborted)
}

// Prompts render as styled huh fields on a real terminal and fall back to
// classic "Prompt [default]: " stdin reads everywhere else (pipes, CI,
// tests), so scripted answers keep working exactly as before.

var stdin = bufio.NewReader(os.Stdin)

// Input asks for a line of text; empty input returns def.
func Input(label, def string) (string, error) {
	if !Interactive() {
		return fallbackAsk(label, def), nil
	}
	var value string
	input := huh.NewInput().Title(label).Value(&value)
	if def != "" {
		input = input.Placeholder(def + " (default)")
	}
	if err := input.Run(); err != nil {
		return "", err
	}
	value = strings.TrimSpace(value)
	if value == "" {
		return def, nil
	}
	return value, nil
}

// Confirm asks a yes/no question.
func Confirm(label string, def bool) (bool, error) {
	if !Interactive() {
		return fallbackConfirm(label, def), nil
	}
	value := def
	if err := huh.NewConfirm().
		Title(label).
		Affirmative("Yes").
		Negative("No").
		Value(&value).
		Run(); err != nil {
		return false, err
	}
	return value, nil
}

// Choice is one option in a Select.
type Choice struct {
	Label string // shown to the user
	Value string // returned when picked
}

// Select asks the user to pick one of the choices; def is the Value
// highlighted first (and the fallback answer's default).
func Select(label string, choices []Choice, def string) (string, error) {
	if !Interactive() {
		return fallbackSelect(label, choices, def), nil
	}
	options := make([]huh.Option[string], 0, len(choices))
	for _, c := range choices {
		options = append(options, huh.NewOption(c.Label, c.Value))
	}
	value := def
	if err := huh.NewSelect[string]().
		Title(label).
		Options(options...).
		Value(&value).
		Run(); err != nil {
		return "", err
	}
	return value, nil
}

func fallbackAsk(label, def string) string {
	if def != "" {
		fmt.Printf("%s [%s]: ", label, def)
	} else {
		fmt.Printf("%s: ", label)
	}
	line, _ := stdin.ReadString('\n')
	line = strings.TrimSpace(line)
	if line == "" {
		return def
	}
	return line
}

func fallbackConfirm(label string, def bool) bool {
	suffix := "[Y/n]"
	if !def {
		suffix = "[y/N]"
	}
	fmt.Printf("%s %s: ", label, suffix)
	line, _ := stdin.ReadString('\n')
	line = strings.ToLower(strings.TrimSpace(line))
	if line == "" {
		return def
	}
	return line == "y" || line == "yes"
}

func fallbackSelect(label string, choices []Choice, def string) string {
	values := make([]string, 0, len(choices))
	for _, c := range choices {
		values = append(values, c.Value)
	}
	answer := fallbackAsk(fmt.Sprintf("%s (%s)", label, strings.Join(values, ", ")), def)
	return matchChoice(answer, choices)
}

func matchChoice(answer string, choices []Choice) string {
	for _, c := range choices {
		if strings.EqualFold(answer, c.Value) {
			return c.Value
		}
	}
	return answer // let the caller validate, same as typed input
}
