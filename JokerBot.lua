-- JokerBot.lua — نسخه کامل و یکجا برای مدیریت گروه
-- اجرا با luajit و بدون نیاز به TDLib (فقط Bot API)

print("JokerBot.lua اجرا شد ✅")

----------------------------
-- کتابخانه‌ها و تنظیمات  --
----------------------------
local https = require("ssl.https")
local URL   = require("socket.url")

local TOKEN = os.getenv("TOKEN")
assert(TOKEN and TOKEN:match("^%d+:%S+$"), "TOKEN env var is missing or invalid")

-- dkjson: اول از Lib/ اگر بود، بعد از luarocks
local ok_dkjson, dkjson = pcall(function() return (loadfile("./Lib/dkjson.lua"))() end)
if not ok_dkjson then
  dkjson = require("dkjson")
end

-----------------------------------
-- ذخیره‌سازی ساده در حافظه RAM  --
-- (با ری‌استارت پاک می‌شود)     --
-----------------------------------
local db = {
  locks   = {},   -- locks[chat_id][lock_name]=true/false  (links, all, media)
  warns   = {},   -- warns[chat_id][user_id] = n
  welcome = {},   -- welcome[chat_id] = text
}

-----------------------
-- توابع کمکی عمومی --
-----------------------
local function api(method, params)
  local base = "https://api.telegram.org/bot" .. TOKEN .. "/" .. method
  if params and next(params) then
    local q = {}
    for k, v in pairs(params) do
      q[#q+1] = k .. "=" .. URL.escape(tostring(v))
    end
    base = base .. "?" .. table.concat(q, "&")
  end
  local body, code = https.request(base)
  if code ~= 200 or not body then
    return nil, "HTTP:" .. tostring(code)
  end
  local obj = dkjson.decode(body)
  if not obj or obj.ok ~= true then
    return nil, (obj and obj.description) or "API error"
  end
  return obj.result
end

local function sendMessage(chat_id, text, reply_to)
  return api("sendMessage", {
    chat_id = tostring(chat_id),
    text = tostring(text),
    parse_mode = "HTML",
    reply_to_message_id = reply_to
  })
end

local function deleteMessage(chat_id, message_id)
  return api("deleteMessage", {
    chat_id = tostring(chat_id),
    message_id = tostring(message_id)
  })
end

local function kick(chat_id, user_id)
  -- بن (Kick) — توجه: برای بن دائمی ممکن است نیاز به banChatMember باشد (در نسخه‌های جدید)
  return api("kickChatMember", {
    chat_id = tostring(chat_id),
    user_id = tostring(user_id)
  })
end

local function isGroup(chat_type)
  return chat_type == "group" or chat_type == "supergroup"
end

local function ensureTable(t, key)
  t[key] = t[key] or {}
  return t[key]
end

-- قفل‌ها
local function isLocked(chat_id, name)
  local locks = ensureTable(db.locks, chat_id)
  return locks[name] == true
end
local function setLock(chat_id, name, state)
  local locks = ensureTable(db.locks, chat_id)
  locks[name] = state and true or false
end

-- اخطارها
local function addWarn(chat_id, user_id)
  local warns = ensureTable(db.warns, chat_id)
  warns[user_id] = (warns[user_id] or 0) + 1
  return warns[user_id]
end
local function getWarns(chat_id, user_id)
  local warns = ensureTable(db.warns, chat_id)
  return warns[user_id] or 0
end
local function resetWarns(chat_id, user_id)
  local warns = ensureTable(db.warns, chat_id)
  warns[user_id] = 0
end

-- خوش‌آمد
local function setWelcome(chat_id, text)
  db.welcome[chat_id] = text
end
local function getWelcome(chat_id)
  return db.welcome[chat_id]
end

--------------------------------
-- چک ادمین بودن یک کاربر    --
--------------------------------
local function isAdmin(chat_id, user_id)
  local res, err = api("getChatMember", {
    chat_id = tostring(chat_id),
    user_id = tostring(user_id)
  })
  if not res then return false end
  local status = res.status
  return (status == "creator" or status == "administrator")
end

--------------------------------
-- تشخیص لینک و مدیا           --
--------------------------------
local function contains_link(msg)
  if not msg.text then return false end
  -- تشخیص ساده با متن
  if msg.text:match("https?://") or msg.text:match("t%.me") then
    return true
  end
  -- تشخیص توسط entities
  local ents = msg.entities
  if ents and type(ents) == "table" then
    for _,e in ipairs(ents) do
      if e.type == "url" or e.type == "text_link" then
        return true
      end
    end
  end
  return false
end

local function contains_media(msg)
  -- اگر هرکدام از انواع مدیا بود، true
  return (msg.photo or msg.video or msg.animation or msg.document or msg.sticker or
          msg.voice or msg.audio or msg.video_note) ~= nil
end

------------------------------------------------
-- منطق اجرای سیاست‌ها قبل از رسیدن به دستورات --
------------------------------------------------
local function enforce_policies(msg)
  local chat_id = msg.chat.id
  local user_id = msg.from and msg.from.id
  local is_admin = user_id and isAdmin(chat_id, user_id) or false

  -- قفل کامل: هر پیام غیر ادمین حذف شود
  if isLocked(chat_id, "all") and not is_admin then
    deleteMessage(chat_id, msg.message_id)
    return true
  end

  -- قفل مدیا
  if isLocked(chat_id, "media") and not is_admin and contains_media(msg) then
    deleteMessage(chat_id, msg.message_id)
    -- اخطار بابت مدیا؟
    local n = addWarn(chat_id, user_id)
    if n >= 3 then
      sendMessage(chat_id, "🚫 کاربر "..(msg.from.username and ("@"..msg.from.username) or ("#"..user_id)).." به دلیل ۳ اخطار بن شد", msg.message_id)
      kick(chat_id, user_id)
      resetWarns(chat_id, user_id)
    else
      sendMessage(chat_id, "⚠️ اخطار "..n.."/3 بابت ارسال مدیا در حالت قفل", msg.message_id)
    end
    return true
  end

  -- قفل لینک‌ها
  if isLocked(chat_id, "links") and not is_admin and contains_link(msg) then
    deleteMessage(chat_id, msg.message_id)
    local n = addWarn(chat_id, user_id)
    if n >= 3 then
      sendMessage(chat_id, "🚫 کاربر "..(msg.from.username and ("@"..msg.from.username) or ("#"..user_id)).." به دلیل ۳ اخطار بن شد", msg.message_id)
      kick(chat_id, user_id)
      resetWarns(chat_id, user_id)
    else
      sendMessage(chat_id, "⚠️ اخطار "..n.."/3 بابت ارسال لینک", msg.message_id)
    end
    return true
  end

  return false
end

-----------------------------
-- پردازش ورود اعضای جدید  --
-----------------------------
local function handle_new_member(msg)
  local chat_id = msg.chat.id
  local wc = getWelcome(chat_id)
  if wc and msg.new_chat_members and #msg.new_chat_members > 0 then
    for _,m in ipairs(msg.new_chat_members) do
      local name = (m.first_name or "") .. (m.last_name and (" " .. m.last_name) or "")
      local mention = m.username and ("@" .. m.username) or name
      sendMessage(chat_id, (wc:gsub("{name}", mention)))
    end
    return true
  end
  return false
end

-------------------------
-- دستورات (ادمین‌ها) --
-------------------------
local function handle_commands(msg)
  if not msg.text then return end
  local chat_id = msg.chat.id
  local user_id = msg.from and msg.from.id or 0
  local text    = msg.text

  local function require_admin()
    if not isAdmin(chat_id, user_id) then
      sendMessage(chat_id, "❌ فقط ادمین می‌تواند این دستور را اجرا کند.", msg.message_id)
      return false
    end
    return true
  end

  -- عمومی
  if text:match("^/start") then
    sendMessage(chat_id, "سلام! ربات مدیریت گروه فعال است ✅\n/help را برای راهنما بفرستید.", msg.message_id)
    return
  elseif text:match("^/help") then
    sendMessage(chat_id, [[
🔹 راهنمای ربات مدیریت گروه 🔹

دستورات ادمین‌ها:
/locklinks — قفل لینک‌ها (حذف لینک + اخطار)
/unlocklinks — آزاد کردن لینک‌ها
/lockmedia — قفل مدیا (عکس/فیلم/استیکر/…)
/unlockmedia — آزاد کردن مدیا
/lockall — قفل کامل گروه (حذف پیام‌های غیرادمین)
/unlockall — باز کردن گروه
/setwelcome <متن> — تعیین پیام خوش‌آمد (از {name} برای نام عضو استفاده کن)
/getwelcome — نمایش پیام خوش‌آمد
/warn @user — دادن اخطار (دستی)
/warns @user — تعداد اخطارها
/resetwarns @user — ریست اخطارها
/ping — تست آنلاین بودن
]], msg.message_id)
    return
  elseif text:match("^/ping$") then
    sendMessage(chat_id, "pong ✅", msg.message_id)
    return
  end

  -- قفل‌ها
  if text:match("^/locklinks$") then
    if not require_admin() then return end
    setLock(chat_id, "links", true)
    sendMessage(chat_id, "✅ قفل لینک‌ها فعال شد.", msg.message_id)
    return
  elseif text:match("^/unlocklinks$") then
    if not require_admin() then return end
    setLock(chat_id, "links", false)
    sendMessage(chat_id, "🔓 قفل لینک‌ها غیرفعال شد.", msg.message_id)
    return
  elseif text:match("^/lockmedia$") then
    if not require_admin() then return end
    setLock(chat_id, "media", true)
    sendMessage(chat_id, "✅ قفل مدیا فعال شد.", msg.message_id)
    return
  elseif text:match("^/unlockmedia$") then
    if not require_admin() then return end
    setLock(chat_id, "media", false)
    sendMessage(chat_id, "🔓 قفل مدیا غیرفعال شد.", msg.message_id)
    return
  elseif text:match("^/lockall$") then
    if not require_admin() then return end
    setLock(chat_id, "all", true)
    sendMessage(chat_id, "✅ قفل کامل گروه فعال شد (فقط ادمین‌ها می‌توانند پیام دهند).", msg.message_id)
    return
  elseif text:match("^/unlockall$") then
    if not require_admin() then return end
    setLock(chat_id, "all", false)
    sendMessage(chat_id, "🔓 گروه باز شد.", msg.message_id)
    return
  end

  -- خوش‌آمد
  if text:match("^/setwelcome") then
    if not require_admin() then return end
    local w = text:gsub("^/setwelcome", "", 1)
    w = w:gsub("^%s+", "")
    if w == "" then
      sendMessage(chat_id, "فرمت درست: /setwelcome متن\nمثال: /setwelcome سلام {name} به گروه خوش اومدی ✨", msg.message_id)
      return
    end
    setWelcome(chat_id, w)
    sendMessage(chat_id, "✅ پیام خوش‌آمد ذخیره شد.", msg.message_id)
    return
  elseif text:match("^/getwelcome$") then
    local w = getWelcome(chat_id)
    if w then
      sendMessage(chat_id, "پیام خوش‌آمد فعلی:\n"..w, msg.message_id)
    else
      sendMessage(chat_id, "هنوز پیام خوش‌آمد تنظیم نشده.", msg.message_id)
    end
    return
  end

  -- اخطار دستی / گزارش اخطارها / ریست
  if text:match("^/warns") then
    if not require_admin() then return end
    local uname = text:match("^/warns%s+@([%w_]+)")
    local tgt_id = nil
    if uname and msg.entities then
      -- اگر username دادند، تلاش برای تبدیل به id با reply راحت‌تر است؛
      -- ساده‌سازی: اگر ریپلای موجود است همان را بگیریم
    end
    if msg.reply_to_message and msg.reply_to_message.from then
      tgt_id = msg.reply_to_message.from.id
    end
    if not tgt_id then
      sendMessage(chat_id, "ریپلای کن یا /warns را با ریپلای استفاده کن.", msg.message_id)
      return
    end
    local n = getWarns(chat_id, tgt_id)
    sendMessage(chat_id, "🔎 اخطارهای کاربر: "..tostring(n).."/3", msg.message_id)
    return
  elseif text:match("^/resetwarns") then
    if not require_admin() then return end
    local tgt_id = msg.reply_to_message and msg.reply_to_message.from and msg.reply_to_message.from.id
    if not tgt_id then
      sendMessage(chat_id, "ریپلای کن روی پیام کاربر و /resetwarns بزن.", msg.message_id)
      return
    end
    resetWarns(chat_id, tgt_id)
    sendMessage(chat_id, "✅ اخطارهای کاربر ریست شد.", msg.message_id)
    return
  elseif text:match("^/warn$") then
    if not require_admin() then return end
    local tgt_id = msg.reply_to_message and msg.reply_to_message.from and msg.reply_to_message.from.id
    if not tgt_id then
      sendMessage(chat_id, "ریپلای کن روی پیام کاربر و /warn بزن.", msg.message_id)
      return
    end
    local n = addWarn(chat_id, tgt_id)
    if n >= 3 then
      sendMessage(chat_id, "🚫 کاربر به دلیل ۳ اخطار بن شد.", msg.message_id)
      kick(chat_id, tgt_id)
      resetWarns(chat_id, tgt_id)
    else
      sendMessage(chat_id, "⚠️ اخطار "..n.."/3 ثبت شد.", msg.message_id)
    end
    return
  end
end

-----------------
-- حلقه اصلی   --
-----------------
-- نکته: اگر privacy در BotFather روشن باشد، ربات پیام‌های عادی گروه را نمی‌گیرد.
-- برای مدیریت گروه باید privacy را Disable کنی.
local me = api("getMe")
if me and me.username then
  print("Bot @"..me.username.." آماده است")
end

local offset = 0
while true do
  local updates = api("getUpdates", { timeout = "25", offset = tostring(offset) })
  if updates then
    for _, u in ipairs(updates) do
      offset = math.max(offset, (u.update_id or 0) + 1)

      -- خوش‌آمدگویی
      if u.message and u.message.new_chat_members then
        handle_new_member(u.message)
      end

      -- پیام متنی یا مدیا
      if u.message and u.message.chat and isGroup(u.message.chat.type) then
        -- اول سیاست‌ها (قفل‌ها/اخطار خودکار)
        local acted = enforce_policies(u.message)
        if not acted and u.message.text then
          -- سپس دستورات
          handle_commands(u.message)
        end
      elseif u.message and u.message.text then
        -- چت خصوصی: فقط دستورات پایه
        handle_commands(u.message)
      end
    end
  else
    -- خطای موقتی شبکه
    os.execute("sleep 2")
  end
end
