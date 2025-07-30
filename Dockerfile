FROM debian:bullseye-slim

# نصب ابزارهای لازم + وابستگی‌ها
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
    wget \
    unzip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .

# نصب کتابخانه‌های Lua
RUN luarocks install luasocket && \
    luarocks install luasec && \
    luarocks install lua-cjson

# دانلود tdlua.so (لینک جدید و فعال)
RUN wget -O tdlua.so https://github.com/tdlight-team/tdlight/releases/download/v0.6.0/tdlua.so

CMD sh -c "redis-server --daemonize yes && lua JokerBot.lua"
