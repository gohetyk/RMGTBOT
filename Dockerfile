FROM debian:bullseye-slim

# نصب LuaJIT و ابزارها
RUN apt-get update && apt-get install -y \
    luajit \
    libluajit-5.1-dev \
    luarocks \
    gcc \
    g++ \
    make \
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

# دانلود tdlua.so آماده از Release خودت
RUN wget -O /app/tdlua.so \
    https://github.com/gohetyk/RMGTBOT/releases/download/tdlua-v1/tdlua.so

CMD sh -c "redis-server --daemonize yes && luajit JokerBot.lua"
