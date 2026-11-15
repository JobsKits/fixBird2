package workbench

import (
	"encoding/base64"
	"fmt"
	"time"
)

// Old snapshots omit these optional aggregates; present records must retain their owner.
func validatePersonalState(state State) error {
	accounts := map[string]bool{}
	for _, account := range state.Accounts {
		accounts[account.Actor.ID] = true
	}
	logs, mediaIDs, reminders := map[string]bool{}, map[string]bool{}, map[string]bool{}
	for _, log := range state.WorkLogs {
		key := log.OwnerID + ":" + log.Date
		if !accounts[log.OwnerID] || !validJournalDate(log.Date) || logs[key] || log.Version < 1 || !validPersonalText(log.Text, 0, journalTextMax) || len(log.Media) > journalFileMax {
			return fmt.Errorf("invalid private work log")
		}
		if _, err := time.Parse(time.RFC3339Nano, log.UpdatedAt); err != nil {
			return fmt.Errorf("invalid work log update time")
		}
		logs[key] = true
		if log.Deleted && (log.Text != "" || len(log.Media) != 0) {
			return fmt.Errorf("deleted work log retained private content")
		}
		total := 0
		for _, media := range log.Media {
			if media.ID == "" || mediaIDs[media.ID] || media.Size < 1 || media.Size > journalTotalMax || len(media.DataBase64) > base64.StdEncoding.EncodedLen(journalTotalMax) {
				return fmt.Errorf("invalid private journal media")
			}
			data, err := base64.StdEncoding.Strict().DecodeString(media.DataBase64)
			if err != nil || len(data) != media.Size || validJournalMedia(media.Name, media.MIME, data) != nil {
				return fmt.Errorf("invalid private journal media payload")
			}
			mediaIDs[media.ID] = true
			total += media.Size
		}
		if total > journalTotalMax {
			return fmt.Errorf("journal media quota exceeded")
		}
	}
	for _, reminder := range state.Reminders {
		if !accounts[reminder.OwnerID] || reminder.ID == "" || reminders[reminder.ID] || reminder.Version < 1 || !validPersonalText(reminder.Title, 1, 200) || !validPersonalText(reminder.Body, 0, 2000) {
			return fmt.Errorf("invalid private reminder")
		}
		if _, err := personalLocation(reminder.TimeZone); err != nil {
			return err
		}
		for _, stamp := range []string{reminder.DueAt, reminder.CreatedAt, reminder.UpdatedAt} {
			if _, err := time.Parse(time.RFC3339Nano, stamp); err != nil {
				return fmt.Errorf("invalid reminder timestamp")
			}
		}
		if reminder.Status != "pending" && reminder.Status != "notified" && reminder.Status != "done" {
			return fmt.Errorf("invalid reminder status")
		}
		if reminder.Status == "notified" && reminder.NotifiedAt == "" || reminder.Status == "pending" && reminder.NotifiedAt != "" {
			return fmt.Errorf("invalid reminder notification state")
		}
		if reminder.NotifiedAt != "" {
			if _, err := time.Parse(time.RFC3339Nano, reminder.NotifiedAt); err != nil {
				return fmt.Errorf("invalid reminder notification time")
			}
		}
		reminders[reminder.ID] = true
	}
	return nil
}
