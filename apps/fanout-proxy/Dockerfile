FROM golang:1.26 AS build
WORKDIR /app
COPY go.mod ./
COPY main.go ./
RUN CGO_ENABLED=0 go build -o /fanout .

FROM gcr.io/distroless/static-debian13
COPY --from=build /fanout /fanout
EXPOSE 8080
ENTRYPOINT ["/fanout"]
