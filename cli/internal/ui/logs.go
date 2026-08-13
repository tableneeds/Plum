package ui

import (
	"encoding/json"
	"fmt"
	"io"
	"sort"
	"strings"
	"time"
)

// LogWriter prettifies streamed app logs on a terminal, heroku-style.
// Structured JSON lines (slog/thruster shape: time/level/msg/...) become
//
//	22:41:27 INFO  GET /up → 200 (2ms)
//	22:43:10 ERROR Some message key=value
//
// with levels and status codes color-coded. Anything that isn't a JSON log
// line — plain Rails log text, partial output — passes through untouched.
// Unstyled (piped, CI, NO_COLOR) it returns w as-is: scripts see the raw
// bytes the server sent.
func LogWriter(w io.Writer) io.Writer {
	if !Styled() {
		return w
	}
	return &logLineWriter{w: w}
}

type logLineWriter struct {
	w   io.Writer
	buf strings.Builder // partial line carried across writes
}

func (l *logLineWriter) Write(p []byte) (int, error) {
	l.buf.WriteString(string(p))
	text := l.buf.String()
	var out strings.Builder
	for {
		nl := strings.IndexByte(text, '\n')
		if nl < 0 {
			break
		}
		out.WriteString(renderLogLine(text[:nl]) + "\n")
		text = text[nl+1:]
	}
	l.buf.Reset()
	l.buf.WriteString(text)
	if _, err := io.WriteString(l.w, out.String()); err != nil {
		return 0, err
	}
	return len(p), nil
}

var (
	levelStyles = map[string]func(...string) string{
		"DEBUG": dimStyle.Render,
		"INFO":  plumStyle.Render,
		"WARN":  warnGlyph.Render,
		"ERROR": failGlyph.Render,
	}
	// request-line fields rendered specially or too noisy to keep
	requestFields = map[string]bool{
		"method": true, "path": true, "status": true, "dur": true,
		"req_content_length": true, "req_content_type": true,
		"resp_content_length": true, "resp_content_type": true,
		"remote_addr": true, "user_agent": true, "query": true,
		"proto": true, "cache": true,
	}
)

// renderLogLine compacts one structured log line for human eyes; anything
// unparseable is returned verbatim.
func renderLogLine(line string) string {
	trimmed := strings.TrimSpace(line)
	if !strings.HasPrefix(trimmed, "{") {
		return line
	}
	var entry map[string]any
	if err := json.Unmarshal([]byte(trimmed), &entry); err != nil {
		return line
	}
	msg, hasMsg := entry["msg"].(string)
	timeStr, hasTime := entry["time"].(string)
	if !hasMsg || !hasTime {
		return line
	}

	stamp := timeStr
	if t, err := time.Parse(time.RFC3339Nano, timeStr); err == nil {
		stamp = t.Local().Format("15:04:05")
	}

	level, _ := entry["level"].(string)
	level = strings.ToUpper(level)
	styleLevel := levelStyles[level]
	if styleLevel == nil {
		styleLevel = boldStyle.Render
	}

	head := dimStyle.Render(stamp) + " " + styleLevel(fmt.Sprintf("%-5s", level))

	// Request lines get the router treatment: method, path, status, time.
	if method, ok := entry["method"].(string); ok && entry["path"] != nil {
		status, _ := entry["status"].(float64)
		dur, _ := entry["dur"].(float64)
		return fmt.Sprintf("%s %s %v %s %s",
			head,
			boldStyle.Render(method),
			entry["path"],
			styleStatus(int(status)),
			dimStyle.Render(fmt.Sprintf("(%dms)", int(dur))),
		)
	}

	rest := head + " " + msg
	keys := make([]string, 0, len(entry))
	for k := range entry {
		if k == "time" || k == "level" || k == "msg" || requestFields[k] {
			continue
		}
		keys = append(keys, k)
	}
	sort.Strings(keys)
	for _, k := range keys {
		rest += " " + dimStyle.Render(fmt.Sprintf("%s=%v", k, entry[k]))
	}
	return rest
}

func styleStatus(status int) string {
	s := fmt.Sprintf("%d", status)
	switch {
	case status >= 500:
		return failGlyph.Render(s)
	case status >= 400:
		return warnGlyph.Render(s)
	case status >= 300:
		return dimStyle.Render(s)
	default:
		return okGlyph.Render(s)
	}
}
