FROM ubuntu:22.04
ENV PROMPT_COMMAND="history -a"
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
  tor nftables curl jq netcat dnsutils iproute2 \
  iputils-ping

COPY --from=ghcr.io/matti/tailer:824002811ee20a0dbb19501e77553b49ebdf5869 /tailer /usr/local/bin
#COPY --from=ghcr.io/bamboo-crypto/bamboo:06b8c90d734407c3948efdd55fe1ef006397bf64 /usr/local/bin/* /usr/local/bin

RUN useradd tor
RUN mkdir -p /home/tor
RUN chown -R tor /home/tor

RUN useradd app

WORKDIR /app
COPY app .
ENTRYPOINT [ "/app/entrypoint.sh" ]
