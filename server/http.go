package main

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"log"
	"net"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/go-sql-driver/mysql"
)

// Server exposes the REST API used by the app (see API.md).
type Server struct {
	store       *Store
	sessionDays int
	maxBody     int64
	logins      *limiter
}

// Allowed synchronized tables (same list as the app: lib/sync/sync_schema.dart).
var syncTables = map[string]bool{
	"settings": true, "categories": true, "time_entries": true, "vacation_years": true,
	"journal_entries": true, "notes": true, "attachments": true,
}

const (
	pullMaxRows  = 500
	pullMaxBytes = 16 << 20
)

func (s *Server) Routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /api/v1/health", s.health)
	mux.HandleFunc("POST /api/v1/auth/signup", s.signup)
	mux.HandleFunc("POST /api/v1/auth/login", s.login)
	mux.HandleFunc("POST /api/v1/auth/logout", s.auth(s.logout))
	mux.HandleFunc("GET /api/v1/account", s.auth(s.account))
	mux.HandleFunc("POST /api/v1/account/delete", s.auth(s.deleteAccount))
	mux.HandleFunc("POST /api/v1/sync/push", s.auth(s.push))
	mux.HandleFunc("GET /api/v1/sync/pull", s.auth(s.pull))
	return logRequests(mux)
}

// ------------------------------------------------------------------ helpers

type apiError struct {
	Error string `json:"error"`
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

// fail answers with a stable error code (translated by the app).
func fail(w http.ResponseWriter, status int, code string) { writeJSON(w, status, apiError{code}) }

func (s *Server) decode(w http.ResponseWriter, r *http.Request, v any) bool {
	r.Body = http.MaxBytesReader(w, r.Body, s.maxBody)
	if err := json.NewDecoder(r.Body).Decode(v); err != nil {
		var tooBig *http.MaxBytesError
		if errors.As(err, &tooBig) {
			fail(w, http.StatusRequestEntityTooLarge, "too_large")
		} else {
			fail(w, http.StatusBadRequest, "bad_request")
		}
		return false
	}
	return true
}

func internal(w http.ResponseWriter, err error) {
	log.Printf("error: %v", err)
	fail(w, http.StatusInternalServerError, "server_error")
}

func clientIP(r *http.Request) string {
	if ip := strings.TrimSpace(strings.Split(r.Header.Get("X-Forwarded-For"), ",")[0]); ip != "" {
		return ip
	}
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}

func encodeBase64(b []byte) string { return base64.StdEncoding.EncodeToString(b) }

type statusWriter struct {
	http.ResponseWriter
	status int
}

func (w *statusWriter) WriteHeader(s int) { w.status = s; w.ResponseWriter.WriteHeader(s) }

func logRequests(h http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		sw := &statusWriter{ResponseWriter: w, status: http.StatusOK}
		h.ServeHTTP(sw, r)
		log.Printf("%s %s %d %s", r.Method, r.URL.Path, sw.status, time.Since(start).Round(time.Millisecond))
	})
}

// ---------------------------------------------------------------- sessions

type ctxKey int

const (
	ctxAccount ctxKey = iota
	ctxEmail
	ctxToken
)

func bearer(r *http.Request) string {
	h := r.Header.Get("Authorization")
	if t, ok := strings.CutPrefix(h, "Bearer "); ok {
		return strings.TrimSpace(t)
	}
	return ""
}

// auth requires a valid session token ("Authorization: Bearer <token>").
func (s *Server) auth(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		token := bearer(r)
		if token == "" {
			fail(w, http.StatusUnauthorized, "unauthorized")
			return
		}
		hash := hashToken(token)
		id, email, err := s.store.SessionAccount(r.Context(), hash, time.Now().AddDate(0, 0, s.sessionDays))
		if errors.Is(err, errNotFound) {
			fail(w, http.StatusUnauthorized, "unauthorized")
			return
		}
		if err != nil {
			internal(w, err)
			return
		}
		ctx := context.WithValue(r.Context(), ctxAccount, id)
		ctx = context.WithValue(ctx, ctxEmail, email)
		ctx = context.WithValue(ctx, ctxToken, hash)
		next(w, r.WithContext(ctx))
	}
}

func accountOf(r *http.Request) int64 { return r.Context().Value(ctxAccount).(int64) }

// ---------------------------------------------------------------- handlers

func (s *Server) health(w http.ResponseWriter, r *http.Request) {
	if err := s.store.db.PingContext(r.Context()); err != nil {
		fail(w, http.StatusServiceUnavailable, "database_unavailable")
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok", "app": "TimeLog"})
}

type credentials struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

type sessionResponse struct {
	Token     string `json:"token"`
	AccountID string `json:"account_id"`
	Email     string `json:"email"`
}

func (s *Server) openSession(w http.ResponseWriter, r *http.Request, id int64, email string, status int) {
	token, hash, err := newToken()
	if err != nil {
		internal(w, err)
		return
	}
	if err := s.store.CreateSession(r.Context(), hash, id, time.Now().AddDate(0, 0, s.sessionDays)); err != nil {
		internal(w, err)
		return
	}
	writeJSON(w, status, sessionResponse{Token: token, AccountID: strconv.FormatInt(id, 10), Email: email})
}

func (s *Server) signup(w http.ResponseWriter, r *http.Request) {
	var c credentials
	if !s.decode(w, r, &c) {
		return
	}
	email, ok := normalizeEmail(c.Email)
	if !ok {
		fail(w, http.StatusBadRequest, "invalid_email")
		return
	}
	if !validPassword(c.Password) {
		fail(w, http.StatusBadRequest, "weak_password")
		return
	}
	hash, err := hashPassword(c.Password)
	if err != nil {
		internal(w, err)
		return
	}
	id, err := s.store.CreateAccount(r.Context(), email, hash)
	var myErr *mysql.MySQLError
	if errors.As(err, &myErr) && myErr.Number == 1062 { // duplicate key
		fail(w, http.StatusConflict, "email_taken")
		return
	}
	if err != nil {
		internal(w, err)
		return
	}
	s.openSession(w, r, id, email, http.StatusCreated)
}

func (s *Server) login(w http.ResponseWriter, r *http.Request) {
	var c credentials
	if !s.decode(w, r, &c) {
		return
	}
	email, _ := normalizeEmail(c.Email)
	key := clientIP(r) + "|" + email
	if s.logins.Blocked(key) {
		fail(w, http.StatusTooManyRequests, "too_many_attempts")
		return
	}
	id, hash, err := s.store.AccountByEmail(r.Context(), email)
	if err != nil && !errors.Is(err, errNotFound) {
		internal(w, err)
		return
	}
	if errors.Is(err, errNotFound) {
		hash = string(dummyHash)
	}
	if !checkPassword(hash, c.Password) || errors.Is(err, errNotFound) {
		s.logins.Fail(key)
		fail(w, http.StatusUnauthorized, "invalid_credentials")
		return
	}
	s.logins.Reset(key)
	s.openSession(w, r, id, email, http.StatusOK)
}

func (s *Server) logout(w http.ResponseWriter, r *http.Request) {
	if err := s.store.DeleteSession(r.Context(), r.Context().Value(ctxToken).(string)); err != nil {
		internal(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) account(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{
		"account_id": strconv.FormatInt(accountOf(r), 10),
		"email":      r.Context().Value(ctxEmail).(string),
	})
}

// deleteAccount removes the account and all its data (the password is asked again).
func (s *Server) deleteAccount(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Password string `json:"password"`
	}
	if !s.decode(w, r, &body) {
		return
	}
	_, hash, err := s.store.AccountByID(r.Context(), accountOf(r))
	if err != nil {
		internal(w, err)
		return
	}
	if !checkPassword(hash, body.Password) {
		fail(w, http.StatusUnauthorized, "invalid_credentials")
		return
	}
	if err := s.store.DeleteAccount(r.Context(), accountOf(r)); err != nil {
		internal(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

type pushRequest struct {
	DeviceID string   `json:"device_id"`
	Changes  []Change `json:"changes"`
}

func (s *Server) push(w http.ResponseWriter, r *http.Request) {
	var req pushRequest
	if !s.decode(w, r, &req) {
		return
	}
	if req.DeviceID == "" || len(req.DeviceID) > 64 {
		fail(w, http.StatusBadRequest, "bad_request")
		return
	}
	data := make([][]byte, len(req.Changes))
	for i := range req.Changes {
		c := &req.Changes[i]
		if !syncTables[c.Table] || c.UID == "" || len(c.UID) > 100 {
			fail(w, http.StatusBadRequest, "bad_request")
			return
		}
		c.DeviceID = req.DeviceID
		if c.Data != nil {
			b, err := base64.StdEncoding.DecodeString(*c.Data)
			if err != nil {
				fail(w, http.StatusBadRequest, "bad_request")
				return
			}
			data[i] = b
		}
	}
	if err := s.store.Push(r.Context(), accountOf(r), req.Changes, data); err != nil {
		internal(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]int{"accepted": len(req.Changes)})
}

type pullResponse struct {
	Changes []Change `json:"changes"`
	Cursor  string   `json:"cursor"`
	HasMore bool     `json:"has_more"`
}

func (s *Server) pull(w http.ResponseWriter, r *http.Request) {
	var cursor int64
	if c := r.URL.Query().Get("cursor"); c != "" {
		var err error
		if cursor, err = strconv.ParseInt(c, 10, 64); err != nil || cursor < 0 {
			fail(w, http.StatusBadRequest, "bad_request")
			return
		}
	}
	records, hasMore, err := s.store.Pull(r.Context(), accountOf(r), cursor, pullMaxRows, pullMaxBytes)
	if err != nil {
		internal(w, err)
		return
	}
	resp := pullResponse{Changes: []Change{}, Cursor: strconv.FormatInt(cursor, 10), HasMore: hasMore}
	for _, p := range records {
		resp.Changes = append(resp.Changes, p.Change)
		resp.Cursor = strconv.FormatInt(p.Seq, 10)
	}
	writeJSON(w, http.StatusOK, resp)
}
