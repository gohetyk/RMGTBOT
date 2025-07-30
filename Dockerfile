FROM debian:bullseye-slim

# نصب LuaJIT و ابزارها
RUN apt-get update && apt-get install -y \
    luajit \
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

# نصب کتابخانه‌های Lua مورد نیاز
RUN luarocks install luasocket && \
    luarocks install luasec && \
    luarocks install dkjson || true

# اجرای Redis و سپس اجرای ربات
CMD sh -c "redis-server --daemonize yes && luajit JokerBot.lua"
