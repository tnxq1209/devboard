# syntax=docker/dockerfile:1.7

# Stage 1: Build the Go application
FROM golang:1.27-alpine AS builder

WORKDIR /app

# Cache dependencies separately from application source
COPY go.mod go.sum ./

RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

# Copy source after dependencies for better layer caching
COPY . .

# Compile a static Linux binary
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=linux \
    go build -trimpath -ldflags="-s -w" \
    -o /out/devboard-backend .

# Stage 2: Minimal non-root runtime
FROM gcr.io/distroless/static-debian12:nonroot

WORKDIR /app

COPY --from=builder --chown=nonroot:nonroot \
    /out/devboard-backend ./devboard-backend

EXPOSE 8080

ENTRYPOINT ["/app/devboard-backend"]
