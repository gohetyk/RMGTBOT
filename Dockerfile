FROM debian:bullseye-slim

# نصب ابزارها و وابستگی‌های لازم
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

# دانلود tdlua.so از Release خودت
RUN wget -O /app/tdlua.so \
    https://github.com/gohetyk/RMGTBOT/releases/download/tdlua-v1/tdlua.so

CMD sh -c "redis-server --daemonize yes && lua JokerBot.lua"
