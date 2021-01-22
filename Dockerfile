ARG VERSION=1.0.0

FROM golang:1-alpine AS builder

RUN apk update && apk add --no-cache wget git

ARG VERSION

RUN wget -O - "https://api.github.com/repos/prologic/tube/releases/latest" \
    | grep "tarball_url" | cut -d\" -f4 \
    | wget -O /tmp/tube.tar.gz -i -

WORKDIR /tmp/tube
ENV CGO_ENABLED=0

RUN go get -v github.com/GeertJohan/go.rice/rice
RUN tar -zxvf /tmp/tube.tar.gz --strip-components=1 -C . \
    && go generate $(go list)/... \
    && go build -o tube -trimpath -tags "netgo static_build" -installsuffix netgo -ldflags "-s -w -buildid=" .

FROM golang:1-alpine AS lib-builder

ENV CGO_ENABLED=1
RUN apk update && apk add --no-cache ffmpeg ffmpeg-dev build-base wget git
RUN go get -v github.com/mutschler/mt

FROM alpine

RUN apk update && apk add --no-cache ffmpeg ffmpeg-dev

ENV GOPATH=/go
WORKDIR /go/src/github.com/prologic/tube

COPY --from=lib-builder /go/bin/mt /usr/local/bin/
COPY --from=builder /tmp/tube/tube /usr/local/bin/
COPY --from=builder /tmp/tube/static ./static
COPY --from=builder /tmp/tube/templates ./templates

WORKDIR /data/uploads
WORKDIR /data/videos
WORKDIR /data

COPY config.json /etc/tube/config.json

RUN rm -rf /var/cache/apk/*

CMD ["/usr/local/bin/tube", "-c", "/etc/tube/config.json"]
