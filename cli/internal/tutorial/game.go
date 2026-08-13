package tutorial

import (
	"fmt"
	"math"
	"math/rand"
	"strings"

	"github.com/charmbracelet/harmonica"
	"github.com/charmbracelet/lipgloss"
)

// Plum Drop: the title screen's arcade cabinet. Plums fall on harmonica
// projectile physics; you slide a basket to catch them. Streaks multiply,
// five misses end the run, and the high score outlives the session.

const (
	gameMisses     = 5
	basketHalf     = 2 // basket is 5 cells wide: \___/
	gameSpawnStart = 40
	gameSpawnFloor = 14 // frames between plums at maximum chaos
)

type fallingPlum struct {
	proj *harmonica.Projectile
	pos  harmonica.Point
}

type plumDrop struct {
	width, height int
	basketX       float64
	plums         []fallingPlum
	score         int
	combo         int
	misses        int
	sinceSpawn    int
	caught        int
	popup         string // "+3" floater after a catch
	popupX        int
	popupTTL      int
	over          bool
	newBest       bool
}

func newPlumDrop(width, height int) *plumDrop {
	if width < 30 {
		width = 60
	}
	if height < 12 {
		height = 20
	}
	return &plumDrop{
		width:   width,
		height:  height,
		basketX: float64(width) / 2,
	}
}

// stage rows: header takes 2, basket sits on the last row.
func (g *plumDrop) stageRows() int { return g.height - 4 }

func (g *plumDrop) spawnEvery() int {
	every := gameSpawnStart - g.caught
	if every < gameSpawnFloor {
		every = gameSpawnFloor
	}
	return every
}

func (g *plumDrop) tick() {
	if g.over {
		return
	}
	g.sinceSpawn++
	if g.sinceSpawn >= g.spawnEvery() {
		g.sinceSpawn = 0
		fps := harmonica.FPS(33)
		x := 2 + rand.Float64()*float64(g.width-4)
		g.plums = append(g.plums, fallingPlum{
			proj: harmonica.NewProjectile(fps,
				harmonica.Point{X: x, Y: 0},
				harmonica.Vector{X: rand.Float64()*4 - 2, Y: 2 + rand.Float64()*3},
				harmonica.Vector{Y: 5 + rand.Float64()*4},
			),
		})
	}

	floor := float64(g.stageRows() - 1)
	alive := g.plums[:0]
	for _, p := range g.plums {
		p.pos = p.proj.Update()
		if p.pos.Y >= floor {
			if math.Abs(p.pos.X-g.basketX) <= basketHalf+0.5 {
				g.combo++
				points := g.combo
				g.score += points
				g.caught++
				g.popup = fmt.Sprintf("+%d", points)
				g.popupX = int(math.Round(p.pos.X))
				g.popupTTL = 16
			} else {
				g.misses++
				g.combo = 0
				if g.misses >= gameMisses {
					g.over = true
				}
			}
			continue
		}
		alive = append(alive, p)
	}
	g.plums = alive
	if g.popupTTL > 0 {
		g.popupTTL--
	}
}

func (g *plumDrop) move(dx float64) {
	g.basketX += dx
	if g.basketX < basketHalf {
		g.basketX = basketHalf
	}
	if g.basketX > float64(g.width-1-basketHalf) {
		g.basketX = float64(g.width - 1 - basketHalf)
	}
}

var (
	gamePlum   = lipgloss.NewStyle().Foreground(plumColor).Bold(true).Render("●")
	gameBasket = lipgloss.NewStyle().Foreground(lipgloss.AdaptiveColor{Light: "#93540A", Dark: "#F7C948"}).Bold(true)
	gamePopup  = lipgloss.NewStyle().Foreground(lipgloss.AdaptiveColor{Light: "#087443", Dark: "#3FCF8E"}).Bold(true)
	gameOver   = lipgloss.NewStyle().Bold(true).Foreground(plumColor)
)

func (g *plumDrop) view(highScore int) string {
	var b strings.Builder

	lives := strings.Repeat("●", gameMisses-g.misses) + strings.Repeat("○", g.misses)
	head := fmt.Sprintf(" score %d", g.score)
	if g.combo > 1 {
		head += dimText.Render("  ·  ") + gamePopup.Render(fmt.Sprintf("combo ×%d", g.combo))
	}
	head += dimText.Render(fmt.Sprintf("  ·  best %d  ·  ", highScore)) + lives
	b.WriteString(head + "\n\n")

	if g.over {
		b.WriteString("\n\n" + indent(gameOver.Render("GAME OVER"), g.width/2-5) + "\n\n")
		line := fmt.Sprintf("you caught %d plums for %d points", g.caught, g.score)
		if g.newBest {
			line += " — a new best!"
		}
		b.WriteString(indent(line, max(0, (g.width-len(line))/2)) + "\n\n")
		hint := "any key for the title screen"
		b.WriteString(indent(dimText.Render(hint), max(0, (g.width-len(hint))/2)))
		return b.String()
	}

	rows := g.stageRows()
	grid := make([][]string, rows)
	for r := range grid {
		grid[r] = make([]string, g.width)
		for c := range grid[r] {
			grid[r][c] = " "
		}
	}
	for _, p := range g.plums {
		x, y := int(math.Round(p.pos.X)), int(math.Round(p.pos.Y))
		if y >= 0 && y < rows && x >= 0 && x < g.width {
			grid[y][x] = gamePlum
		}
	}
	if g.popupTTL > 0 && g.popupX >= 0 && g.popupX < g.width-3 {
		row := rows - 3
		if row >= 0 {
			for i, ch := range g.popup {
				if g.popupX+i < g.width {
					grid[row][g.popupX+i] = gamePopup.Render(string(ch))
				}
			}
		}
	}
	// Basket on the floor row.
	bx := int(math.Round(g.basketX))
	basket := `\___/`
	for i, ch := range basket {
		col := bx - basketHalf + i
		if col >= 0 && col < g.width {
			grid[rows-1][col] = gameBasket.Render(string(ch))
		}
	}

	for r := range grid {
		b.WriteString(strings.TrimRight(strings.Join(grid[r], ""), " ") + "\n")
	}
	b.WriteString(dimText.Render(" ←/→ move · q back to title"))
	return b.String()
}
