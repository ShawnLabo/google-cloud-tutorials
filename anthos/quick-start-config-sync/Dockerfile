FROM golang:1.16.5-buster

ENV PORT 9090

COPY tutorial.md /app/tutorial.md

RUN go get github.com/googlecodelabs/tools/claat \
    && cd /app \
    && claat export tutorial.md

WORKDIR /app/quick-start-config-sync

CMD ["bash", "-c", "claat serve -addr 0.0.0.0:$PORT"]