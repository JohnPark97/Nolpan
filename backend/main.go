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
	Factories  [][]string              `json:"factories"`
	Center     []string                `json:"center"`
	TurnPlayer string                  `json:"turn_player"` // NEW: Explicit turn tracking
	Boards     map[string]*PlayerBoard `json:"boards"`
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
				for _, p := range room.Players {
					if p != currentName { newPlayers = append(newPlayers, p) }
				}
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
					data, _ := json.Marshal(map[string]interface{}{"type": "GAME_STARTED", "payload": room.State})
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
		roomsMu.Unlock()
	}
}

func generateCode() string {
	const l = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	return string([]byte{l[rand.Intn(26)], l[rand.Intn(26)], l[rand.Intn(26)], l[rand.Intn(26)]})
}

func generateInitialState(players []string) *GameState {
	colors := []string{"blue", "yellow", "red", "black", "white"}
	factories := make([][]string, 5)
	for i := 0; i < 5; i++ {
		tileGroup := []string{}
		for j := 0; j < 4; j++ { tileGroup = append(tileGroup, colors[rand.Intn(len(colors))]) }
		factories[i] = tileGroup
	}

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

	return &GameState{
		Factories:  factories,
		Center:     []string{},
		TurnPlayer: players[0], // Set first player as turn starter
		Boards:     boards,
	}
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