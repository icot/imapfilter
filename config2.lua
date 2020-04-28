---------------
--  Options  --
---------------

options.timeout = 30
options.subscribe = true
options.create = false


-- Load custom config
account_name  = 'cern' -- TODO: Fetch from config file base name

local lyaml = require "lyaml"
config_file = string.format('%s/.imapfilter/config.yaml', os.getenv('HOME'))
file, err = io.open('config.yaml','r')
if err then
  print(string.format("Error reading %s:: %s", config_file, err))
  os.exit(-1)
end
config_str = file:read "*a"
file:close()

config = lyaml.load(config_str)

imap_server = config[account_name]['server']
user = config[account_name]['username']
pass = config[account_name]['password']

print(imap_server, user, pass)
imaps = IMAP {
    server = imap_server,
    username = user,
    password = string.format("%s", pass),
    ssl = 'tls1'
}


-- Functions and helpers

function deleteold(messages, days)
    todelete=messages:is_older(days)
    todelete:move_messages(imaps['Trash'])
end

function empty_trash(days)
    todelete=imaps['Trash']:is_older(days)
    todelete:delete_messages()
end


-- https://stackoverflow.com/questions/9168058/how-to-dump-a-table-to-console
function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

-- mailboxes, folders = imaps:list_all()
-- print("Mailboxes", dump(mailboxes))
-- print("Folders", dump(folders))

imaps.INBOX:check_status()

os.exit()

while true do
  imaps.INBOX:check_status()
  recent = imaps.INBOX:is_recent()
  process(recent)
  imaps.INBOX:enter_idle()
end

function process(recent)
  print("Processing recent items")
end

function process2(recent)
  for _, message in ipairs(recent) do
    mailbox, uid = table.unpack(message)
    header = mailbox[uid]:fetch_header()
    flags = mailbox[uid]:fetch_flags()
    subject = mailbox[uid]:fetch_field('subject')
    from = mailbox[uid]:fetch_field('from')
    to = mailbox[uid]:fetch_field('to')
    cc = mailbox[uid]:fetch_field('cc')
    bcc = mailbox[uid]:fetch_field('bcc')
    if not next(flags) == nil then
      print(string.format(" %s, %s", from, subject))
      print(string.format("Flags: %s", flags))
      dump(flags)
      io.read()
    end
  end
end
