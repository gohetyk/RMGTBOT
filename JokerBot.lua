-- Minimal Telegram Bot (Bot API, no TDLib)
-- Reads TOKEN from env, replies to /start, long-polling loop.

-- ====== Config ======
local TOKEN = os.getenv("TOKEN")
assert(TOKEN and TOKEN:match("^%d+:%S+$"), "TOKEN env var is missing or invalid")

-- ====== Requires (from LuaRocks / Lib) ======
local https = require("ssl.https")
local URL   = require("socket.url")

-- dkjson: اول از Lib/ اگر بود، بعد از luarocks
local ok_dkjson, dkjson = pcall(function() return (loadfile("./Lib/dkjson.lua"))() end)
if not ok_dkjson then
  dkjson = require("dkjson")
end

-- ====== Helpers ======
local function urlencode(s) return URL.escape(s or "") end

local function api(method, params)
  local base = "https://api.telegram.org/bot" .. TOKEN .. "/" .. method
  if params and next(params) then
    local q = {}
    for k, v in pairs(params) do
      q[#q+1] = k .. "=" .. urlencode(v)
    end
    base = base .. "?" .. table.concat(q, "&")
  end
  local body, code = https.request(base)
  if not body or code ~= 200 then
    return nil, "HTTP error: " .. tostring(code)
  end
  local obj = dkjson.decode(body)
  if not obj or not obj.ok then
    return nil, "API error: " .. (obj and obj.description or "unknown")
  end
  return obj.result
end

local function sendMessage(chat_id, text, reply_to)
  local ok, err = api("sendMessage", {
    chat_id = tostring(chat_id),
    text    = tostring(text),
    parse_mode = "HTML",
    reply_to_message_id = reply_to and tostring(reply_to) or nil
  })
  return ok, err
end

-- ====== Health check (optional) ======
do
  local me, err = api("getMe")
  if not me then
    print("getMe failed: " .. tostring(err))
  else
    print("Bot online as @" .. tostring(me.username))
  end
end

-- ====== Main long-poll loop ======
local offset = 0
while true do
  -- 25 ثانیه لانگ‌پول
  local updates, err = api("getUpdates", { timeout = "25", offset = tostring(offset) })
  if updates then
    for _, u in ipairs(updates) do
      offset = math.max(offset, (u.update_id or 0) + 1)
      local msg = u.message
      if msg and msg.chat and msg.chat.id and msg.text then
        local text = msg.text
        -- پاسخ ساده به /start
        if text:match("^/start") then
          sendMessage(msg.chat.id, "سلام! ربات با موفقیت ران شد ✅", msg.message_id)
        else
          -- Echo نمونه (می‌تونی حذف کنی)
          -- sendMessage(msg.chat.id, "گفتی: " .. text, msg.message_id)
        end
      end
    end
  else
    print("getUpdates error: " .. tostring(err))
    -- کمی صبر و تلاش مجدد
    os.execute("sleep 2")
  end
end
