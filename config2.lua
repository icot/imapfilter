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


function process(recent)

  -- Important
  addr = 'it-dep-db-mgmt@cern.ch'
  imp = recent:match_from(addr)
    + recent:match_to(addr)
    + recent:match_cc(addr)
  imp:add_flags({'\\Flagged'})

  -- Hardware
  addr = 'it-db-storage@cern.ch'
  hw = recent:match_from(addr)
    + recent:match_to(addr)
    + recent:match_cc(addr)
  hw:add_flags({'Hardware'})
  hw:move_messages(imaps['Storage'])

  -- Storage
  addr = 'it-db-storage@cern.ch'
  storage = recent:match_from(addr)
    + recent:match_to(addr)
    + recent:match_cc(addr)
    + recent:match_subject('Parts Shipped - NetApp Log')
  storage:add_flags({'Storage'})
  storage:move_messages(imaps['Storage'])

  -- GNI
  gni = (recent:match_subject('^INC(\\d+) ')
    + recent:match_from('noreply-service-desk@cern.ch'))
    + recent:match_subject('^INC(\\d+) has a new event.')
  gni:move_messages(imaps['GNI'])

--  -- SNOW
--  addr = 'noreply-service-desk@cern.ch'
--  addr2 = 'service-desk@cern.ch'
--  snow = recent:contain_from(addr)
--    + recent:contain_from(addr2)
--    + recent:contain_cc(addr)
--    + recent:contain_cc(addr2)
--    + recent:contain_to(addr)
--    + recent:contain_to(addr2)
--  snow:move_messages(imaps['CERN Service Desk'])

  --Account Management
  addr = 'account-management.service@cern.ch'
  acc_m = recent:match_from(addr)
    + recent:match_cc(addr)
    + recent:match_to(addr)
  acc_m:move_messages(imaps['ACCOUNT MANAGEMENT'])

  -- Gitlab mesages
  -- gitlab = recent:match_field('X-GitLab-Project','(\\d)*')
  --   + recent:match_field('X-GitLab-Project-Path','(\\d)*')
  -- gitlab:move_messages(imaps['Gitlab'])

  --Resource Portal
  resource_portal = recent:match_subject('Request to create Oracle account')
    + recent:match_subject('ResourcePortal')
  resource_portal:move_messages(imaps['ResourcePortal'])

  --DBOD
  dbod = recent:match_from('dbondemand-admin@cern.ch')
    + recent:match_cc('dbondemand-admin@cern.ch')
    + recent:match_to('dbondemand-(admin|user)@cern.ch')
    + recent:match_subject('eos_archive.sh')
  dbod:move_messages(imaps['DBOD'])

  --egroup-loop
  --eloop = recent:match_field('x-ms-exchange-inbox-rules-loop','cern.ch$')
  --eloop.add_flags({'dup'})
  --eloop:move_messages(imaps['todelete'])

  -- RedHat
  redhat = recent:match_from('errata@redhat.com')
    + recent:match_cc('errata@cern.com')
    + recent:match_to('errata@cern.com')
  redhat:move_messages(imaps['RedHat'])

  -- OSS-Security
  osssec = recent:match_to('oss-security@lists.openwall.com')
  osssec:move_messages(imaps['OSS-Security'])

  -- CERN-JIRA
  cern_jira = recent:match_from('noreply-jira@cern.ch')
  cern_jira:move_messages(imaps['CERN-JIRA'])

  -- AIS-JIRA
  ais_jira = recent:match_from('ais-jira@cern.ch')
  ais_jira:delete_messages()

  -- TODELETE
  todelete = recent:match_subject('RMAN ERROR')
    + recent:match_subject('Anacron job')
    + recent:match_subject('Cron <')
    + recent:match_subject('GGUS-Ticket-ID')
    + recent:match_subject('SUCCESS: Volume')
    + recent:match_subject('RECOVERY ERROR')
    + recent:match_subject('^EM Event:')
    + recent:match_subject('ACCOUNT MANAGEMENT')
  todelete:move_messages(imaps['TODELETE'])

end

while true do
  imaps.INBOX:check_status()
  local recent = imaps.INBOX:is_recent()
  process(recent)
  imaps.INBOX:check_status()
  imaps.INBOX:enter_idle()
end

