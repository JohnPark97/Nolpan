package main

import (
	"encoding/json"
	"fmt"
	"log"
	"math/rand"
	"net/http"
	"os"
	"sync"
	"time"
	"github.com/gorilla/websocket"
)

const (
	TypeCreateRoom  = "CREATE_ROOM"
	TypeRoomCreated = "ROOM_CREATED"
)

type Message struct {
	Type    string          `json:"type"`
	Payload json.RawMessage `json:"payload"`
}

type Room struct {
	Code    string
	Clients map[*websocket.Conn]bool
	mu      sync.RWMutex
}

var (
	upgrader = websocket.Upgrader{CheckOrigin: func(r *http.Request) bool { return true }}
	rooms    = make(map[string]*Room)
	roomsMu  sync.RWMutex
)

func generateRoomCode() string {
	const letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	b := make([]byte, 4)
	for i := range b { b[i] = letters[rand.Intn(len(letters))] }
	return string(b)
}

func main() {
	rand.Seed(time.Now().UnixNano())
	http.HandleFunc("/ws", handleConnections)

	port := os.Getenv("PORT")
	if port == "" { port = "8080" }

	log.Printf("Nolpan Pro Server listening on port %s", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}

func handleConnections(w http.ResponseWriter, r *http.Request) {
	ws, err := upgrader.Upgrade(w, r, nil)
	if err != nil { return }
	defer ws.Close()

	for {
		var msg Message
		if err := ws.ReadJSON(&msg); err != nil { break }

		if msg.Type == TypeCreateRoom {
			code := generateRoomCode()

			roomsMu.Lock()
			rooms[code] = &Room{
				Code:    code,
				Clients: make(map[*websocket.Conn]bool),
			}
			rooms[code].Clients[ws] = true
			roomsMu.Unlock()

			resp, _ := json.Marshal(map[string]string{"code": code})
			
			rooms[code].mu.Lock()
			ws.WriteJSON(Message{Type: TypeRoomCreated, Payload: resp})
			rooms[code].mu.Unlock()
			
			log.Printf("Room %s created", code)
		}
	}
}