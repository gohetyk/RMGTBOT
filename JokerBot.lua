print("JokerBot.lua اجرا شد ✅")

local https = require("ssl.https")
local URL   = require("socket.url")

local TOKEN = os.getenv("TOKEN")
assert(TOKEN and TOKEN:match("^%d+:%S+$"), "TOKEN env var is missing or invalid")

local ok_dkjson, dkjson = pcall(function() return (loadfile("./Lib/dkjson.lua"))() end)
if not ok_dkjson then dkjson = require("dkjson") end

-- جدول اخطارها در حافظه
local warns = {}

-- Bot API
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

-- بن کردن کاربر
local function banUser(chat_id, user_id)
  api("kickChatMember", {chat_id = tostring(chat_id), user_id = tostring(user_id)})
end

-- دستورات
local function handle_commands(msg)
  local user_id = msg.from.id

  -- دستور /start
  if msg.text:match("^/start") then
    sendMessage(msg.chat.id, "سلام! ربات با موفقیت ران شد ✅", msg.message_id)

  -- دستور /help
  elseif msg.text:match("^/help") then
    sendMessage(msg.chat.id, [[
🔹 راهنمای ربات 🔹

/start - شروع کار با ربات
/help - همین راهنما

📌 وقتی ربات ادمین باشد:
- لینک‌های گروه را حذف و اخطار می‌دهد.
- بعد از ۳ اخطار کاربر بن می‌شود.
]], msg.message_id)

  -- حذف لینک و اخطار
  else
    if msg.chat.type and msg.chat.type:match("group") then
      if msg.text:match("https?://") or msg.text:match("t%.me") then
        api("deleteMessage", {
          chat_id = tostring(msg.chat.id),
          message_id = tostring(msg.message_id)
        })

        warns[user_id] = (warns[user_id] or 0) + 1
        if warns[user_id] >= 3 then
          sendMessage(msg.chat.id, "🚫 کاربر @"..(msg.from.username or user_id).." به دلیل ۳ اخطار بن شد", msg.message_id)
          banUser(msg.chat.id, user_id)
          warns[user_id] = 0 -- ریست شود
        else
          sendMessage(msg.chat.id, "⚠️ کاربر @"..(msg.from.username or user_id).." اخطار "..warns[user_id].."/3 دریافت کرد", msg.message_id)
        end
      end
    end
  end
end

-- حلقه اصلی
local offset = 0
while true do
  local updates = api("getUpdates", {timeout = "25", offset = tostring(offset)})
  if updates then
    for _,u in ipairs(updates) do
      offset = math.max(offset, (u.update_id or 0) + 1)
      if u.message and u.message.text then
        handle_commands(u.message)
      end
    end
  else
    os.execute("sleep 2")
  end
end
