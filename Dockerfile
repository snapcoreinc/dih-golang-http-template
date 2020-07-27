

FROM registry.gitlab.com/snapcoreinc/snapcore-monitor:latest as kickstart
FROM golang:1.14-alpine3.12 as builder

# Required to enable Go modules
RUN apk add --no-cache git

# Allows you to add additional packages via build-arg
ARG ADDITIONAL_PACKAGE
ARG CGO_ENABLED=0
ARG GO111MODULE="on"
ARG GOPROXY=""
ARG GOFLAGS=""

ENV CGO_ENABLED=0

WORKDIR /go/src/handler
COPY --from=kickstart /gomodmerge .

COPY go.mod ./
COPY module/go.mod module/

# Add user overrides to the root go.mod, which is the only place "replace" can be used
RUN ./gomodmerge go.mod module/go.mod && cat go.mod.new
RUN cp go.mod.new go.mod && go mod download

COPY . .

# Run a gofmt and exclude all vendored code.
RUN test -z "$(gofmt -l $(find . -type f -name '*.go' -not -path "./vendor/*" -not -path "./module/vendor/*"))" || { echo "Run \"gofmt -s -w\" on your Golang code"; exit 1; }

WORKDIR /go/src/handler/module
RUN CGO_ENABLED=${CGO_ENABLED} go test ./... -cover

WORKDIR /go/src/handler

RUN mv go.mod.new go.mod && rm module/go.mod

RUN CGO_ENABLED=${CGO_ENABLED} GOOS=linux \
    go build --ldflags "-s -w" -a -installsuffix cgo -o handler .

RUN addgroup -S app \
    && adduser -S -g app app \
    && apk add --no-cache ca-certificates \
    && mkdir /scratch-tmp

FROM scratch

WORKDIR /

COPY --from=builder /go/src/handler/handler  .
COPY --from=builder /etc/passwd /etc/group /etc/
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder --chown=app:app /scratch-tmp /tmp
COPY --from=kickstart /tini .
COPY --from=kickstart /dih-monitor /dih-monitor

USER app

ENV startup_process="/handler" \
    mode="http" \
    proxy_url="http://127.0.0.1:8082" \
    http_proxy="" \
    https_proxy=""

EXPOSE 8080

ENTRYPOINT ["/tini", "--"]
CMD ["/dih-monitor"]






# FROM openfaas/of-watchdog:0.7.7 as watchdog
# FROM golang:1.13-alpine3.11 as build

# RUN apk --no-cache add git

# ENV CGO_ENABLED=0

# COPY --from=watchdog /fwatchdog /usr/bin/fwatchdog
# RUN chmod +x /usr/bin/fwatchdog

# ENV CGO_ENABLED=0

# RUN mkdir -p /go/src/handler
# WORKDIR /go/src/handler
# COPY . .

# # Run a gofmt and exclude all vendored code.
# RUN test -z "$(gofmt -l $(find . -type f -name '*.go' -not -path "./vendor/*" -not -path "./function/vendor/*"))" || { echo "Run \"gofmt -s -w\" on your Golang code"; exit 1; }

# ARG GO111MODULE="off"
# ARG GOPROXY=""

# RUN go build --ldflags "-s -w" -a -installsuffix cgo -o handler .
# RUN go test handler/function/... -cover

# FROM alpine:3.11
# # Add non root user and certs
# RUN apk --no-cache add ca-certificates \
#     && addgroup -S app && adduser -S -g app app \
#     && mkdir -p /home/app \
#     && chown app /home/app

# WORKDIR /home/app

# COPY --from=build /go/src/handler/handler    .
# COPY --from=build /usr/bin/fwatchdog         .
# COPY --from=build /go/src/handler/function/  .

# RUN chown -R app /home/app

# USER app

# ENV fprocess="./handler"
# ENV mode="http"
# ENV upstream_url="http://127.0.0.1:8082"

# CMD ["./fwatchdog"]
