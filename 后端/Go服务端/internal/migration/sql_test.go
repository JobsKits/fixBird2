package migration

import (
	"testing"
	"testing/fstest"
)

func TestSQLSplittingAndVersions(t *testing.T) {
	statements, err := SplitSQL("-- header;\nINSERT INTO x VALUES ('a;b', 'it''s;ok'); /* separator; */ SELECT `semi;column` FROM x; # eof;")
	if err != nil || len(statements) != 2 {
		t.Fatalf("split=%v err=%v", statements, err)
	}
	for _, input := range []string{"SELECT 'unterminated", "/* unterminated", "DELIMITER $$", "/*! executable */ SELECT 1;"} {
		if _, err := SplitSQL(input); err == nil {
			t.Fatal("unsupported SQL accepted", input)
		}
	}
	files := fstest.MapFS{"002_second.sql": {Data: []byte("SELECT 2;")}, "001_first.sql": {Data: []byte("SELECT 1;")}, "demo.sql": {Data: []byte("SELECT 9;")}}
	steps, err := Load(files)
	if err != nil || len(steps) != 2 || steps[0].Version != "001_first.sql" || len(steps[0].Checksum) != 64 {
		t.Fatalf("steps=%v err=%v", steps, err)
	}
	before := steps[0].Checksum
	files["001_first.sql"] = &fstest.MapFile{Data: []byte("SELECT 3;")}
	steps, err = Load(files)
	if err != nil || steps[0].Checksum == before {
		t.Fatal("content change did not alter checksum")
	}
	files["001_duplicate.sql"] = &fstest.MapFile{Data: []byte("SELECT 4;")}
	if _, err := Load(files); err == nil {
		t.Fatal("duplicate version accepted")
	}
}
