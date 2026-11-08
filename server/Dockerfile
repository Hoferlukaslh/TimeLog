# Build
FROM golang:1.26-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY *.go ./
RUN go test ./... && CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /timelog-server .

# Run: minimal image, non-root user
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /timelog-server /timelog-server
EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/timelog-server"]
