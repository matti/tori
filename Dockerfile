FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
  tor

WORKDIR /app
COPY app .
ENTRYPOINT [ "/app/entrypoint.sh" ]
