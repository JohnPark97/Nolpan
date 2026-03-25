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

type GameState struct {
	Factories [][]string `json:"factories"`
	Center    []string   `json:"center"`
	Turn      int        `json:"turn"`
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
					delete(rooms, currentRoomCode)
					log.Printf("Room %s garbage collected.", currentRoomCode)
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

		roomsMu.Lock()
		if msg.Type == "CREATE_ROOM" {
			var p struct{ Name string `json:"name"` }
			json.Unmarshal(msg.Payload, &p)
			code := generateCode()
			currentRoomCode = code
			currentName = p.Name
			rooms[code] = &Room{Code: code, Players: []string{p.Name}, Clients: make(map[*websocket.Conn]string)}
			rooms[code].Clients[ws] = p.Name
			broadcastRoom(rooms[code])
		}

		if msg.Type == "JOIN_ROOM" {
			var p struct {
				Name string `json:"name"`
				Code string `json:"code"`
			}
			json.Unmarshal(msg.Payload, &p)
			if room, exists := rooms[p.Code]; exists {
				currentRoomCode = p.Code
				currentName = p.Name
				room.Players = append(room.Players, p.Name)
				room.Clients[ws] = p.Name
				broadcastRoom(room)
			} else {
				errData, _ := json.Marshal(map[string]interface{}{"type": "ERROR", "payload": "Room " + p.Code + " does not exist."})
				ws.WriteMessage(websocket.TextMessage, errData)
			}
		}

		if msg.Type == "START_GAME" {
			var p struct {
				Code string `json:"code"`
			}
			json.Unmarshal(msg.Payload, &p)
			
			log.Printf("-> Received START_GAME for room: %s", p.Code)
			
			if room, ok := rooms[p.Code]; ok {
				room.State = generateInitialState()
				log.Printf("-> Generating Tiles... Broadcasting GAME_STARTED to %s", p.Code)
				broadcastMessage(room, "GAME_STARTED", room.State)
			} else {
				log.Printf("-> ERROR: Tried to start game for missing room %s", p.Code)
			}
		}
		roomsMu.Unlock()
	}
}

func generateCode() string {
	const l = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	return string([]byte{l[rand.Intn(26)], l[rand.Intn(26)], l[rand.Intn(26)], l[rand.Intn(26)]})
}

func generateInitialState() *GameState {
	colors := []string{"blue", "yellow", "red", "black", "white"}
	factories := make([][]string, 5)
	for i := 0; i < 5; i++ {
		tileGroup := []string{}
		for j := 0; j < 4; j++ { tileGroup = append(tileGroup, colors[rand.Intn(len(colors))]) }
		factories[i] = tileGroup
	}
	return &GameState{Factories: factories, Center: []string{}, Turn: 0}
}

func broadcastRoom(r *Room) {
	broadcastMessage(r, "ROOM_UPDATE", map[string]interface{}{"code": r.Code, "players": r.Players})
}

func broadcastMessage(r *Room, t string, p interface{}) {
	data, _ := json.Marshal(map[string]interface{}{"type": t, "payload": p})
	for client := range r.Clients {
		client.WriteMessage(websocket.TextMessage, data)
	}
}