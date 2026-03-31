package main

import (
	"encoding/json"
	"math/rand"
	"net/http"
	"sync"
	"time"
	"github.com/gorilla/websocket"
)

type Room struct {
	Code     string
	Players  []string
	Clients  map[*websocket.Conn]string
	State    *GameState
	GameType string
	mu       sync.RWMutex
}

var upgrader = websocket.Upgrader{CheckOrigin: func(r *http.Request) bool { return true }}

func generateCode() string {
	const l = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	return string([]byte{l[rand.Intn(26)], l[rand.Intn(26)], l[rand.Intn(26)], l[rand.Intn(26)]})
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
				
                if room.State == nil {
				    var newPlayers []string
				    for _, p := range room.Players { if p != currentName { newPlayers = append(newPlayers, p) } }
				    room.Players = newPlayers
                }
				isEmpty := len(room.Clients) == 0
				room.mu.Unlock()

				if isEmpty {
					go func(code string) {
						time.Sleep(2 * time.Minute)
						roomsMu.Lock()
						if r, stillExists := rooms[code]; stillExists {
							r.mu.Lock()
							if len(r.Clients) == 0 { delete(rooms, code) }
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
                
                inPlayers := false
                for _, name := range room.Players {
                    if name == p.Name { inPlayers = true; break }
                }
                if !inPlayers { room.Players = append(room.Players, p.Name) }

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
			rooms[code] = &Room{Code: code, Players: []string{p.Name}, Clients: make(map[*websocket.Conn]string), GameType: "mosaic"}
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
			} else {
                currentRoomCode = p.Code; currentName = p.Name
                rooms[p.Code] = &Room{Code: p.Code, Players: []string{p.Name}, Clients: make(map[*websocket.Conn]string), GameType: "mosaic"}
                rooms[p.Code].Clients[ws] = p.Name
                broadcastRoom(rooms[p.Code])
            }
		}

        if msg.Type == "CHANGE_GAME" {
            var p struct { Code string `json:"code"`; Game string `json:"game"` }
            json.Unmarshal(msg.Payload, &p)
            if room, exists := rooms[p.Code]; exists {
                if len(room.Players) > 0 && room.Players[0] == currentName {
                    room.GameType = p.Game
                    broadcastRoom(room)
                }
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

        if msg.Type == "RETURN_TO_LOBBY" {
			var p struct{ Code string `json:"code"` }
			json.Unmarshal(msg.Payload, &p)
			if room, ok := rooms[p.Code]; ok {
				room.State = nil 
				broadcastRoom(room)
                broadcastMessage(room, "RETURN_TO_LOBBY", nil)
			}
		}

		if msg.Type == "PLAY_AGAIN" {
			var p struct{ Code string `json:"code"` }
			json.Unmarshal(msg.Payload, &p)
			if room, ok := rooms[p.Code]; ok && room.State != nil {
                state := room.State
                bag := make([]string, 0, 100)
                colors := []string{"blue", "yellow", "red", "black", "amethyst"} // Synchronized with V23
                for _, c := range colors {
                    for i := 0; i < 20; i++ { bag = append(bag, c) }
                }
                rand.Shuffle(len(bag), func(i, j int) { bag[i], bag[j] = bag[j], bag[i] })
                
                state.Bag = bag
                state.Discard = []string{}
                state.Status = "PLAYING"
                state.LastScored = make(map[string]map[string]int)
                state.TurnPlayer = room.Players[0] 
                state.ActiveSelection = make(map[string]interface{})
                
                for _, pName := range room.Players {
                    if b, exists := state.Boards[pName]; exists {
                        b.Score = 0
                        b.FloorLine = []string{}
                        for r := 0; r < 5; r++ {
                            for c := 0; c <= r; c++ { b.PatternLines[r][c] = "" }
                            for c := 0; c < 5; c++ { b.Wall[r][c] = "" }
                        }
                    }
                }
                
                for i := 0; i < 5; i++ { state.Factories[i] = drawTiles(state, 4) }
                state.CenterHasFirstPlayer = true
                state.Center = []string{"first_player"}
                
				broadcastMessage(room, "GAME_STARTED", state)
			}
		}

        if msg.Type == "HOVER_TILE" {
            var p struct {
                Code      string `json:"code"`
                Name      string `json:"name"`
                Selection interface{} `json:"selection"`
            }
            json.Unmarshal(msg.Payload, &p)
            if room, ok := rooms[p.Code]; ok && room.State != nil {
                if room.State.ActiveSelection == nil {
                    room.State.ActiveSelection = make(map[string]interface{})
                }
                if p.Selection == nil {
                    delete(room.State.ActiveSelection, p.Name)
                } else {
                    room.State.ActiveSelection[p.Name] = p.Selection
                }
                broadcastMessage(room, "GAME_UPDATE", room.State)
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
				if room.State.TurnPlayer != p.Player || room.State.Status == "GAME_OVER" { 
                    roomsMu.Unlock()
                    continue 
                }

                if room.State.ActiveSelection != nil {
                    delete(room.State.ActiveSelection, p.Player)
                }

				pickedCount := 0
				board := room.State.Boards[p.Player]
				
                addToFloor := func(c string) {
                    if len(board.FloorLine) < 7 {
                        board.FloorLine = append(board.FloorLine, c)
                    } else {
                        room.State.Discard = append(room.State.Discard, c)
                    }
                }

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
							addToFloor("first_player")
						} else {
							newCenter = append(newCenter, tile)
						}
					}
					room.State.Center = newCenter
				}

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
							addToFloor(p.Color)
						}
					}
				} else {
					for i := 0; i < pickedCount; i++ { addToFloor(p.Color) }
				}

				for i, name := range room.Players {
					if name == p.Player {
						nextIdx := (i + 1) % len(room.Players)
						room.State.TurnPlayer = room.Players[nextIdx]
						break
					}
				}

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
					go func(r *Room, currentPlayers []string) {
						time.Sleep(100 * time.Millisecond)
						r.mu.Lock()
						scoreRound(r.State, currentPlayers)
						status := r.State.Status
						r.mu.Unlock()
						
						if status == "GAME_OVER" {
							broadcastMessage(r, "GAME_OVER", r.State)
						} else {
							broadcastMessage(r, "GAME_UPDATE", r.State)
						}
					}(room, room.Players)
				} else {
					broadcastMessage(room, "GAME_UPDATE", room.State)
				}
			}
		}

		roomsMu.Unlock()
	}
}

func broadcastRoom(r *Room) {
	r.mu.RLock()
	defer r.mu.RUnlock()
    gameType := r.GameType
    if gameType == "" { gameType = "mosaic" }
	data, _ := json.Marshal(map[string]interface{}{"type": "ROOM_UPDATE", "payload": map[string]interface{}{"code": r.Code, "players": r.Players, "game": gameType}})
	for client := range r.Clients { client.WriteMessage(websocket.TextMessage, data) }
}

func broadcastMessage(r *Room, t string, p interface{}) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	data, _ := json.Marshal(map[string]interface{}{"type": t, "payload": p})
	for client := range r.Clients { client.WriteMessage(websocket.TextMessage, data) }
}