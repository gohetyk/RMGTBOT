print("JokerBot.lua اجرا شد ✅")

local https = require("ssl.https")
local URL   = require("socket.url")

local TOKEN = os.getenv("TOKEN")
assert(TOKEN and TOKEN:match("^%d+:%S+$"), "TOKEN env var is missing or invalid")

-- dkjson
local ok_dkjson, dkjson = pcall(function() return (loadfile("./Lib/dkjson.lua"))() end)
if not ok_dkjson then
  dkjson = require("dkjson")
end

local function api(method, params)
  local base = "https://api.telegram.org/bot" .. TOKEN .. "/" .. method
  if params and next(params) then
    local q = {}
    for k, v in pairs(params) do
      q[#q+1] = k .. "=" .. URL.escape(v)
    end
    base = base .. "?" .. table.concat(q, "&")
  end
  local body, code = https.request(base)
  if not body or code ~= 200 then return nil end
  local obj = dkjson.decode(body)
  if not obj or not obj.ok then return nil end
  return obj.result
end

local function sendMessage(chat_id, text, reply_to)
  api("sendMessage", {
    chat_id = tostring(chat_id),
    text = tostring(text),
    parse_mode = "HTML",
    reply_to_message_id = reply_to
  })
end

local offset = 0
while true do
  local updates = api("getUpdates", {timeout = "25", offset = tostring(offset)})
  if updates then
    for _,u in ipairs(updates) do
      offset = math.max(offset, (u.update_id or 0) + 1)
      local msg = u.message
      if msg and msg.text then
        if msg.text:match("^/start") then
          sendMessage(msg.chat.id, "سلام! ربات با موفقیت ران شد ✅", msg.message_id)
        elseif msg.text:match("^/help") then
          local help = [[
🔹 *راهنمای ربات* 🔹

/start - شروع کار با ربات
/help - همین راهنما

(به‌زودی دستورات مدیریت گروه اضافه می‌شود)
]]
          sendMessage(msg.chat.id, help, msg.message_id)
        end
      end
    end
  end
end
