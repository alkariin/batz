package web

import (
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"

	"github.com/alkariin/batz/batz-web/internal/application"
	"github.com/alkariin/batz/batz-web/internal/domain/journal"
)

type syncHandler struct{ sync *application.Sync }

// entryJSON is an entry on the wire. value is the JSON text of the value:
// the server stores and returns it exactly as received.
type entryJSON struct {
	HLC      string `json:"hlc"`
	Entity   string `json:"entity"`
	RecordID string `json:"recordId"`
	Field    string `json:"field"`
	Value    string `json:"value"`
}

type syncRequest struct {
	Protocol   int               `json:"protocol"`
	AppVersion string            `json:"appVersion"`
	Known      map[string]string `json:"known"`
	Since      map[string]string `json:"since"`
	Entries    []entryJSON       `json:"entries"`
	Limit      int               `json:"limit"`
}

type syncResponse struct {
	Protocol   int               `json:"protocol"`
	ServerTime time.Time         `json:"serverTime"`
	Known      map[string]string `json:"known"`
	Since      map[string]string `json:"since"`
	Entries    []entryJSON       `json:"entries"`
	More       bool              `json:"more"`
	Added      int               `json:"added"`
}

func (h *syncHandler) exchange(c *gin.Context) {
	var req syncRequest
	dec := json.NewDecoder(c.Request.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(&req); err != nil {
		var tooLarge *http.MaxBytesError
		if errors.As(err, &tooLarge) {
			abort(c, http.StatusRequestEntityTooLarge, CodeSyncPageTooLarge, "request body too large")
			return
		}
		abort(c, http.StatusBadRequest, CodeBadRequest, "body must be a JSON exchange request: "+err.Error())
		return
	}
	entries := make([]journal.Entry, len(req.Entries))
	for i, e := range req.Entries {
		entries[i] = journal.Entry{HLC: e.HLC, Entity: e.Entity, RecordID: e.RecordID, Field: e.Field, Value: e.Value}
	}
	from := currentDevice(c)
	res, err := h.sync.Exchange(c.Request.Context(), from, application.SyncRequest{
		Protocol:   req.Protocol,
		AppVersion: req.AppVersion,
		Known:      req.Known,
		Since:      req.Since,
		Entries:    entries,
		Limit:      req.Limit,
	})
	if err != nil {
		if !errors.Is(err, application.ErrStateChanged) {
			slog.Warn("exchange refused", "device", from.ID, "entries", len(entries), "error", err)
		}
		fail(c, err)
		return
	}
	out := make([]entryJSON, len(res.Entries))
	for i, e := range res.Entries {
		out[i] = entryJSON{HLC: e.HLC, Entity: e.Entity, RecordID: e.RecordID, Field: e.Field, Value: e.Value}
	}
	slog.Info("exchange", "device", from.ID, "received", len(entries), "added", res.Added,
		"sent", len(out), "more", res.More)
	c.JSON(http.StatusOK, syncResponse{
		Protocol:   journal.Protocol,
		ServerTime: res.ServerTime,
		Known:      res.Known,
		Since:      res.Since,
		Entries:    out,
		More:       res.More,
		Added:      res.Added,
	})
}
