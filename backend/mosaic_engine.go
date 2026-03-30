package main

import (
	"math/rand"
	"strconv"
)

type PlayerBoard struct {
	Score        int        `json:"score"`
	Wins         int        `json:"wins"`
	PatternLines [][]string `json:"pattern_lines"`
	Wall         [][]string `json:"wall"`
	FloorLine    []string   `json:"floor_line"`
}

type GameState struct {
	Factories            [][]string              `json:"factories"`
	Center               []string                `json:"center"`
	TurnPlayer           string                  `json:"turn_player"`
	CenterHasFirstPlayer bool                    `json:"center_has_first_player"`
	Boards               map[string]*PlayerBoard `json:"boards"`
	Bag                  []string                `json:"-"`
	Discard              []string                `json:"-"`
	Status               string                  `json:"status"`
	LastScored           map[string]map[string]int `json:"last_scored"`
	ActiveSelection      map[string]interface{}    `json:"active_selection"`
}

func generateInitialState(players []string) *GameState {
    bag := make([]string, 0, 100)
	colors := []string{"blue", "yellow", "red", "black", "purple"}
    for _, c := range colors {
        for i := 0; i < 20; i++ { bag = append(bag, c) }
    }
    rand.Shuffle(len(bag), func(i, j int) { bag[i], bag[j] = bag[j], bag[i] })

	boards := make(map[string]*PlayerBoard)
	for _, pName := range players {
		pattern := make([][]string, 5)
		for i := 0; i < 5; i++ {
			pattern[i] = make([]string, i+1)
			for j := 0; j <= i; j++ { pattern[i][j] = "" }
		}
		wall := make([][]string, 5)
		for i := 0; i < 5; i++ {
			wall[i] = make([]string, 5)
			for j := 0; j < 5; j++ { wall[i][j] = "" }
		}
		boards[pName] = &PlayerBoard{Score: 0, Wins: 0, PatternLines: pattern, Wall: wall, FloorLine: []string{}}
	}

	state := &GameState{
		Factories:            make([][]string, 5),
		Center:               []string{"first_player"},
		TurnPlayer:           players[0],
		CenterHasFirstPlayer: true,
		Boards:               boards,
        Bag:                  bag,
        Discard:              []string{},
        Status:               "PLAYING",
        LastScored:           make(map[string]map[string]int),
		ActiveSelection:      make(map[string]interface{}),
	}

    for i := 0; i < 5; i++ { state.Factories[i] = drawTiles(state, 4) }
    return state
}

func drawTiles(state *GameState, count int) []string {
	drawn := []string{}
	for i := 0; i < count; i++ {
		if len(state.Bag) == 0 {
			if len(state.Discard) == 0 { break }
			state.Bag = append(state.Bag, state.Discard...)
			state.Discard = []string{}
			rand.Shuffle(len(state.Bag), func(a, b int) { state.Bag[a], state.Bag[b] = state.Bag[b], state.Bag[a] })
		}
		tile := state.Bag[len(state.Bag)-1]
		state.Bag = state.Bag[:len(state.Bag)-1]
		drawn = append(drawn, tile)
	}
	return drawn
}

func scoreRound(state *GameState, playerOrder []string) {
	wallPattern := [][]string{
		{"blue", "yellow", "red", "black", "purple"},
		{"purple", "blue", "yellow", "red", "black"},
		{"black", "purple", "blue", "yellow", "red"},
		{"red", "black", "purple", "blue", "yellow"},
		{"yellow", "red", "black", "purple", "blue"},
	}
	penalties := []int{-1, -1, -2, -2, -2, -3, -3}
	
    state.LastScored = make(map[string]map[string]int)
    state.TurnPlayer = "" 

	for pName, board := range state.Boards {
        state.LastScored[pName] = make(map[string]int)

		for r := 0; r < 5; r++ {
			isFull := true
			color := ""
			for c := 0; c <= r; c++ {
				if board.PatternLines[r][c] == "" { isFull = false; break }
				color = board.PatternLines[r][c]
			}
			if isFull && color != "" {
                targetC := -1
				for c := 0; c < 5; c++ {
					if wallPattern[r][c] == color { targetC = c; break }
				}
                if targetC != -1 {
                    board.Wall[r][targetC] = color
                    hScore := 1
                    for j := targetC - 1; j >= 0 && board.Wall[r][j] != ""; j-- { hScore++ }
                    for j := targetC + 1; j < 5 && board.Wall[r][j] != ""; j++ { hScore++ }
                    vScore := 1
                    for i := r - 1; i >= 0 && board.Wall[i][targetC] != ""; i-- { vScore++ }
                    for i := r + 1; i < 5 && board.Wall[i][targetC] != ""; i++ { vScore++ }

                    pts := 0
                    if hScore > 1 && vScore > 1 { pts = hScore + vScore } else if hScore > 1 { pts = hScore } else if vScore > 1 { pts = vScore } else { pts = 1 }
                    board.Score += pts
                    state.LastScored[pName][strconv.Itoa(r)] = pts
                }
                for i := 0; i < r; i++ { state.Discard = append(state.Discard, color) }
				for c := 0; c <= r; c++ { board.PatternLines[r][c] = "" }
			}
		}

        for i, tile := range board.FloorLine {
			if tile == "first_player" {
				state.TurnPlayer = pName
			} else {
                state.Discard = append(state.Discard, tile)
            }
			if i < len(penalties) { 
                board.Score += penalties[i] 
            } else { 
                board.Score -= 3 
            }
		}

        if board.Score < 0 { board.Score = 0 }
		board.FloorLine = []string{}
	}
	
    if state.TurnPlayer == "" && len(playerOrder) > 0 {
        state.TurnPlayer = playerOrder[0]
    }

    gameIsOver := false
    maxScore := -1
    for _, b := range state.Boards {
        for r := 0; r < 5; r++ {
            rowComplete := true
            for c := 0; c < 5; c++ { if b.Wall[r][c] == "" { rowComplete = false; break } }
            if rowComplete { gameIsOver = true; break }
        }
    }

    if gameIsOver {
        state.Status = "GAME_OVER"
        for _, b := range state.Boards {
            for r := 0; r < 5; r++ {
                comp := true
                for c := 0; c < 5; c++ { if b.Wall[r][c] == "" { comp = false; break } }
                if comp { b.Score += 2 }
            }
            for c := 0; c < 5; c++ {
                comp := true
                for r := 0; r < 5; r++ { if b.Wall[r][c] == "" { comp = false; break } }
                if comp { b.Score += 7 }
            }
            colors := []string{"blue", "yellow", "red", "black", "purple"}
            for _, color := range colors {
                count := 0
                for r := 0; r < 5; r++ {
                    for c := 0; c < 5; c++ { if b.Wall[r][c] == color { count++ } }
                }
                if count == 5 { b.Score += 10 }
            }
            if b.Score > maxScore {
                maxScore = b.Score
            }
        }
        
        for _, b := range state.Boards {
            if b.Score == maxScore {
                b.Wins++
            }
        }
        return
    }

	for i := 0; i < len(state.Factories); i++ {
		state.Factories[i] = drawTiles(state, 4)
	}
	state.CenterHasFirstPlayer = true
	state.Center = []string{"first_player"}
}