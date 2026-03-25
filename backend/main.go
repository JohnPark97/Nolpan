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

type Room struct {
	Code    string
	Players []string
	Clients map[*websocket.Conn]string
	mu      sync.RWMutex
}

var (
	upgrader = websocket.Upgrader{CheckOrigin: func(r *http.Request) bool { return true }}
	rooms    = make(map[string]*Room)
	roomsMu  sync.RWMutex
)

func main() {
	rand.Seed(time.Now().UnixNano())
	http.HandleFunc("/ws", handleConnections)
	port := os.Getenv("PORT")
	if port == "" { port = "8080" }
	log.Printf("Server Live on :%s", port)
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

		if msg.Type == "CREATE_ROOM" {
			var p struct{ Name string `json:"name"` }
			json.Unmarshal(msg.Payload, &p)
			code := ""
			const letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
			for i := 0; i < 4; i++ { code += string(letters[rand.Intn(len(letters))]) }
			room := &Room{Code: code, Players: []string{p.Name}, Clients: make(map[*websocket.Conn]string)}
			room.Clients[ws] = p.Name
			roomsMu.Lock()
			rooms[code] = room
			roomsMu.Unlock()
			broadcastRoom(room)
		}

		if msg.Type == "JOIN_ROOM" {
			var p struct{ Name string `json:"name"; Code string `json:"code"` }
			json.Unmarshal(msg.Payload, &p)
			roomsMu.RLock()
			room, exists := rooms[p.Code]
			roomsMu.RUnlock()
			if exists {
				room.mu.Lock()
				room.Players = append(room.Players, p.Name)
				room.Clients[ws] = p.Name
				room.mu.Unlock()
				broadcastRoom(room)
			}
		}
	}
}

func broadcastRoom(r *Room) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	data, _ := json.Marshal(map[string]interface{}{
		"type": "ROOM_UPDATE",
		"payload": map[string]interface{}{"code": r.Code, "players": r.Players},
	})
	for client := range r.Clients {
		client.WriteMessage(websocket.TextMessage, data)
	}
}