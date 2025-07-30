FROM debian:bullseye-slim

# نصب LuaJIT + ابزارها
RUN apt-get update && apt-get install -y \
    luajit \
    libluajit-5.1-dev \
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

# نصب کتابخانه‌های Lua روی LuaJIT
RUN luarocks --lua-suffix=jit install luasocket && \
    luarocks --lua-suffix=jit install luasec && \
    luarocks --lua-suffix=jit install lua-cjson

# کلون و build tdlua.so از سورس پایدار
RUN git clone --depth 1 https://github.com/kennyledet/tdlua.git /tmp/tdlua && \
    cd /tmp/tdlua && \
    cmake -DLUA_INCLUDE_DIR=/usr/include/luajit-2.1 -DLUA_LIBRARY=/usr/lib/x86_64-linux-gnu/libluajit-5.1.so . && \
    make && \
    cp tdlua.so /app && \
    rm -rf /tmp/tdlua

CMD sh -c "redis-server --daemonize yes && luajit JokerBot.lua"
