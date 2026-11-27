// Package web exposes the HTTP API.
package web

import (
	"errors"
	"log/slog"
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/alkariin/batz/batz-web/internal/application"
	"github.com/alkariin/batz/batz-web/internal/domain/device"
	"github.com/alkariin/batz/batz-web/internal/domain/journal"
	"github.com/alkariin/batz/batz-web/internal/domain/statement"
)

// Error codes the app relies on; messages are for humans and logs.
const (
	CodeBadRequest         = "BAD_REQUEST"
	CodeDeviceNameInvalid  = "DEVICE_NAME_INVALID"
	CodePairingCodeInvalid = "PAIRING_CODE_INVALID"
	CodePairingCodeExpired = "PAIRING_CODE_EXPIRED"
	CodePairingCodeUsed    = "PAIRING_CODE_USED"
	CodeDeviceKeyMissing   = "DEVICE_KEY_MISSING"
	CodeDeviceKeyInvalid   = "DEVICE_KEY_INVALID"
	CodeDeviceRevoked      = "DEVICE_REVOKED"
	CodeDeviceNotFound     = "DEVICE_NOT_FOUND"
	CodeNotFound           = "NOT_FOUND"
	CodeInternal           = "INTERNAL"

	CodeSyncProtocolUnsupported = "SYNC_PROTOCOL_UNSUPPORTED"
	CodeAppVersionUnsupported   = "APP_VERSION_UNSUPPORTED"
	CodeSyncPageTooLarge        = "SYNC_PAGE_TOO_LARGE"
	CodeSyncPageInvalid         = "SYNC_PAGE_INVALID"
	CodeSyncStateChanged        = "SYNC_STATE_CHANGED"

	CodeImportUnreadable    = statement.CodeUnreadable
	CodeImportUnknownFormat = statement.CodeUnknownFormat
	CodeImportInconsistent  = statement.CodeInconsistent
	CodeImportTooLarge      = "IMPORT_TOO_LARGE"
	CodeImportPDFNotFound   = "IMPORT_PDF_NOT_FOUND"

	CodeDocumentTooLarge = "DOCUMENT_TOO_LARGE"
	CodeDocumentEmpty    = "DOCUMENT_EMPTY"
	CodeDocumentNotFound = "DOCUMENT_NOT_FOUND"
)

// ErrorBody is the JSON body of every error response. Check names the
// failed check of a refused statement.
type ErrorBody struct {
	Code    string `json:"code"`
	Check   string `json:"check,omitempty"`
	Message string `json:"message"`
}

func abort(c *gin.Context, status int, code, message string) {
	c.AbortWithStatusJSON(status, ErrorBody{Code: code, Message: message})
}

// fail maps a domain error to its response; anything else is a 500.
func fail(c *gin.Context, err error) {
	switch {
	case errors.Is(err, device.ErrInvalidName):
		abort(c, http.StatusBadRequest, CodeDeviceNameInvalid, err.Error())
	case errors.Is(err, device.ErrPairingCodeInvalid):
		abort(c, http.StatusUnauthorized, CodePairingCodeInvalid, err.Error())
	case errors.Is(err, device.ErrPairingCodeExpired):
		abort(c, http.StatusUnauthorized, CodePairingCodeExpired, err.Error())
	case errors.Is(err, device.ErrPairingCodeUsed):
		abort(c, http.StatusUnauthorized, CodePairingCodeUsed, err.Error())
	case errors.Is(err, device.ErrUnknownKey):
		abort(c, http.StatusUnauthorized, CodeDeviceKeyInvalid, err.Error())
	case errors.Is(err, device.ErrRevoked):
		abort(c, http.StatusUnauthorized, CodeDeviceRevoked, err.Error())
	case errors.Is(err, device.ErrNotFound):
		abort(c, http.StatusNotFound, CodeDeviceNotFound, err.Error())
	case errors.Is(err, application.ErrProtocolUnsupported):
		abort(c, http.StatusBadRequest, CodeSyncProtocolUnsupported, err.Error())
	case errors.Is(err, application.ErrAppTooOld):
		abort(c, http.StatusUpgradeRequired, CodeAppVersionUnsupported, err.Error())
	case errors.Is(err, application.ErrPageTooLarge):
		abort(c, http.StatusRequestEntityTooLarge, CodeSyncPageTooLarge, err.Error())
	case errors.Is(err, journal.ErrInvalid):
		abort(c, http.StatusBadRequest, CodeSyncPageInvalid, err.Error())
	case errors.Is(err, application.ErrStateChanged):
		abort(c, http.StatusConflict, CodeSyncStateChanged, err.Error())
	case errors.Is(err, application.ErrPDFNotFound):
		abort(c, http.StatusNotFound, CodeImportPDFNotFound, err.Error())
	case errors.Is(err, application.ErrDocumentNotFound):
		abort(c, http.StatusNotFound, CodeDocumentNotFound, err.Error())
	case errors.Is(err, application.ErrDocumentEmpty):
		abort(c, http.StatusBadRequest, CodeDocumentEmpty, err.Error())
	default:
		slog.Error("request failed", "method", c.Request.Method, "path", c.FullPath(), "error", err)
		abort(c, http.StatusInternalServerError, CodeInternal, "internal error")
	}
}
