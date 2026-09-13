local pendingRequests = {}
local requestCounter = 0

local function SerializableZones()
    local result = {}
    for _, zone in ipairs(Config.AlertZones or {}) do
        result[#result + 1] = { id = zone.id, label = zone.label }
    end
    return result
end

local function BrandingPayload()
    local branding = Config.Branding or {}
    if branding.Enabled then
        local name = tostring(branding.Name or ''):gsub('^%s+', ''):gsub('%s+$', '')
        return {
            title = name ~= '' and (name .. ' Emergency Alert System') or 'Emergency Alert System',
            subtitle = tostring(branding.Subtitle or 'Authorised Communications Console')
        }
    end

    return {
        title = 'Emergency Alert System',
        subtitle = 'Authorised Communications Console'
    }
end

local function RequestServer(kind, cb)
    requestCounter = requestCounter + 1
    local requestId = ('%s:%s'):format(GetGameTimer(), requestCounter)
    pendingRequests[requestId] = cb
    TriggerServerEvent('bs-eas:server:requestData', requestId, kind)

    SetTimeout(10000, function()
        local pending = pendingRequests[requestId]
        if pending then
            pendingRequests[requestId] = nil
            pending({ success = false, alerts = {}, error = 'Request timed out.' })
        end
    end)
end

RegisterNetEvent('bs-eas:client:requestDataResponse', function(requestId, data)
    local cb = pendingRequests[requestId]
    if not cb then return end
    pendingRequests[requestId] = nil
    cb(data or { success = false, alerts = {} })
end)

RegisterNetEvent('bs-eas:client:notify', function(message, kind)
    local isError = kind == 'error'
    TriggerEvent('chat:addMessage', {
        template = '<div style="padding:0.45vw;margin:0.2vw;background:rgba(20,20,20,.88);border-left:4px solid ' .. (isError and '#c33' or '#3a9') .. ';border-radius:3px;"><b>{0}</b><br>{1}</div>',
        args = { 'Emergency Alert System', tostring(message or '') }
    })
end)

RegisterNetEvent('bs-eas:client:openMenu', function()
    RequestServer('composer', function(data)
        if not data.success then
            TriggerEvent('bs-eas:client:notify', data.error or 'Unable to open the EAS console.', 'error')
            return
        end

        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'openComposer',
            templates = Config.Templates,
            issuers = Config.Issuers,
            levels = Config.AlertLevels,
            zones = SerializableZones(),
            alerts = data.alerts or {},
            maxHeadlineLength = Config.MaxHeadlineLength,
            maxMessageLength = Config.MaxMessageLength,
            maxDetailLength = Config.MaxDetailLength,
            placeholderFields = Config.PlaceholderFields or {},
            branding = BrandingPayload()
        })
    end)
end)

RegisterNUICallback('refreshComposerData', function(_, cb)
    RequestServer('composer', function(data)
        cb(data or { success = false, alerts = {} })
    end)
end)

RegisterNUICallback('closeComposer', function(_, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeComposer' })
    cb({ success = true })
end)

RegisterNUICallback('composerAction', function(data, cb)
    if type(data) ~= 'table' then cb({ success = false }); return end
    local action = tostring(data.action or '')
    local id = tonumber(data.alertId)
    local issuer = tostring(data.issuerId or '')
    local headline = tostring(data.headline or '')
    local message = tostring(data.message or '')
    local details = type(data.details) == 'table' and data.details or {}
    local level = tostring(data.level or 'advice')
    local tone = data.playTone == true
    local zones = type(data.zones) == 'table' and data.zones or {}

    if action == 'create' then
        TriggerServerEvent('bs-eas:server:createAlert', tostring(data.templateId or ''), issuer, headline, message, level, tone, zones, details)
    elseif action == 'update' then
        TriggerServerEvent('bs-eas:server:updateAlert', id, issuer, headline, message, level, tone, zones, details)
    elseif action == 'clear' then
        TriggerServerEvent('bs-eas:server:clearAlert', id, issuer, headline, message)
    elseif action == 'reactivate' then
        TriggerServerEvent('bs-eas:server:reactivateAlert', id, issuer, headline, message, level, tone, zones, details)
    elseif action == 'remove' then
        TriggerServerEvent('bs-eas:server:removeAlert', id)
    end

    if action ~= 'remove' then
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'closeComposer' })
    end
    cb({ success = true })
end)

RegisterNetEvent('bs-eas:client:playCriticalSound', function()
    SendNUIMessage({ action = 'playAlertSound', volume = Config.AlertSoundVolume })
end)

RegisterNUICallback('getAlerts', function(_, cb)
    RequestServer('alerts', function(data)
        cb(data or { success = true, alerts = {} })
    end)
end)

CreateThread(function()
    Wait(10000)
    while true do
        TriggerServerEvent('bs-eas:server:checkZoneAlerts')
        Wait(5000)
    end
end)
