package migration

import (
	"fmt"
	"strings"
)

// SplitSQL respects quoted literals and comments. Stored routines/DELIMITER are unsupported.
func SplitSQL(input string) ([]string, error) {
	var statements []string
	var current strings.Builder
	var quote byte
	lineComment, blockComment := false, false
	for i := 0; i < len(input); i++ {
		value := input[i]
		next := byte(0)
		if i+1 < len(input) {
			next = input[i+1]
		}
		if lineComment {
			if value == '\n' {
				lineComment = false
				current.WriteByte('\n')
			}
			continue
		}
		if blockComment {
			if value == '*' && next == '/' {
				blockComment = false
				i++
				current.WriteByte(' ')
			}
			continue
		}
		if quote != 0 {
			current.WriteByte(value)
			if value == '\\' && next != 0 {
				i++
				current.WriteByte(next)
				continue
			}
			if value == quote {
				if next == quote {
					i++
					current.WriteByte(next)
				} else {
					quote = 0
				}
			}
			continue
		}
		if value == '#' || (value == '-' && next == '-' && (i+2 == len(input) || input[i+2] <= ' ')) {
			lineComment = true
			current.WriteByte(' ')
			continue
		}
		if value == '/' && next == '*' {
			if i+2 < len(input) && input[i+2] == '!' {
				return nil, fmt.Errorf("executable SQL comments are unsupported")
			}
			blockComment = true
			i++
			current.WriteByte(' ')
			continue
		}
		if value == '\'' || value == '"' || value == '`' {
			quote = value
			current.WriteByte(value)
			continue
		}
		if value == ';' {
			statement := strings.TrimSpace(current.String())
			if statement != "" {
				statements = append(statements, statement)
			}
			current.Reset()
			continue
		}
		current.WriteByte(value)
	}
	if quote != 0 || blockComment {
		return nil, fmt.Errorf("unterminated SQL quote or comment")
	}
	if value := strings.TrimSpace(current.String()); value != "" {
		statements = append(statements, value)
	}
	for _, statement := range statements {
		if strings.HasPrefix(strings.ToUpper(statement), "DELIMITER") {
			return nil, fmt.Errorf("DELIMITER is unsupported")
		}
	}
	return statements, nil
}
