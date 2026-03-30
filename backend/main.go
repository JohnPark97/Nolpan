package main

import (
	"log"
	"math/rand"
	"net/http"
	"os"
	"sync"
	"time"
)

var (
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