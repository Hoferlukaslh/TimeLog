package main

import "testing"

func change(at int64, values map[string]any, cols ...string) Change {
	return Change{Table: "time_entries", UID: "day:2026-11-09", Values: values, Columns: cols, ModifiedAt: at, DeviceID: "d"}
}

func TestMergeColumnsFromTwoDevices(t *testing.T) {
	r, _ := Merge(nil, change(100, map[string]any{"date": "2026-11-09", "arrival": 480.0, "departure": nil}, "date", "arrival"), nil)
	r, changed := Merge(&r, change(90, map[string]any{"date": "2026-11-09", "arrival": nil, "departure": 1020.0}, "date", "departure"), nil)
	if !changed || r.Values["arrival"] != 480.0 || r.Values["departure"] != 1020.0 {
		t.Fatalf("merge lost a column: %+v", r.Values)
	}
}

func TestMergeLatestWinsOnSameColumn(t *testing.T) {
	r, _ := Merge(nil, change(100, map[string]any{"arrival": 480.0}, "arrival"), nil)
	r, _ = Merge(&r, change(300, map[string]any{"arrival": 490.0}, "arrival"), nil)
	r, changed := Merge(&r, change(200, map[string]any{"arrival": 485.0}, "arrival"), nil)
	if changed || r.Values["arrival"] != 490.0 {
		t.Fatalf("older change overwrote a newer one: %+v", r.Values)
	}
}

func TestMergeDeletion(t *testing.T) {
	r, _ := Merge(nil, change(100, map[string]any{"title": "a"}, "title"), nil)
	// Deletion older than the last edit: ignored.
	if r2, changed := Merge(&r, Change{Deleted: true, ModifiedAt: 50}, nil); changed || r2.Deleted {
		t.Fatal("old deletion applied")
	}
	r, _ = Merge(&r, Change{Deleted: true, ModifiedAt: 200}, nil)
	if !r.Deleted {
		t.Fatal("deletion not applied")
	}
	// Edit older than the deletion: ignored; newer: the row comes back.
	if _, changed := Merge(&r, change(150, map[string]any{"title": "b"}, "title"), nil); changed {
		t.Fatal("old edit resurrected the row")
	}
	r, _ = Merge(&r, change(250, map[string]any{"title": "c"}, "title"), nil)
	if r.Deleted || r.Values["title"] != "c" {
		t.Fatal("newer edit did not win over the deletion")
	}
}

func TestMergeAttachmentData(t *testing.T) {
	r, _ := Merge(nil, change(100, map[string]any{"file_name": "a.pdf"}, "file_name"), []byte{1, 2})
	r, _ = Merge(&r, change(50, map[string]any{}), []byte{9})
	if len(r.Data) != 2 {
		t.Fatal("older file content overwrote a newer one")
	}
	r, _ = Merge(&r, change(150, map[string]any{}), []byte{3})
	if len(r.Data) != 1 || r.Data[0] != 3 {
		t.Fatal("newer file content not applied")
	}
}
