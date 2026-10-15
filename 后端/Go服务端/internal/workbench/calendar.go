package workbench

import "time"

// Business months use the Chinese calendar date, clamping a missing day to month end.
func warrantyEnd(effective time.Time, months int) (time.Time, error) {
	if months < 1 || months > 60 {
		return time.Time{}, fail(422, "invalid_warranty", "质保须为1至60个完整日历月")
	}
	local := effective.In(chinaLocation())
	first := time.Date(local.Year(), local.Month()+time.Month(months), 1, local.Hour(), local.Minute(), local.Second(), local.Nanosecond(), chinaLocation())
	if first.Year() < 1 || first.Year() > 9999 {
		return time.Time{}, fail(422, "invalid_warranty", "质保日期超出可记录范围")
	}
	lastDay := time.Date(first.Year(), first.Month()+1, 0, 0, 0, 0, 0, chinaLocation()).Day()
	day := local.Day()
	if day > lastDay {
		day = lastDay
	}
	return time.Date(first.Year(), first.Month(), day, local.Hour(), local.Minute(), local.Second(), local.Nanosecond(), chinaLocation()), nil
}

// EndsAt remains the agreed historical date; coverage includes that entire day.
func warrantyActive(endsAt string, now time.Time) bool {
	end, err := time.Parse(time.RFC3339, endsAt)
	if err != nil {
		return false
	}
	local := end.In(chinaLocation())
	expires := time.Date(local.Year(), local.Month(), local.Day()+1, 0, 0, 0, 0, chinaLocation())
	return now.Before(expires)
}
