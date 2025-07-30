FROM debian:bullseye-slim

# نصب ابزارها + Lua 5.4 و کتابخانه‌های dev
RUN apt-get update && apt-get install -y \
    lua5.4 \
    lua5.4-dev \
    luarocks \
    gcc \
    g++ \
    make \
    cmake \
    git \
    libc-dev \
    libssl-dev \
    zlib1g-dev \
    redis-server \
    wget \
    unzip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .

# نصب کتابخانه‌های Lua
RUN luarocks install luasocket && \
    luarocks install luasec && \
    luarocks install lua-cjson

# کامپایل tdlua.so از سورس
RUN git clone https://github.com/sergobot/tdlib-lua.git /tmp/tdlua && \
    cd /tmp/tdlua && \
    cmake . && \
    make && \
    cp tdlua.so /app && \
    rm -rf /tmp/tdlua

CMD sh -c "redis-server --daemonize yes && lua5.4 JokerBot.lua"
