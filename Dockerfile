FROM alpine:latest
RUN apk add --no-cache lua5.4 luarocks redis wget unzip
WORKDIR /app
COPY . .
RUN luarocks install luasocket && luarocks install luasec && luarocks install lua-cjson

# دانلود tdlua.so موقع build
RUN wget -O tdlua.so https://github.com/tdlight-team/tdlight-telegram-bot-api/releases/download/v1.8.0/tdlua.so

CMD sh -c "redis-server --daemonize yes && lua JokerBot.lua"
