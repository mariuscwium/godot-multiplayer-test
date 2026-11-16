FROM debian:12-slim
ARG GODOT=4.7.2-stable
ARG TARGETARCH
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl unzip \
 && rm -rf /var/lib/apt/lists/* \
 && A=$([ "$TARGETARCH" = "arm64" ] && echo arm64 || echo x86_64) \
 && curl -fsSL "https://github.com/godotengine/godot-builds/releases/download/${GODOT}/Godot_v${GODOT}_linux.${A}.zip" -o /tmp/g.zip \
 && unzip -q /tmp/g.zip -d /tmp && mv /tmp/Godot_v${GODOT}_linux.${A} /usr/local/bin/godot && rm /tmp/g.zip
WORKDIR /app
COPY project.godot main.tscn main.gd ./
COPY scripts ./scripts
COPY maps ./maps
# register the class_name scripts (Net, Server, ...) before the first run
RUN godot --headless --path /app --import || true
EXPOSE 7777/udp 7777/tcp
# Default: WebSocket (browsers via a Cloudflare tunnel). Native UDP: -e SERVER_ARGS=""
ENV SERVER_ARGS="--ws"
CMD ["sh", "-c", "exec godot --headless --path /app -- --server $SERVER_ARGS"]
