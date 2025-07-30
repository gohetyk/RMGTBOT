FROM debian:bullseye-slim

# نصب ابزارها و پکیج‌های لازم
RUN apt-get update && apt-get install -y \
    lua5.4 \
    lua5.4-dev \
    luarocks \
    gcc \
    g++ \
    make \
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

# دانلود tdlua.so
RUN wget -O tdlua.so https://github.com/tdlight-team/tdlight-telegram-bot-api/releases/download/v1.8.0/tdlua.so

CMD sh -c "redis-server --daemonize yes && lua JokerBot.lua"
