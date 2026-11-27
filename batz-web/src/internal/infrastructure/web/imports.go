package web

import (
	"bytes"
	"errors"
	"io"
	"log/slog"
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/alkariin/batz/batz-web/internal/application"
	"github.com/alkariin/batz/batz-web/internal/domain/statement"
)

type importHandler struct{ imports *application.Imports }

type importResponse struct {
	Fingerprint string              `json:"fingerprint"`
	Statement   statement.Statement `json:"statement"`
}

// importStatement receives a statement file as the raw request body and
// answers with the statement read and its fingerprint, or the reason of the
// refusal. The logs never hold any text of the statement.
func (h *importHandler) importStatement(c *gin.Context) {
	from := currentDevice(c)
	pdf, err := io.ReadAll(c.Request.Body)
	if err != nil {
		var tooLarge *http.MaxBytesError
		if errors.As(err, &tooLarge) {
			slog.Warn("import refused", "device", from.ID, "code", CodeImportTooLarge)
			abort(c, http.StatusRequestEntityTooLarge, CodeImportTooLarge, "statement file over 10 MiB")
			return
		}
		abort(c, http.StatusBadRequest, CodeBadRequest, "the statement file could not be read")
		return
	}
	res, err := h.imports.Import(c.Request.Context(), pdf)
	if err != nil {
		code, check, refused := statement.Refusal(err)
		if !refused {
			fail(c, err)
			return
		}
		slog.Warn("import refused", "device", from.ID, "bytes", len(pdf), "code", code, "check", check)
		c.AbortWithStatusJSON(http.StatusUnprocessableEntity, ErrorBody{Code: code, Check: check, Message: err.Error()})
		return
	}
	slog.Info("import", "device", from.ID, "fingerprint", res.Fingerprint[:12], "format", res.Statement.Format,
		"lines", len(res.Statement.Lines), "new", res.New)
	c.JSON(http.StatusOK, importResponse{Fingerprint: res.Fingerprint, Statement: res.Statement})
}

// pdf returns the original file of a statement: a PDF, or the CSV of an
// export (the route keeps its name).
func (h *importHandler) pdf(c *gin.Context) {
	fingerprint := c.Param("fingerprint")
	file, err := h.imports.PDF(c.Request.Context(), fingerprint)
	if err != nil {
		fail(c, err)
		return
	}
	extension, contentType := ".csv", "text/csv; charset=utf-8"
	if bytes.HasPrefix(file, []byte("%PDF-")) {
		extension, contentType = ".pdf", "application/pdf"
	}
	c.Header("Content-Disposition", `attachment; filename="`+fingerprint+extension+`"`)
	c.Data(http.StatusOK, contentType, file)
}
