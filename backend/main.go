package main

import (
	"encoding/json"
	"fmt"
	"log"
	"math/rand"
	"net/http"
	"sync"
	"time"
	"github.com/gorilla/websocket"
)

const (
	TypeCreateRoom = "CREATE_ROOM"
	TypeJoinRoom   = "JOIN_ROOM"
)

type Message struct {
	Type    string          `json:"type"`
	Payload json.RawMessage `json:"payload"`
}

var (
	upgrader = websocket.Upgrader{
		CheckOrigin: func(r *http.Request) bool { return true },
	}
	rooms = make(map[string]interface{})
	mu    sync.Mutex
)

func main() {
	rand.Seed(time.Now().UnixNano())
	http.HandleFunc("/ws", handleConnections)
	fmt.Println("Nolpan Go Hub running on :8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}

func handleConnections(w http.ResponseWriter, r *http.Request) {
	ws, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("error: %v", err)
		return
	}
	defer ws.Close()
	for {
		var msg Message
		err := ws.ReadJSON(&msg)
		if err != nil { break }
		fmt.Printf("Message: %s\\n", msg.Type)
	}
}