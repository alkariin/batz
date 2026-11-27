package web

import (
	"errors"
	"io"
	"log/slog"
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/alkariin/batz/batz-web/internal/application"
)

// MaxDocumentBytes caps a document: a scanned contract of a few pages.
const MaxDocumentBytes = 25 << 20

type documentHandler struct{ documents *application.Documents }

type documentResponse struct {
	Fingerprint string `json:"fingerprint"`
	Size        int    `json:"size"`
}

// store receives a document as the raw request body and answers with its
// fingerprint. The logs hold its size, never its content.
func (h *documentHandler) store(c *gin.Context) {
	from := currentDevice(c)
	file, err := io.ReadAll(c.Request.Body)
	if err != nil {
		var tooLarge *http.MaxBytesError
		if errors.As(err, &tooLarge) {
			abort(c, http.StatusRequestEntityTooLarge, CodeDocumentTooLarge, "document over 25 MiB")
			return
		}
		abort(c, http.StatusBadRequest, CodeBadRequest, "the document could not be read")
		return
	}
	fingerprint, isNew, err := h.documents.Store(c.Request.Context(), file)
	if err != nil {
		fail(c, err)
		return
	}
	slog.Info("document", "device", from.ID, "fingerprint", fingerprint[:12], "bytes", len(file), "new", isNew)
	status := http.StatusOK
	if isNew {
		status = http.StatusCreated
	}
	c.JSON(status, documentResponse{Fingerprint: fingerprint, Size: len(file)})
}

// read returns a document, as bytes: the app knows its type.
func (h *documentHandler) read(c *gin.Context) {
	file, err := h.documents.Read(c.Request.Context(), c.Param("fingerprint"))
	if err != nil {
		fail(c, err)
		return
	}
	c.Data(http.StatusOK, "application/octet-stream", file)
}
