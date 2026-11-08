package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"time"
)

// Store is the MariaDB storage of accounts, sessions and synchronized rows.
type Store struct{ db *sql.DB }

var schema = []string{
	`CREATE TABLE IF NOT EXISTS accounts (
		id BIGINT AUTO_INCREMENT PRIMARY KEY,
		email VARCHAR(255) NOT NULL UNIQUE,
		password_hash VARCHAR(100) NOT NULL,
		last_seq BIGINT NOT NULL DEFAULT 0,
		created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
	) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`,
	`CREATE TABLE IF NOT EXISTS sessions (
		token_hash CHAR(64) PRIMARY KEY,
		account_id BIGINT NOT NULL,
		created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
		expires_at DATETIME NOT NULL,
		KEY idx_sessions_account (account_id),
		CONSTRAINT fk_sessions_account FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE
	) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`,
	// Current state of every synchronized row of every account.
	`CREATE TABLE IF NOT EXISTS records (
		account_id BIGINT NOT NULL,
		tbl VARCHAR(32) NOT NULL,
		uid VARCHAR(100) NOT NULL,
		seq BIGINT NOT NULL,
		deleted TINYINT(1) NOT NULL DEFAULT 0,
		modified_at BIGINT NOT NULL,
		device_id VARCHAR(64) NOT NULL,
		vals LONGTEXT NOT NULL,
		col_times LONGTEXT NOT NULL,
		data LONGBLOB NULL,
		data_time BIGINT NOT NULL DEFAULT 0,
		PRIMARY KEY (account_id, tbl, uid),
		KEY idx_records_seq (account_id, seq),
		CONSTRAINT fk_records_account FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE
	) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin`,
}

func (s *Store) Migrate(ctx context.Context) error {
	for _, q := range schema {
		if _, err := s.db.ExecContext(ctx, q); err != nil {
			return err
		}
	}
	return nil
}

var errNotFound = errors.New("not found")

// ---------------------------------------------------------------- accounts

func (s *Store) CreateAccount(ctx context.Context, email, hash string) (int64, error) {
	res, err := s.db.ExecContext(ctx, `INSERT INTO accounts (email, password_hash) VALUES (?, ?)`, email, hash)
	if err != nil {
		return 0, err
	}
	return res.LastInsertId()
}

func (s *Store) AccountByEmail(ctx context.Context, email string) (id int64, hash string, err error) {
	err = s.db.QueryRowContext(ctx, `SELECT id, password_hash FROM accounts WHERE email = ?`, email).Scan(&id, &hash)
	if errors.Is(err, sql.ErrNoRows) {
		err = errNotFound
	}
	return
}

func (s *Store) AccountByID(ctx context.Context, id int64) (email, hash string, err error) {
	err = s.db.QueryRowContext(ctx, `SELECT email, password_hash FROM accounts WHERE id = ?`, id).Scan(&email, &hash)
	if errors.Is(err, sql.ErrNoRows) {
		err = errNotFound
	}
	return
}

// DeleteAccount removes the account, its sessions and all its data.
func (s *Store) DeleteAccount(ctx context.Context, id int64) error {
	_, err := s.db.ExecContext(ctx, `DELETE FROM accounts WHERE id = ?`, id)
	return err
}

// ---------------------------------------------------------------- sessions

func (s *Store) CreateSession(ctx context.Context, tokenHash string, accountID int64, expires time.Time) error {
	_, err := s.db.ExecContext(ctx,
		`INSERT INTO sessions (token_hash, account_id, expires_at) VALUES (?, ?, ?)`, tokenHash, accountID, expires.UTC())
	return err
}

// SessionAccount returns the account of a valid session and extends it.
func (s *Store) SessionAccount(ctx context.Context, tokenHash string, extendTo time.Time) (int64, string, error) {
	var id int64
	var email string
	err := s.db.QueryRowContext(ctx, `
		SELECT a.id, a.email FROM sessions s JOIN accounts a ON a.id = s.account_id
		WHERE s.token_hash = ? AND s.expires_at > UTC_TIMESTAMP()`, tokenHash).Scan(&id, &email)
	if errors.Is(err, sql.ErrNoRows) {
		return 0, "", errNotFound
	}
	if err != nil {
		return 0, "", err
	}
	_, err = s.db.ExecContext(ctx, `UPDATE sessions SET expires_at = ? WHERE token_hash = ?`, extendTo.UTC(), tokenHash)
	return id, email, err
}

func (s *Store) DeleteSession(ctx context.Context, tokenHash string) error {
	_, err := s.db.ExecContext(ctx, `DELETE FROM sessions WHERE token_hash = ?`, tokenHash)
	return err
}

func (s *Store) DeleteExpiredSessions(ctx context.Context) error {
	_, err := s.db.ExecContext(ctx, `DELETE FROM sessions WHERE expires_at <= UTC_TIMESTAMP()`)
	return err
}

// ------------------------------------------------------------------- sync

// Push merges the changes of a device into the records of the account.
// Pushes of one account are serialized (lock on the account row).
func (s *Store) Push(ctx context.Context, accountID int64, changes []Change, data [][]byte) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback() //nolint:errcheck // no-op after Commit

	var seq int64
	if err := tx.QueryRowContext(ctx, `SELECT last_seq FROM accounts WHERE id = ? FOR UPDATE`, accountID).Scan(&seq); err != nil {
		return err
	}
	for i, c := range changes {
		existing, err := loadRecord(ctx, tx, accountID, c.Table, c.UID)
		if err != nil {
			return err
		}
		merged, changed := Merge(existing, c, data[i])
		if !changed {
			continue
		}
		seq++
		if err := saveRecord(ctx, tx, accountID, c.Table, c.UID, seq, merged); err != nil {
			return err
		}
	}
	if _, err := tx.ExecContext(ctx, `UPDATE accounts SET last_seq = ? WHERE id = ?`, seq, accountID); err != nil {
		return err
	}
	return tx.Commit()
}

func loadRecord(ctx context.Context, tx *sql.Tx, accountID int64, table, uid string) (*Record, error) {
	var r Record
	var vals, times string
	err := tx.QueryRowContext(ctx, `
		SELECT deleted, modified_at, device_id, vals, col_times, data, data_time FROM records
		WHERE account_id = ? AND tbl = ? AND uid = ? FOR UPDATE`, accountID, table, uid,
	).Scan(&r.Deleted, &r.ModifiedAt, &r.DeviceID, &vals, &times, &r.Data, &r.DataTime)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	if err := json.Unmarshal([]byte(vals), &r.Values); err != nil {
		return nil, err
	}
	if err := json.Unmarshal([]byte(times), &r.ColTimes); err != nil {
		return nil, err
	}
	return &r, nil
}

func saveRecord(ctx context.Context, tx *sql.Tx, accountID int64, table, uid string, seq int64, r Record) error {
	vals, err := json.Marshal(nonNilValues(r.Values))
	if err != nil {
		return err
	}
	times, err := json.Marshal(nonNilTimes(r.ColTimes))
	if err != nil {
		return err
	}
	_, err = tx.ExecContext(ctx, `
		INSERT INTO records (account_id, tbl, uid, seq, deleted, modified_at, device_id, vals, col_times, data, data_time)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		ON DUPLICATE KEY UPDATE seq = VALUES(seq), deleted = VALUES(deleted), modified_at = VALUES(modified_at),
			device_id = VALUES(device_id), vals = VALUES(vals), col_times = VALUES(col_times),
			data = VALUES(data), data_time = VALUES(data_time)`,
		accountID, table, uid, seq, r.Deleted, r.ModifiedAt, r.DeviceID, string(vals), string(times), r.Data, r.DataTime)
	return err
}

// PulledRecord is a record sent to a device.
type PulledRecord struct {
	Seq    int64
	Change Change
}

// Pull returns the records changed after cursor, limited in number and size.
func (s *Store) Pull(ctx context.Context, accountID, cursor int64, maxRows int, maxBytes int) ([]PulledRecord, bool, error) {
	rows, err := s.db.QueryContext(ctx, `
		SELECT seq, tbl, uid, deleted, modified_at, device_id, vals, col_times, data, data_time FROM records
		WHERE account_id = ? AND seq > ? ORDER BY seq LIMIT ?`, accountID, cursor, maxRows+1)
	if err != nil {
		return nil, false, err
	}
	defer rows.Close()
	var out []PulledRecord
	size := 0
	hasMore := false
	for rows.Next() {
		if len(out) == maxRows || (len(out) > 0 && size > maxBytes) {
			hasMore = true
			break
		}
		var p PulledRecord
		var r Record
		var vals, times string
		if err := rows.Scan(&p.Seq, &p.Change.Table, &p.Change.UID, &r.Deleted, &r.ModifiedAt, &r.DeviceID,
			&vals, &times, &r.Data, &r.DataTime); err != nil {
			return nil, false, err
		}
		c := &p.Change
		c.Deleted, c.ModifiedAt, c.DeviceID = r.Deleted, r.ModifiedAt, r.DeviceID
		if !r.Deleted {
			if err := json.Unmarshal([]byte(vals), &c.Values); err != nil {
				return nil, false, err
			}
			if err := json.Unmarshal([]byte(times), &c.ColumnTimes); err != nil {
				return nil, false, err
			}
			for k := range c.Values {
				c.Columns = append(c.Columns, k)
			}
			if r.Data != nil {
				enc := encodeBase64(r.Data)
				c.Data = &enc
				c.ColumnTimes["data"] = r.DataTime
				size += len(enc)
			}
		}
		size += len(vals)
		out = append(out, p)
	}
	return out, hasMore, rows.Err()
}

func nonNilValues(m map[string]any) map[string]any {
	if m == nil {
		return map[string]any{}
	}
	return m
}

func nonNilTimes(m map[string]int64) map[string]int64 {
	if m == nil {
		return map[string]int64{}
	}
	return m
}
