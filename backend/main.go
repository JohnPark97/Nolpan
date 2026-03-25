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
	TypeStartGame   = "START_GAME"
	TypeGameState   = "GAME_STATE"
)

type Message struct {
	Type    string          `json:"type"`
	Payload json.RawMessage `json:"payload"`
}

type GameState struct {
	Factories   [][]string `json:"factories"`
	CenterPool  []string   `json:"center_pool"`
	CurrentTurn int        `json:"current_turn"`
}

type Room struct {
	Code    string
	Players map[*websocket.Conn]string
	Game    *GameState
	mu      sync.Mutex
}

var (
	upgrader = websocket.Upgrader{CheckOrigin: func(r *http.Request) bool { return true }}
	rooms    = make(map[string]*Room)
	mu       sync.Mutex
)

func main() {
	rand.Seed(time.Now().UnixNano())
	http.HandleFunc("/ws", handleConnections)
	
	port := os.Getenv("PORT")
	if port == "" { port = "8080" }
	
	log.Printf("Nolpan Engine live on :%s", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}

func handleConnections(w http.ResponseWriter, r *http.Request) {
	ws, err := upgrader.Upgrade(w, r, nil)
	if err != nil { return }
	defer ws.Close()

	for {
		var msg Message
		if err := ws.ReadJSON(&msg); err != nil { break }

		switch msg.Type {
		case TypeCreateRoom:
			code := fmt.Sprintf("%d", 1000+rand.Intn(8999))
			mu.Lock()
			rooms[code] = &Room{Code: code, Players: make(map[*websocket.Conn]string)}
			mu.Unlock()
			resp, _ := json.Marshal(map[string]string{"code": code})
			ws.WriteJSON(Message{Type: TypeRoomCreated, Payload: resp})

		case TypeStartGame:
			// Logic: Mosaic Master (Azul) Dealer
			tiles := []string{"Azure", "Amber", "Ruby", "Onyx", "Pearl"}
			factories := make([][]string, 5)
			for i := 0; i < 5; i++ {
				f := make([]string, 4)
				for j := 0; j < 4; j++ {
					f[j] = tiles[rand.Intn(len(tiles))]
				}
				factories[i] = f
			}
			state := &GameState{Factories: factories, CenterPool: []string{}, CurrentTurn: 0}
			resp, _ := json.Marshal(state)
			ws.WriteJSON(Message{Type: TypeGameState, Payload: resp})
		}
	}
}