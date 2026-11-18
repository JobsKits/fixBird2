package workbench

import (
	"sort"
	"unicode"
)

func passwordRuneInRanges(value rune, ranges [][2]rune) bool {
	index := sort.Search(len(ranges), func(i int) bool {
		return ranges[i][1] >= value
	})
	return index < len(ranges) && ranges[index][0] <= value
}

func passwordContainsEmoji(value string) bool {
	previousEmojiBase := false
	for _, scalar := range value {
		if scalar == 0xFE0F || scalar == 0x20E3 || passwordRuneInRanges(scalar, passwordEmojiPresentationRanges) {
			return true
		}
		if scalar == 0x200D || scalar >= 0xE0020 && scalar <= 0xE007F {
			if previousEmojiBase {
				return true
			}
			continue
		}
		// ASCII digits, # and * have Emoji=Yes for keycaps, but remain valid text passwords.
		if scalar > 0x7F && passwordRuneInRanges(scalar, passwordEmojiRanges) {
			previousEmojiBase = true
			if scalar != 0x00A9 && scalar != 0x00AE && scalar != 0x2122 {
				return true
			}
			continue
		}
		// Ordinary text ends the local symbol sequence; combining marks and ZWNJ extend it.
		if !unicode.Is(unicode.M, scalar) && scalar != 0x200C {
			previousEmojiBase = false
		}
	}
	return false
}

func validatePasswordEmoji(values ...string) error {
	for _, value := range values {
		if passwordContainsEmoji(value) {
			return fail(422, "invalid_password", "密码不能包含表情符号")
		}
	}
	return nil
}
