FROM golang:1.27-alpine AS builder

WORKDIR /src
COPY src/go.mod src/go.sum ./
RUN go mod download

COPY src/ ./
# VERSION is what /healthz reports; the release workflow passes the git tag.
ARG VERSION=dev
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath \
    -ldflags "-s -w -X github.com/alkariin/batz/batz-web/internal/version.Version=${VERSION}" \
    -o /out/batz-web .

FROM alpine:3.24

# Unprivileged user; /data holds the database and the TLS certificate.
RUN adduser -D -H -u 10001 batz && mkdir /data && chown batz:batz /data
COPY --from=builder /out/batz-web /usr/local/bin/batz-web

ENV BATZ_DATA_DIR=/data \
    BATZ_PORT=8443
VOLUME /data
EXPOSE 8443
USER batz

# Calls /healthz over HTTPS, pinned on the certificate in /data.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD ["batz-web", "healthcheck"]

ENTRYPOINT ["batz-web"]
CMD ["serve"]
