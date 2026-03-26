package main

import (
	"encoding/json"
	"log"
	"math/rand"
	"net/http"
	"os"
	"sync"
	"time"
	"github.com/gorilla/websocket"
)

type PlayerBoard struct {
	Score        int        `json:"score"`
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
	Bag                  []string                `json:"-"` // Hidden from client
	Discard              []string                `json:"-"` // Hidden from client
	Status               string                  `json:"status"`
}

type Room struct {
	Code    string
	Players []string
	Clients map[*websocket.Conn]string
	State   *GameState
	mu      sync.RWMutex
}

var (
	upgrader = websocket.Upgrader{CheckOrigin: func(r *http.Request) bool { return true }}
	rooms    = make(map[string]*Room)
	roomsMu  sync.RWMutex
)

func main() {
	rand.Seed(time.Now().UnixNano())
	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusOK); w.Write([]byte("OK")) })
	http.HandleFunc("/ws", handleConnections)
	port := os.Getenv("PORT")
	if port == "" { port = "8080" }
	log.Printf("Engine Live on :%s", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}

func handleConnections(w http.ResponseWriter, r *http.Request) {
	ws, err := upgrader.Upgrade(w, r, nil)
	if err != nil { return }
	
	var currentRoomCode string
	var currentName string

	defer func() {
		ws.Close()
		if currentRoomCode != "" {
			roomsMu.Lock()
			if room, ok := rooms[currentRoomCode]; ok {
				room.mu.Lock()
				delete(room.Clients, ws)
				var newPlayers []string
				for _, p := range room.Players { if p != currentName { newPlayers = append(newPlayers, p) } }
				room.Players = newPlayers
				isEmpty := len(room.Players) == 0
				room.mu.Unlock()

				if isEmpty {
					go func(code string) {
						time.Sleep(2 * time.Minute)
						roomsMu.Lock()
						if r, stillExists := rooms[code]; stillExists {
							r.mu.Lock()
							if len(r.Players) == 0 { delete(rooms, code) }
							r.mu.Unlock()
						}
						roomsMu.Unlock()
					}(currentRoomCode)
				} else {
					go broadcastRoom(room)
				}
			}
			roomsMu.Unlock()
		}
	}()

	for {
		var msg struct {
			Type    string          `json:"type"`
			Payload json.RawMessage `json:"payload"`
		}
		if err := ws.ReadJSON(&msg); err != nil { break }
		if msg.Type == "PING" { continue }

		roomsMu.Lock()
		
		if msg.Type == "RECONNECT" {
			var p struct { Name string `json:"name"`; Code string `json:"code"` }
			json.Unmarshal(msg.Payload, &p)
			if room, exists := rooms[p.Code]; exists {
				currentRoomCode = p.Code; currentName = p.Name
				room.Clients[ws] = p.Name
				if room.State != nil {
					data, _ := json.Marshal(map[string]interface{}{"type": "GAME_UPDATE", "payload": room.State})
					ws.WriteMessage(websocket.TextMessage, data)
				}
				broadcastRoom(room)
			}
		}

		if msg.Type == "CREATE_ROOM" {
			var p struct{ Name string `json:"name"` }
			json.Unmarshal(msg.Payload, &p)
			code := generateCode()
			currentRoomCode = code; currentName = p.Name
			rooms[code] = &Room{Code: code, Players: []string{p.Name}, Clients: make(map[*websocket.Conn]string)}
			rooms[code].Clients[ws] = p.Name
			broadcastRoom(rooms[code])
		}

		if msg.Type == "JOIN_ROOM" {
			var p struct { Name string `json:"name"`; Code string `json:"code"` }
			json.Unmarshal(msg.Payload, &p)
			if room, exists := rooms[p.Code]; exists {
				currentRoomCode = p.Code; currentName = p.Name
				room.Players = append(room.Players, p.Name)
				room.Clients[ws] = p.Name
				broadcastRoom(room)
			}
		}

		if msg.Type == "START_GAME" {
			var p struct{ Code string `json:"code"` }
			json.Unmarshal(msg.Payload, &p)
			if room, ok := rooms[p.Code]; ok {
				room.State = generateInitialState(room.Players)
				broadcastMessage(room, "GAME_STARTED", room.State)
			}
		}

        // SPRINT 10: PLAY AGAIN LOGIC
		if msg.Type == "PLAY_AGAIN" {
			var p struct{ Code string `json:"code"` }
			json.Unmarshal(msg.Payload, &p)
			if room, ok := rooms[p.Code]; ok {
				room.State = nil // Wipe game state
				broadcastMessage(room, "RETURN_TO_LOBBY", map[string]interface{}{"code": room.Code, "players": room.Players})
			}
		}

		if msg.Type == "PICK_TILES" {
			var p struct {
				Code      string `json:"code"`
				Player    string `json:"player"`
				KilnIdx   int    `json:"kiln_idx"`
				Color     string `json:"color"`
				TargetRow int    `json:"target_row"`
			}
			json.Unmarshal(msg.Payload, &p)
			
			if room, ok := rooms[p.Code]; ok && room.State != nil {
				if room.State.TurnPlayer != p.Player || room.State.Status == "GAME_OVER" { roomsMu.Unlock(); continue }

				pickedCount := 0
				
				// 1. DRAFT TILES
				if p.KilnIdx >= 0 && p.KilnIdx < len(room.State.Factories) {
					for _, tile := range room.State.Factories[p.KilnIdx] {
						if tile == p.Color { pickedCount++ } else { room.State.Center = append(room.State.Center, tile) }
					}
					room.State.Factories[p.KilnIdx] = []string{}
				} else if p.KilnIdx == -1 {
					newCenter := []string{}
					for _, tile := range room.State.Center {
						if tile == p.Color {
							pickedCount++
						} else if tile == "first_player" {
							room.State.Boards[p.Player].FloorLine = append(room.State.Boards[p.Player].FloorLine, "first_player")
						} else {
							newCenter = append(newCenter, tile)
						}
					}
					room.State.Center = newCenter
				}

				// 2. PLACE TILES
				board := room.State.Boards[p.Player]
				if p.TargetRow >= 0 && p.TargetRow < 5 {
					emptySlots := 0
					for _, slot := range board.PatternLines[p.TargetRow] { if slot == "" { emptySlots++ } }
					
					for i := 0; i < pickedCount; i++ {
						if emptySlots > 0 {
							for j := 0; j < len(board.PatternLines[p.TargetRow]); j++ {
								if board.PatternLines[p.TargetRow][j] == "" {
									board.PatternLines[p.TargetRow][j] = p.Color
									emptySlots--
									break
								}
							}
						} else {
							board.FloorLine = append(board.FloorLine, p.Color)
						}
					}
				} else {
					for i := 0; i < pickedCount; i++ { board.FloorLine = append(board.FloorLine, p.Color) }
				}

				// 3. PASS TURN
				for i, name := range room.Players {
					if name == p.Player {
						nextIdx := (i + 1) % len(room.Players)
						room.State.TurnPlayer = room.Players[nextIdx]
						break
					}
				}

				// 4. CHECK END OF DRAFTING ROUND
				isRoundOver := true
				for _, f := range room.State.Factories {
					if len(f) > 0 { isRoundOver = false; break }
				}
				if isRoundOver {
					for _, t := range room.State.Center {
						if t != "first_player" { isRoundOver = false; break }
					}
				}

				if isRoundOver {
					broadcastMessage(room, "GAME_UPDATE", room.State)
					go func(r *Room) {
						time.Sleep(1500 * time.Millisecond) // The Juice Pause
						r.mu.Lock()
						scoreRound(r.State)
						status := r.State.Status
						r.mu.Unlock()
						
						if status == "GAME_OVER" {
							broadcastMessage(r, "GAME_OVER", r.State)
						} else {
							broadcastMessage(r, "GAME_UPDATE", r.State)
						}
					}(room)
				} else {
					broadcastMessage(room, "GAME_UPDATE", room.State)
				}
			}
		}

		roomsMu.Unlock()
	}
}

// SPRINT 9: THE TILE ECONOMY
func drawTiles(state *GameState, count int) []string {
	drawn := []string{}
	for i := 0; i < count; i++ {
		if len(state.Bag) == 0 {
			if len(state.Discard) == 0 { break } // Board is completely tapped out
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

// SPRINT 8: COMPLEX MATH SCORING
func scoreRound(state *GameState) {
	wallPattern := [][]string{
		{"blue", "yellow", "red", "black", "white"},
		{"white", "blue", "yellow", "red", "black"},
		{"black", "white", "blue", "yellow", "red"},
		{"red", "black", "white", "blue", "yellow"},
		{"yellow", "red", "black", "white", "blue"},
	}
	penalties := []int{-1, -1, -2, -2, -2, -3, -3}
	
	for pName, board := range state.Boards {
		for i, tile := range board.FloorLine {
			if tile == "first_player" {
				state.TurnPlayer = pName
			} else {
                state.Discard = append(state.Discard, tile) // SPRINT 9: To Discard
            }
			if i < len(penalties) { board.Score += penalties[i] } else { board.Score -= 3 }
		}
		if board.Score < 0 { board.Score = 0 }
		board.FloorLine = []string{}
		
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
                    
                    // COMPLEX CONTIGUOUS SCORING
                    hScore := 1
                    for j := targetC - 1; j >= 0 && board.Wall[r][j] != ""; j-- { hScore++ }
                    for j := targetC + 1; j < 5 && board.Wall[r][j] != ""; j++ { hScore++ }
                    vScore := 1
                    for i := r - 1; i >= 0 && board.Wall[i][targetC] != ""; i-- { vScore++ }
                    for i := r + 1; i < 5 && board.Wall[i][targetC] != ""; i++ { vScore++ }

                    if hScore > 1 && vScore > 1 { board.Score += hScore + vScore } else if hScore > 1 { board.Score += hScore } else if vScore > 1 { board.Score += vScore } else { board.Score += 1 }
                }
                
                // Clear pattern line and send rest to discard
                for i := 0; i < r; i++ { state.Discard = append(state.Discard, color) }
				for c := 0; c <= r; c++ { board.PatternLines[r][c] = "" }
			}
		}
	}
	
    // ENDGAME TRIGGER CHECK
    gameIsOver := false
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
            // Horiz +2
            for r := 0; r < 5; r++ {
                comp := true
                for c := 0; c < 5; c++ { if b.Wall[r][c] == "" { comp = false; break } }
                if comp { b.Score += 2 }
            }
            // Vert +7
            for c := 0; c < 5; c++ {
                comp := true
                for r := 0; r < 5; r++ { if b.Wall[r][c] == "" { comp = false; break } }
                if comp { b.Score += 7 }
            }
            // Color +10
            colors := []string{"blue", "yellow", "red", "black", "white"}
            for _, color := range colors {
                count := 0
                for r := 0; r < 5; r++ {
                    for c := 0; c < 5; c++ { if b.Wall[r][c] == color { count++ } }
                }
                if count == 5 { b.Score += 10 }
            }
        }
        return // End round immediately
    }

	// REPOPULATE KILNS FROM BAG
	for i := 0; i < len(state.Factories); i++ {
		state.Factories[i] = drawTiles(state, 4)
	}
	state.CenterHasFirstPlayer = true
	state.Center = []string{"first_player"}
}

func generateCode() string {
	const l = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	return string([]byte{l[rand.Intn(26)], l[rand.Intn(26)], l[rand.Intn(26)], l[rand.Intn(26)]})
}

func generateInitialState(players []string) *GameState {
    bag := make([]string, 0, 100)
	colors := []string{"blue", "yellow", "red", "black", "white"}
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
		boards[pName] = &PlayerBoard{Score: 0, PatternLines: pattern, Wall: wall, FloorLine: []string{}}
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
	}

    for i := 0; i < 5; i++ { state.Factories[i] = drawTiles(state, 4) }
    return state
}

func broadcastRoom(r *Room) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	data, _ := json.Marshal(map[string]interface{}{"type": "ROOM_UPDATE", "payload": map[string]interface{}{"code": r.Code, "players": r.Players}})
	for client := range r.Clients { client.WriteMessage(websocket.TextMessage, data) }
}

func broadcastMessage(r *Room, t string, p interface{}) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	data, _ := json.Marshal(map[string]interface{}{"type": t, "payload": p})
	for client := range r.Clients { client.WriteMessage(websocket.TextMessage, data) }
}