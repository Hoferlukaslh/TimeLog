// TimeLog synchronization server: accounts (e-mail + password) and the data
// of the TimeLog app, stored in MariaDB. See README.md and API.md.
package main

import (
	"context"
	"database/sql"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	_ "github.com/go-sql-driver/mysql"
)

func env(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func envInt(key string, def int) int {
	if v, err := strconv.Atoi(os.Getenv(key)); err == nil && v > 0 {
		return v
	}
	return def
}

func main() {
	dsn := env("DB_DSN", "timelog:timelog@tcp(localhost:3306)/timelog?charset=utf8mb4&parseTime=true")
	addr := env("LISTEN_ADDR", ":8080")

	db, err := sql.Open("mysql", dsn)
	if err != nil {
		log.Fatalf("database: %v", err)
	}
	db.SetMaxOpenConns(20)
	db.SetConnMaxLifetime(5 * time.Minute)

	// The database container may need a few seconds to start.
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	for {
		if err = db.PingContext(ctx); err == nil {
			break
		}
		log.Printf("waiting for the database: %v", err)
		select {
		case <-ctx.Done():
			log.Fatalf("database unavailable: %v", err)
		case <-time.After(2 * time.Second):
		}
	}
	cancel()

	store := &Store{db: db}
	if err := store.Migrate(context.Background()); err != nil {
		log.Fatalf("migration: %v", err)
	}

	srv := &Server{
		store:       store,
		sessionDays: envInt("SESSION_DAYS", 180),
		maxBody:     int64(envInt("MAX_BODY_MB", 256)) << 20,
		logins:      newLimiter(10, 15*time.Minute),
	}
	httpServer := &http.Server{
		Addr:              addr,
		Handler:           srv.Routes(),
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       5 * time.Minute, // big attachments
		WriteTimeout:      5 * time.Minute,
		IdleTimeout:       2 * time.Minute,
	}

	// Cleanup of expired sessions.
	go func() {
		for range time.Tick(6 * time.Hour) {
			if err := store.DeleteExpiredSessions(context.Background()); err != nil {
				log.Printf("session cleanup: %v", err)
			}
		}
	}()

	go func() {
		log.Printf("TimeLog server listening on %s", addr)
		if err := httpServer.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("http: %v", err)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	<-stop
	log.Print("shutting down")
	shutdown, cancelShutdown := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancelShutdown()
	_ = httpServer.Shutdown(shutdown)
	_ = db.Close()
}
