FROM debian:bullseye-slim

# نصب ابزارها و کتابخانه‌های لازم برای build
RUN apt-get update && apt-get install -y \
    lua5.4 \
    lua5.4-dev \
    luarocks \
    gcc \
    g++ \
    make \
    libc-dev \
    libssl-dev \
    liblua5.4-dev \
    zlib1g-dev \
    redis-server \
    git \
    cmake \
    wget \
    unzip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .

# نصب کتابخانه‌های Lua
RUN luarocks install luasocket && \
    luarocks install luasec && \
    luarocks install lua-cjson

# دانلود و build tdlib-lua برای ساخت tdlua.so
RUN git clone https://github.com/sergobot/tdlib-lua.git /tmp/tdlua && \
    cd /tmp/tdlua && \
    cmake . && \
    make && \
    cp tdlua.so /app && \
    rm -rf /tmp/tdlua

CMD sh -c "redis-server --daemonize yes && lua JokerBot.lua"
