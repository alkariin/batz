package web

import (
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"

	"github.com/alkariin/batz/batz-web/internal/application"
	"github.com/alkariin/batz/batz-web/internal/domain/device"
)

// maxBodyBytes caps JSON request bodies.
const maxBodyBytes = 1 << 20

// Health is what GET /healthz reports.
type Health struct {
	Version       string
	MinAppVersion string
}

// NewRouter wires the routes.
func NewRouter(devices *application.Devices, health Health) *gin.Engine {
	gin.SetMode(gin.ReleaseMode)
	r := gin.New()
	r.Use(gin.Recovery(), limitBody)
	r.NoRoute(func(c *gin.Context) { abort(c, http.StatusNotFound, CodeNotFound, "no such route") })

	r.GET("/healthz", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":        "ok",
			"version":       health.Version,
			"minAppVersion": health.MinAppVersion,
		})
	})

	h := &deviceHandler{devices: devices}
	api := r.Group("/api/v1")
	api.POST("/pairing", h.pair)

	authed := api.Group("", authenticate(devices))
	authed.GET("/devices", h.list)
	authed.DELETE("/devices/:id", h.revoke)
	return r
}

func limitBody(c *gin.Context) {
	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, maxBodyBytes)
	c.Next()
}

const deviceKey = "device"

// authenticate requires "Authorization: Bearer <device key>" from a device
// that is not revoked.
func authenticate(devices *application.Devices) gin.HandlerFunc {
	return func(c *gin.Context) {
		key, ok := strings.CutPrefix(c.GetHeader("Authorization"), "Bearer ")
		if !ok || strings.TrimSpace(key) == "" {
			abort(c, http.StatusUnauthorized, CodeDeviceKeyMissing, "device key is missing")
			return
		}
		d, err := devices.Authenticate(c.Request.Context(), strings.TrimSpace(key))
		if err != nil {
			fail(c, err)
			return
		}
		c.Set(deviceKey, d)
		c.Next()
	}
}

func currentDevice(c *gin.Context) device.Device {
	return c.MustGet(deviceKey).(device.Device)
}

type deviceHandler struct{ devices *application.Devices }

type pairRequest struct {
	Code string `json:"code"`
	Name string `json:"name"`
}

type pairResponse struct {
	DeviceID  string `json:"deviceId"`
	DeviceKey string `json:"deviceKey"`
}

func (h *deviceHandler) pair(c *gin.Context) {
	var req pairRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		abort(c, http.StatusBadRequest, CodeBadRequest, "body must be {\"code\": string, \"name\": string}")
		return
	}
	paired, err := h.devices.Pair(c.Request.Context(), req.Code, req.Name)
	if err != nil {
		fail(c, err)
		return
	}
	c.JSON(http.StatusCreated, pairResponse{DeviceID: paired.DeviceID, DeviceKey: paired.Key})
}

type deviceJSON struct {
	ID         string     `json:"id"`
	Name       string     `json:"name"`
	CreatedAt  time.Time  `json:"createdAt"`
	LastSeenAt *time.Time `json:"lastSeenAt"`
	RevokedAt  *time.Time `json:"revokedAt"`
	Current    bool       `json:"current"`
}

func (h *deviceHandler) list(c *gin.Context) {
	devices, err := h.devices.List(c.Request.Context())
	if err != nil {
		fail(c, err)
		return
	}
	me := currentDevice(c)
	out := make([]deviceJSON, 0, len(devices))
	for _, d := range devices {
		out = append(out, deviceJSON{
			ID: d.ID, Name: d.Name, CreatedAt: d.CreatedAt,
			LastSeenAt: d.LastSeenAt, RevokedAt: d.RevokedAt, Current: d.ID == me.ID,
		})
	}
	c.JSON(http.StatusOK, gin.H{"devices": out})
}

// revoke revokes any device, the caller included: that is how an app unpairs.
func (h *deviceHandler) revoke(c *gin.Context) {
	if err := h.devices.Revoke(c.Request.Context(), c.Param("id")); err != nil {
		fail(c, err)
		return
	}
	c.Status(http.StatusNoContent)
}
