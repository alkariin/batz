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

# pdftotext reads the statements: the PDF on its standard input, the text on
# its standard output, so that the container can stay read-only.
RUN apk add --no-cache poppler-utils

# Unprivileged user; /data holds the database, the TLS certificate, the
# original statements and the dated copies of the database.
RUN adduser -D -H -u 10001 batz && mkdir /data && chown batz:batz /data
COPY --from=builder /out/batz-web /usr/local/bin/batz-web

ENV BATZ_DATA_DIR=/data \
    BATZ_PORT=8443 \
    BATZ_BACKUPS=12
VOLUME /data
EXPOSE 8443
USER batz

# Calls /healthz over HTTPS, pinned on the certificate in /data.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD ["batz-web", "healthcheck"]

ENTRYPOINT ["batz-web"]
CMD ["serve"]
