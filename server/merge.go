package main

// Record is the current state of one synchronized row of an account.
type Record struct {
	Deleted    bool
	ModifiedAt int64
	DeviceID   string
	Values     map[string]any
	// ColTimes holds, for each column, the time of the change that set it.
	ColTimes map[string]int64
	// Data is the content of an attachment file (nil: none).
	Data     []byte
	DataTime int64
}

// Change is a modification sent by a device (see the app: SyncChange).
type Change struct {
	Table      string         `json:"table"`
	UID        string         `json:"uid"`
	Deleted    bool           `json:"deleted,omitempty"`
	Values     map[string]any `json:"values,omitempty"`
	Columns    []string       `json:"columns,omitempty"`
	ModifiedAt int64          `json:"modified_at"`
	DeviceID   string         `json:"device_id"`
	// Data is the base64 content of an attachment file.
	Data *string `json:"data,omitempty"`
	// ColumnTimes is sent to the devices so that they can merge column by column.
	ColumnTimes map[string]int64 `json:"column_times,omitempty"`
}

func maxColTime(r *Record) int64 {
	m := r.ModifiedAt
	for _, t := range r.ColTimes {
		if t > m {
			m = t
		}
	}
	return m
}

// Merge applies a change to the current record (nil: unknown row) and returns
// the new record and whether something changed.
//
// Rules (same as the app):
//   - columns are merged one by one, the most recent change of a column wins;
//   - a deletion wins over older changes, a newer change wins over a deletion;
//   - deletions are kept as tombstones so that every device learns them.
func Merge(existing *Record, c Change, data []byte) (Record, bool) {
	if existing == nil || existing.Deleted {
		if existing != nil && (c.Deleted || c.ModifiedAt <= existing.ModifiedAt) {
			return *existing, false
		}
		if c.Deleted {
			return Record{Deleted: true, ModifiedAt: c.ModifiedAt, DeviceID: c.DeviceID}, true
		}
		r := Record{
			ModifiedAt: c.ModifiedAt,
			DeviceID:   c.DeviceID,
			Values:     map[string]any{},
			ColTimes:   map[string]int64{},
		}
		for k, v := range c.Values {
			r.Values[k] = v
			r.ColTimes[k] = 0 // known value, but not explicitly changed
		}
		for _, col := range c.Columns {
			r.ColTimes[col] = c.ModifiedAt
		}
		if data != nil {
			r.Data, r.DataTime = data, c.ModifiedAt
		}
		return r, true
	}

	r := *existing
	r.Values = copyValues(existing.Values)
	r.ColTimes = copyTimes(existing.ColTimes)
	if c.Deleted {
		if c.ModifiedAt < maxColTime(existing) || c.ModifiedAt < existing.DataTime {
			return *existing, false // edited after the deletion: the edit wins
		}
		return Record{Deleted: true, ModifiedAt: c.ModifiedAt, DeviceID: c.DeviceID}, true
	}
	changed := false
	for _, col := range c.Columns {
		v, ok := c.Values[col]
		if !ok {
			continue
		}
		if c.ModifiedAt >= r.ColTimes[col] {
			if !equalValue(r.Values[col], v) || r.ColTimes[col] != c.ModifiedAt {
				changed = true
			}
			r.Values[col] = v
			r.ColTimes[col] = c.ModifiedAt
		}
	}
	// Columns the server did not know yet (e.g. added by a newer app version).
	for k, v := range c.Values {
		if _, ok := r.Values[k]; !ok {
			r.Values[k] = v
			r.ColTimes[k] = 0
			changed = true
		}
	}
	if data != nil && c.ModifiedAt >= r.DataTime {
		r.Data, r.DataTime = data, c.ModifiedAt
		changed = true
	}
	if changed {
		if c.ModifiedAt > r.ModifiedAt {
			r.ModifiedAt = c.ModifiedAt
		}
		r.DeviceID = c.DeviceID
	}
	return r, changed
}

func copyValues(m map[string]any) map[string]any {
	out := make(map[string]any, len(m))
	for k, v := range m {
		out[k] = v
	}
	return out
}

func copyTimes(m map[string]int64) map[string]int64 {
	out := make(map[string]int64, len(m))
	for k, v := range m {
		out[k] = v
	}
	return out
}

func equalValue(a, b any) bool {
	// Values come from JSON: nil, bool, float64, string.
	return a == b
}
