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
	
	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	})
	
	http.HandleFunc("/ws", handleConnections)
	port := os.Getenv("PORT")
	if port == "" { port = "8080" }
	log.Printf("Engine Live on :%s", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}

func handleConnections(w http.ResponseWriter, r *http.Request) {
	ws, err := upgrader.Upgrade(w, r, nil)
	if err != nil { return }
	defer ws.Close()

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
			rooms[code] = &Room{Code: code, Players: []string{p.Name}, Clients: make(map[*websocket.Conn]string)}
			rooms[code].Clients[ws] = p.Name
			broadcastRoom(rooms[code])
		}

		if msg.Type == "JOIN_ROOM" {
			// THE FIX: Properly formatted Go Struct to prevent compile errors
			var p struct {
				Name string `json:"name"`
				Code string `json:"code"`
			}
			json.Unmarshal(msg.Payload, &p)
			
			if room, ok := rooms[p.Code]; ok {
				room.Players = append(room.Players, p.Name)
				room.Clients[ws] = p.Name
				broadcastRoom(room)
			}
		}

		if msg.Type == "START_GAME" {
			var p struct{ Code string `json:"code"` }
			json.Unmarshal(msg.Payload, &p)
			if room, ok := rooms[p.Code]; ok {
				room.State = generateInitialState()
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

func generateInitialState() *GameState {
	colors := []string{"blue", "yellow", "red", "black", "white"}
	factories := make([][]string, 5) 
	for i := 0; i < 5; i++ {
		tileGroup := []string{}
		for j := 0; j < 4; j++ { 
			tileGroup = append(tileGroup, colors[rand.Intn(len(colors))])
		}
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