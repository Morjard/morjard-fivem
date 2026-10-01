Config = {}

-- How often (ms) the client should notify server to increment the timer (1 minute = 60000)
Config.TickInterval = 60000

-- UI settings
Config.UI = {
    width = 720,
    height = 480
}

-- Supported languages (UI will load corresponding JSON from html/locales)
Config.Languages = { 'en', 'cs', 'it', 'es' }

-- Command name
Config.Command = 'biography' -- /biography [serverID]

-- Max distance (game units) allowed between requester and target to view someone else's
-- biography. Own biography (no target, or target == yourself) is always allowed regardless
-- of distance. Checked server-side -- see server.lua RequestBiography handler.
Config.MaxLookupDistance = 5.0