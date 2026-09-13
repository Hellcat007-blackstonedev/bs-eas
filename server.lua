local AlertHistory = {}
local MemoryNextId = 1
local PersistenceReady = false
local PersistenceEnabled = false

local function OxAvailable()
    return GetResourceState('oxmysql') == 'started'
end

local function QuasarAvailable()
    local resourceName = Config.Quasar and Config.Quasar.ResourceName or 'qs-smartphone'
    return GetResourceState(resourceName) == 'started'
end

local function ProviderUsesPhone()
    local provider = string.lower(tostring(Config.NotificationProvider or 'auto'))
    if provider == 'chat' then return false end
    if provider == 'quasar' or provider == 'both' then return true end
    return QuasarAvailable()
end

local function DbQuery(query, params)
    return exports.oxmysql:query_async(query, params or {})
end

local function DbUpdate(query, params)
    return exports.oxmysql:update_async(query, params or {})
end

local function DbInsert(query, params)
    return exports.oxmysql:insert_async(query, params or {})
end

local function Notify(source, message, kind)
    TriggerClientEvent('bs-eas:client:notify', source, message, kind or 'info')
end

-- Delivery state:
-- Delivered[alertId][playerKey] = highest alert revision delivered.
-- Recipients[alertId][playerKey] = true once that player has ever received the incident.
local Delivered = {}
local Recipients = {}

local function DecodeJson(value, fallback)
    if not value or value == '' then return fallback end
    local ok, decoded = pcall(json.decode, value)
    if ok and decoded ~= nil then return decoded end
    return fallback
end

local function PlayerKey(source)
    local identifierType = tostring(Config.PlayerIdentifierType or 'license')
    return GetPlayerIdentifierByType(source, identifierType)
        or GetPlayerIdentifierByType(source, 'license')
        or ('source:' .. tostring(source))
end

local function AlertRevision(alert)
    return #(alert.revisions or {}) + 1
end

local function IsAllowed(source)
    for _, playerIdentifier in ipairs(GetPlayerIdentifiers(source)) do
        for _, allowedIdentifier in ipairs(Config.AllowedIdentifiers) do
            if string.lower(playerIdentifier) == string.lower(allowedIdentifier) then
                return true
            end
        end
    end

    return false
end

local function FindTemplate(id)
    for _, value in ipairs(Config.Templates) do
        if value.id == id then return value end
    end
end

local function FindIssuer(id)
    for _, value in ipairs(Config.Issuers) do
        if value.id == id then return value end
    end
end

local function FindAlert(id)
    for _, value in ipairs(AlertHistory) do
        if value.id == id then return value end
    end
end

local function FindZone(id)
    for _, value in ipairs(Config.AlertZones or {}) do
        if value.id == id then return value end
    end
end

local function ValidLevel(level)
    return Config.AlertLevels[level] ~= nil and level ~= 'all_clear'
end


local function TemplatePlaceholders(template)
    local result = {}
    local seen = {}

    for _, levelTemplate in pairs((template and template.levelTemplates) or {}) do
        local text = tostring(levelTemplate.message or '')
        for key in text:gmatch('%[([A-Z0-9_]+)%]') do
            if not seen[key] then
                seen[key] = true
                result[#result + 1] = key
            end
        end
    end

    return result
end

local function LevelPlaceholders(template, level)
    local result = {}
    local seen = {}
    local levelTemplate = template and template.levelTemplates and template.levelTemplates[level]
    local text = tostring(levelTemplate and levelTemplate.message or '')

    for key in text:gmatch('%[([A-Z0-9_]+)%]') do
        if not seen[key] then
            seen[key] = true
            result[#result + 1] = key
        end
    end

    return result
end

local function SanitizeDetails(template, values)
    local result = {}
    values = type(values) == 'table' and values or {}
    local maxLength = math.max(1, tonumber(Config.MaxDetailLength) or 160)

    for _, key in ipairs(TemplatePlaceholders(template)) do
        result[key] = tostring(values[key] or ''):sub(1, maxLength)
            :gsub('^%s+', ''):gsub('%s+$', ''):upper()
    end

    return result
end

local function RenderTemplateMessage(template, level, details)
    local levelTemplate = template and template.levelTemplates and template.levelTemplates[level]
    if not levelTemplate then return nil, 'No message template is configured for this alert level.' end

    details = type(details) == 'table' and details or {}
    local missing = {}

    for _, key in ipairs(LevelPlaceholders(template, level)) do
        if tostring(details[key] or '') == '' then
            missing[#missing + 1] = key
        end
    end

    if #missing > 0 then
        return nil, ('Complete the incident detail field(s): %s.'):format(table.concat(missing, ', '))
    end

    local message = tostring(levelTemplate.message or ''):gsub('%[([A-Z0-9_]+)%]', function(key)
        return tostring(details[key] or '')
    end)

    return message:sub(1, Config.MaxMessageLength)
end

local function PrepareAlertContent(template, level, headline, message, details)
    headline = tostring(headline or ''):sub(1, Config.MaxHeadlineLength)
    details = SanitizeDetails(template, details)

    if template and template.id ~= 'custom' then
        local rendered, err = RenderTemplateMessage(template, level, details)
        if not rendered then return nil, nil, nil, err end
        message = rendered
    else
        message = tostring(message or ''):sub(1, Config.MaxMessageLength)
    end

    if headline == '' or message == '' then
        return nil, nil, nil, 'Headline and alert message are required.'
    end

    return headline, message, details, nil
end

local function GetSenderName(source)
    local name = GetPlayerName(source)
    if name and name ~= '' then return name end
    return ('Server ID %s'):format(source)
end

local function PointInPolygon(x, y, points)
    if not points or #points < 3 then return false end

    local inside = false
    local j = #points

    for i = 1, #points do
        local xi, yi = points[i].x, points[i].y
        local xj, yj = points[j].x, points[j].y

        if ((yi > y) ~= (yj > y)) and
           (x < (xj - xi) * (y - yi) /
           ((yj - yi) ~= 0 and (yj - yi) or 0.000001) + xi) then
            inside = not inside
        end

        j = i
    end

    return inside
end

local function PlayerInZone(target, zone)
    local ped = GetPlayerPed(target)

    if not ped or ped == 0 then
        return false
    end

    local coords = GetEntityCoords(ped)

    if zone.minZ and coords.z < zone.minZ then return false end
    if zone.maxZ and coords.z > zone.maxZ then return false end

    return PointInPolygon(coords.x, coords.y, zone.points)
end

local function TargetPlayers(zoneIds)
    -- No zones = statewide.
    if not zoneIds or #zoneIds == 0 then
        local result = {}

        for _, id in ipairs(GetPlayers()) do
            result[#result + 1] = tonumber(id)
        end

        return result
    end

    local zones = {}

    for _, zoneId in ipairs(zoneIds) do
        local zone = FindZone(zoneId)

        if zone then
            zones[#zones + 1] = zone
        end
    end

    if #zones == 0 then
        return {}
    end

    local result = {}

    for _, id in ipairs(GetPlayers()) do
        local target = tonumber(id)

        for _, zone in ipairs(zones) do
            if PlayerInZone(target, zone) then
                result[#result + 1] = target
                break
            end
        end
    end

    return result
end

local function ZoneLabels(zoneIds)
    local labels = {}

    for _, zoneId in ipairs(zoneIds or {}) do
        local zone = FindZone(zoneId)

        if zone then
            labels[#labels + 1] = zone.label
        end
    end

    return labels
end

local function TrimMemoryHistory()
    local maxHistory = math.max(1, tonumber(Config.MaxHistory) or 50)

    while #AlertHistory > maxHistory do
        table.remove(AlertHistory)
    end
end

local function PersistDelivery(alert, target)
    local key = PlayerKey(target)
    local revision = AlertRevision(alert)

    Delivered[alert.id] = Delivered[alert.id] or {}
    Recipients[alert.id] = Recipients[alert.id] or {}

    Delivered[alert.id][key] = revision
    Recipients[alert.id][key] = true

    if PersistenceEnabled then
        DbQuery([[
            INSERT INTO bs_eas_recipients (alert_id, player_key, last_revision)
            VALUES (?, ?, ?)
            ON DUPLICATE KEY UPDATE last_revision = VALUES(last_revision)
        ]], { alert.id, key, revision })
    end
end

local function HasCurrentRevision(alert, target)
    local key = PlayerKey(target)

    return Delivered[alert.id]
        and Delivered[alert.id][key] == AlertRevision(alert)
end

local function WasRecipient(alert, target)
    local key = PlayerKey(target)

    return Recipients[alert.id]
        and Recipients[alert.id][key] == true
end

local function CopyArraySlice(values, count)
    local result = {}
    for i = 1, math.min(count or #values, #values) do
        result[#result + 1] = values[i]
    end
    return result
end

-- Return only the alert revision this character has actually received.
local function DeliveredAlertView(alert, target)
    if not alert.zones or #alert.zones == 0 then
        return alert
    end

    local key = PlayerKey(target)
    local deliveredRevision = Delivered[alert.id]
        and Delivered[alert.id][key]
        or nil

    if not deliveredRevision then
        return nil
    end

    local currentRevision = AlertRevision(alert)

    if deliveredRevision >= currentRevision then
        return alert
    end

    local snapshot = alert.revisions
        and alert.revisions[deliveredRevision]
        or nil

    if not snapshot then
        return nil
    end

    return {
        id = alert.id,
        type = alert.type,
        originalTitle = alert.originalTitle,
        title = snapshot.title or alert.originalTitle or alert.title,
        headline = snapshot.headline,
        message = snapshot.message,
        issuer = snapshot.issuer,
        issuerId = snapshot.issuerId,
        sender = snapshot.sender,
        timestamp = alert.timestamp,
        updatedAt = snapshot.timestamp,
        clearedAt = nil,
        status = 'active',
        level = snapshot.level or 'advice',
        playTone = false,
        zones = snapshot.zones or alert.zones or {},
        zoneLabels = snapshot.zoneLabels or ZoneLabels(snapshot.zones or alert.zones or {}),
        details = alert.details or {},
        revisions = CopyArraySlice(alert.revisions or {}, deliveredRevision - 1)
    }
end

local function AlertsForPhone(target)
    local result = {}
    for _, alert in ipairs(AlertHistory) do
        local view = DeliveredAlertView(alert, target)
        if view then
            result[#result + 1] = view
        end
    end
    return result
end


local function SaveAlertRow(alert)
    if not PersistenceEnabled then return end
    DbUpdate([[
        UPDATE bs_eas_alerts
        SET
            original_title = ?,
            title = ?,
            headline = ?,
            message = ?,
            issuer = ?,
            issuer_id = ?,
            sender = ?,
            updated_at = ?,
            cleared_at = ?,
            status = ?,
            level = ?,
            play_tone = ?,
            zones = ?,
            details = ?
        WHERE id = ?
    ]], {
        alert.originalTitle,
        alert.title,
        alert.headline,
        alert.message,
        alert.issuer,
        alert.issuerId,
        alert.sender,
        alert.updatedAt,
        alert.clearedAt,
        alert.status,
        alert.level,
        alert.playTone and 1 or 0,
        json.encode(alert.zones or {}),
        json.encode(alert.details or {}),
        alert.id
    })
end

local function SaveRevision(alert, eventType)
    local revision = {
        eventType = eventType or 'update',
        title = alert.title,
        headline = alert.headline,
        message = alert.message,
        issuer = alert.issuer,
        issuerId = alert.issuerId,
        level = alert.level,
        zones = alert.zones or {},
        zoneLabels = alert.zoneLabels or {},
        timestamp = alert.updatedAt or alert.timestamp,
        sender = alert.sender
    }

    local revisionId
    if PersistenceEnabled then
        revisionId = DbInsert([[
        INSERT INTO bs_eas_revisions
            (alert_id, event_type, title, headline, message, issuer, issuer_id, level, zones, created_at, sender)
        VALUES
            (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        alert.id,
        revision.eventType,
        revision.title,
        revision.headline,
        revision.message,
        revision.issuer,
        revision.issuerId,
        revision.level,
        json.encode(revision.zones),
        revision.timestamp,
        revision.sender
        })
    else
        revisionId = #alert.revisions + 1
    end

    revision.id = revisionId
    alert.revisions[#alert.revisions + 1] = revision
end

local function SendChatNotification(target, title, headline, message)
    if not Config.Chat or Config.Chat.Enabled == false then
        return false
    end

    local prefix = tostring(Config.Chat.Prefix or 'EMERGENCY ALERT')
    local icon = tostring(Config.Chat.Icon or '')
    local iconHtml = icon ~= '' and ('<i class=\"%s\"></i>&nbsp; '):format(icon) or ''

    TriggerClientEvent('chat:addMessage', target, {
        template = ('<div style=\"padding: 0.55vw; margin: 0.25vw; background-color: rgba(145, 20, 20, 0.88); border-left: 4px solid rgba(255,255,255,0.85); border-radius: 3px;\">%s<b>{0}</b><br><b>{1}</b><br>{2}</div>'):format(iconHtml),
        args = {
            prefix .. ' - ' .. tostring(title or 'ALERT'),
            tostring(headline or ''),
            tostring(message or '')
        }
    })

    return true
end

local function SendQuasarNotification(target, title, headline, message)
    local resourceName = Config.Quasar and Config.Quasar.ResourceName or 'qs-smartphone'

    if not QuasarAvailable() then
        return false, ('resource %s is not started'):format(resourceName)
    end

    local ok, err = pcall(function()
        exports[resourceName]:sendPhoneNotification(target, {
            appId = (Config.Quasar and Config.Quasar.AppId) or 'emergency_alerts',
            title = title,
            text = headline .. '\n\n' .. message
        })
    end)

    return ok, err
end

local function SendToPlayer(target, title, headline, message, playTone)
    local provider = string.lower(tostring(Config.NotificationProvider or 'auto'))
    local delivered = false

    if provider == 'chat' then
        delivered = SendChatNotification(target, title, headline, message)

    elseif provider == 'both' then
        local qsOk, qsErr = false, 'Quasar/SQL persistence unavailable'
        if QuasarAvailable() and OxAvailable() then qsOk, qsErr = SendQuasarNotification(target, title, headline, message)
        end
        local chatOk = SendChatNotification(target, title, headline, message)
        delivered = qsOk or chatOk

        if not qsOk then
            print(('[bs-eas] Quasar notification failed for %s: %s'):format(target, tostring(qsErr)))
        end

    elseif provider == 'quasar' then
        local qsOk, qsErr = false, 'Quasar requires oxmysql for persistent phone alerts'
        if QuasarAvailable() and OxAvailable() then
            qsOk, qsErr = SendQuasarNotification(target, title, headline, message)
        end
        delivered = qsOk

        if not qsOk then
            print(('[bs-eas] Quasar notification failed for %s: %s'):format(target, tostring(qsErr)))

            if not Config.Quasar or Config.Quasar.FallbackToChat ~= false then
                delivered = SendChatNotification(target, title, headline, message)
            end
        end

    else
        -- AUTO: prefer Quasar when available; otherwise use chat.
        if QuasarAvailable() and OxAvailable() then
            local qsOk, qsErr = SendQuasarNotification(target, title, headline, message)
            delivered = qsOk

            if not qsOk then
                print(('[bs-eas] Quasar notification failed for %s: %s'):format(target, tostring(qsErr)))
                delivered = SendChatNotification(target, title, headline, message)
            end
        else
            delivered = SendChatNotification(target, title, headline, message)
        end
    end

    if delivered and playTone then
        TriggerClientEvent('bs-eas:client:playCriticalSound', target)
    end

    return delivered
end

local function Broadcast(alert, title, playTone, zoneIds)
    local sent = 0

    for _, target in ipairs(TargetPlayers(zoneIds)) do
        if SendToPlayer(
            target,
            title,
            alert.headline,
            alert.message,
            playTone
        ) then
            sent = sent + 1
            PersistDelivery(alert, target)
        end
    end

    return sent
end

local function BroadcastAllClearToRecipients(alert)
    local sent = 0

    for _, id in ipairs(GetPlayers()) do
        local target = tonumber(id)

        if target and WasRecipient(alert, target) then
            if SendToPlayer(
                target,
                'ALL CLEAR',
                alert.headline,
                alert.message,
                false
            ) then
                sent = sent + 1
                PersistDelivery(alert, target)
            end
        end
    end

    return sent
end

local function EnsureDatabaseColumns()
    local ok, columns = pcall(function()
        return DbQuery("SHOW COLUMNS FROM bs_eas_alerts LIKE 'details'")
    end)

    if ok and type(columns) == 'table' and #columns == 0 then
        DbQuery('ALTER TABLE bs_eas_alerts ADD COLUMN details LONGTEXT NULL AFTER zones')
        print('[bs-eas] Added bs_eas_alerts.details column for persistent template fields.')
    end
end

local function LoadDatabase()
    AlertHistory = {}
    Delivered = {}
    Recipients = {}

    local maxHistory = math.max(1, tonumber(Config.MaxHistory) or 50)

    local rows = DbQuery([[
        SELECT *
        FROM bs_eas_alerts
        ORDER BY id DESC
        LIMIT ?
    ]], {
        maxHistory
    }) or {}

    for _, row in ipairs(rows) do
        local alert = {
            id = tonumber(row.id),
            type = row.type,
            originalTitle = row.original_title,
            title = row.title,
            headline = row.headline,
            message = row.message,
            issuer = row.issuer,
            issuerId = row.issuer_id,
            sender = row.sender,
            timestamp = tonumber(row.created_at),
            updatedAt = row.updated_at and tonumber(row.updated_at) or nil,
            clearedAt = row.cleared_at and tonumber(row.cleared_at) or nil,
            status = row.status,
            level = row.level,
            playTone = tonumber(row.play_tone) == 1,
            zones = DecodeJson(row.zones, {}),
            zoneLabels = {},
            details = DecodeJson(row.details, {}),
            revisions = {}
        }

        alert.zoneLabels = ZoneLabels(alert.zones)

        local revisionRows = DbQuery([[
            SELECT *
            FROM bs_eas_revisions
            WHERE alert_id = ?
            ORDER BY id ASC
        ]], {
            alert.id
        }) or {}

        for _, revisionRow in ipairs(revisionRows) do
            local revisionZones = DecodeJson(revisionRow.zones, {})

            alert.revisions[#alert.revisions + 1] = {
                id = tonumber(revisionRow.id),
                eventType = revisionRow.event_type,
                title = revisionRow.title,
                headline = revisionRow.headline,
                message = revisionRow.message,
                issuer = revisionRow.issuer,
                issuerId = revisionRow.issuer_id,
                level = revisionRow.level,
                zones = revisionZones,
                zoneLabels = ZoneLabels(revisionZones),
                timestamp = tonumber(revisionRow.created_at),
                sender = revisionRow.sender
            }
        end

        AlertHistory[#AlertHistory + 1] = alert
    end

    local recipientRows = DbQuery([[
        SELECT r.alert_id, r.player_key, r.last_revision
        FROM bs_eas_recipients r
        INNER JOIN bs_eas_alerts a ON a.id = r.alert_id
        ORDER BY r.alert_id DESC
    ]]) or {}

    for _, row in ipairs(recipientRows) do
        local alertId = tonumber(row.alert_id)
        local key = row.player_key

        Delivered[alertId] = Delivered[alertId] or {}
        Recipients[alertId] = Recipients[alertId] or {}

        Delivered[alertId][key] = tonumber(row.last_revision) or 0
        Recipients[alertId][key] = true
    end

    print(
        ('[bs-eas] Loaded %s persisted alert(s) from SQL.')
        :format(#AlertHistory)
    )
end

local function EnsureDatabaseSchema()
    DbQuery([[
        CREATE TABLE IF NOT EXISTS bs_eas_alerts (
            id INT NOT NULL AUTO_INCREMENT,
            type VARCHAR(64) NOT NULL,
            original_title VARCHAR(120) NULL,
            title VARCHAR(120) NOT NULL,
            headline VARCHAR(255) NOT NULL,
            message TEXT NOT NULL,
            issuer VARCHAR(120) NULL,
            issuer_id VARCHAR(64) NULL,
            sender VARCHAR(120) NULL,
            created_at BIGINT NOT NULL,
            updated_at BIGINT NULL,
            cleared_at BIGINT NULL,
            status VARCHAR(32) NOT NULL DEFAULT 'active',
            level VARCHAR(32) NOT NULL DEFAULT 'advice',
            play_tone TINYINT(1) NOT NULL DEFAULT 0,
            zones LONGTEXT NULL,
            details LONGTEXT NULL,
            PRIMARY KEY (id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    DbQuery([[
        CREATE TABLE IF NOT EXISTS bs_eas_revisions (
            id INT NOT NULL AUTO_INCREMENT,
            alert_id INT NOT NULL,
            event_type VARCHAR(32) NOT NULL,
            title VARCHAR(120) NULL,
            headline VARCHAR(255) NULL,
            message TEXT NULL,
            issuer VARCHAR(120) NULL,
            issuer_id VARCHAR(64) NULL,
            level VARCHAR(32) NULL,
            zones LONGTEXT NULL,
            created_at BIGINT NOT NULL,
            sender VARCHAR(120) NULL,
            PRIMARY KEY (id),
            KEY idx_bs_eas_revisions_alert (alert_id),
            CONSTRAINT fk_bs_eas_revisions_alert FOREIGN KEY (alert_id) REFERENCES bs_eas_alerts(id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    DbQuery([[
        CREATE TABLE IF NOT EXISTS bs_eas_recipients (
            alert_id INT NOT NULL,
            player_key VARCHAR(100) NOT NULL,
            last_revision INT NOT NULL DEFAULT 1,
            PRIMARY KEY (alert_id, player_key),
            CONSTRAINT fk_bs_eas_recipients_alert FOREIGN KEY (alert_id) REFERENCES bs_eas_alerts(id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
end

local function InitializePersistence()
    if PersistenceReady then return end
    PersistenceReady = true

    if not ProviderUsesPhone() then
        PersistenceEnabled = false
        print('[bs-eas] Chat/session mode active. SQL persistence is not required.')
        return
    end

    if not OxAvailable() then
        PersistenceEnabled = false
        print('[bs-eas] WARNING: Quasar phone delivery requires oxmysql. Phone delivery will fall back to chat until oxmysql is started.')
        return
    end

    PersistenceEnabled = true
    local ok, err = pcall(function()
        EnsureDatabaseSchema()
        EnsureDatabaseColumns()
        LoadDatabase()
    end)

    if not ok then
        PersistenceEnabled = false
        print(('[bs-eas] SQL persistence failed to initialise: %s'):format(tostring(err)))
    end
end

CreateThread(function()
    Wait(1000)
    InitializePersistence()
end)

AddEventHandler('onResourceStart', function(resourceName)
    local qsName = Config.Quasar and Config.Quasar.ResourceName or 'qs-smartphone'
    if resourceName == 'oxmysql' or resourceName == qsName then
        if not PersistenceEnabled and ProviderUsesPhone() and OxAvailable() then
            PersistenceReady = false
            SetTimeout(500, InitializePersistence)
        end
    end
end)

RegisterCommand(Config.Command, function(source)
    if source == 0 then
        print('[bs-eas] The EAS management console can only be opened by a player.')
        return
    end

    if not IsAllowed(source) then
        Notify(source, 'You are not authorised to access the Emergency Alert System.', 'error')
        return
    end

    TriggerClientEvent('bs-eas:client:openMenu', source)
end, false)

RegisterNetEvent('bs-eas:server:requestData', function(requestId, kind)
    local src = source
    requestId = tostring(requestId or '')

    if kind == 'composer' then
        local allowed = IsAllowed(src)
        TriggerClientEvent('bs-eas:client:requestDataResponse', src, requestId, {
            success = allowed,
            alerts = allowed and AlertHistory or {},
            error = allowed and nil or 'You are not authorised to access the Emergency Alert System.'
        })
        return
    end

    if kind == 'alerts' then
        TriggerClientEvent('bs-eas:client:requestDataResponse', src, requestId, {
            success = true,
            alerts = AlertsForPhone(src)
        })
        return
    end

    TriggerClientEvent('bs-eas:client:requestDataResponse', src, requestId, {
        success = false,
        alerts = {},
        error = 'Unknown request.'
    })
end)

RegisterNetEvent(
    'bs-eas:server:createAlert',
    function(templateId, issuerId, headline, message, level, playTone, zoneIds, details)
        local src = source

        if not IsAllowed(src) then return end

        local template = FindTemplate(tostring(templateId or ''))
        local issuer = FindIssuer(tostring(issuerId or ''))

        if not template or not issuer or not ValidLevel(level) then
            return
        end

        local contentError
        headline, message, details, contentError = PrepareAlertContent(template, level, headline, message, details)

        if contentError then
            Notify(src, contentError, 'error')
            return
        end

        zoneIds = template.zoned
            and (type(zoneIds) == 'table' and zoneIds or {})
            or {}

        if template.zoned and #zoneIds == 0 then
            Notify(src, 'Select at least one affected delivery area.', 'error')
            return
        end

        local alert = {
            type = template.id,
            originalTitle = template.title,
            title = template.title,
            headline = headline,
            message = message,
            issuer = issuer.label,
            issuerId = issuer.id,
            sender = GetSenderName(src),
            timestamp = os.time(),
            updatedAt = nil,
            clearedAt = nil,
            status = 'active',
            level = level,
            playTone = playTone == true and level == 'emergency',
            zones = zoneIds,
            zoneLabels = ZoneLabels(zoneIds),
            details = details or {},
            revisions = {}
        }

        if PersistenceEnabled then
            alert.id = DbInsert([[
                INSERT INTO bs_eas_alerts
                    (type, original_title, title, headline, message, issuer, issuer_id, sender,
                     created_at, updated_at, cleared_at, status, level, play_tone, zones, details)
                VALUES
                    (?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, NULL, ?, ?, ?, ?, ?)
            ]], {
                alert.type, alert.originalTitle, alert.title, alert.headline, alert.message,
                alert.issuer, alert.issuerId, alert.sender, alert.timestamp, alert.status,
                alert.level, alert.playTone and 1 or 0, json.encode(alert.zones), json.encode(alert.details or {})
            })
        else
            alert.id = MemoryNextId
            MemoryNextId = MemoryNextId + 1
        end

        table.insert(AlertHistory, 1, alert)
        TrimMemoryHistory()

        local sent = Broadcast(
            alert,
            alert.title,
            alert.playTone,
            alert.zones
        )

        Notify(src, ('Alert sent to %s player(s).'):format(sent), 'success')
    end
)

RegisterNetEvent(
    'bs-eas:server:updateAlert',
    function(alertId, issuerId, headline, message, level, playTone, zoneIds, details)
        local src = source

        if not IsAllowed(src) then return end

        local alert = FindAlert(tonumber(alertId))
        local issuer = FindIssuer(tostring(issuerId or ''))
        local template = alert and FindTemplate(alert.type) or nil

        if not alert
            or alert.status ~= 'active'
            or not issuer
            or not ValidLevel(level) then
            return
        end

        local contentError
        headline, message, details, contentError = PrepareAlertContent(template, level, headline, message, details or alert.details)

        if contentError then
            Notify(src, contentError, 'error')
            return
        end

        if template and template.zoned then
            zoneIds = type(zoneIds) == 'table'
                and zoneIds
                or alert.zones
                or {}

            if #zoneIds == 0 then
                Notify(src, 'Select at least one affected area.', 'error')
                return
            end
        else
            zoneIds = {}
        end

        SaveRevision(alert, 'update')

        alert.headline = headline
        alert.message = message
        alert.issuer = issuer.label
        alert.issuerId = issuer.id
        alert.level = level
        alert.playTone = playTone == true and level == 'emergency'
        alert.zones = zoneIds
        alert.zoneLabels = ZoneLabels(zoneIds)
        alert.details = details or alert.details or {}
        alert.updatedAt = os.time()
        alert.sender = GetSenderName(src)

        SaveAlertRow(alert)

        local sent = Broadcast(
            alert,
            'UPDATED: ' .. alert.title,
            alert.playTone,
            alert.zones
        )

        Notify(src, ('Alert #%s updated and sent to %s player(s).'):format(alert.id, sent), 'success')
    end
)

RegisterNetEvent(
    'bs-eas:server:clearAlert',
    function(alertId, issuerId, headline, message)
        local src = source

        if not IsAllowed(src) then return end

        local alert = FindAlert(tonumber(alertId))
        local issuer = FindIssuer(tostring(issuerId or ''))

        if not alert or alert.status ~= 'active' or not issuer then
            return
        end

        headline = tostring(headline or 'ALL CLEAR')
            :sub(1, Config.MaxHeadlineLength)

        message = tostring(message or '')
            :sub(1, Config.MaxMessageLength)

        if message == '' then
            return
        end

        SaveRevision(alert, 'all_clear')

        local now = os.time()

        alert.status = 'cleared'
        alert.level = 'all_clear'
        alert.playTone = false
        alert.title = 'ALL CLEAR'
        alert.headline = headline
        alert.message = message
        alert.issuer = issuer.label
        alert.issuerId = issuer.id
        alert.updatedAt = now
        alert.clearedAt = now
        alert.sender = GetSenderName(src)

        SaveAlertRow(alert)

        -- All Clear is deliberately NOT zone-limited.
        -- Anyone who previously received this incident receives its clearance.
        local sent = BroadcastAllClearToRecipients(alert)

        Notify(src, ('All Clear sent to %s previous recipient(s).'):format(sent), 'success')
    end
)

RegisterNetEvent(
    'bs-eas:server:reactivateAlert',
    function(alertId, issuerId, headline, message, level, playTone, zoneIds, details)
        local src = source

        if not IsAllowed(src) then return end

        local alert = FindAlert(tonumber(alertId))
        local issuer = FindIssuer(tostring(issuerId or ''))
        local template = alert and FindTemplate(alert.type) or nil

        if not alert
            or alert.status ~= 'cleared'
            or not issuer
            or not ValidLevel(level) then
            return
        end

        local contentError
        headline, message, details, contentError = PrepareAlertContent(template, level, headline, message, details or alert.details)

        if contentError then
            Notify(src, contentError, 'error')
            return
        end

        if template and template.zoned then
            zoneIds = type(zoneIds) == 'table'
                and zoneIds
                or alert.zones
                or {}

            if #zoneIds == 0 then
                return
            end
        else
            zoneIds = {}
        end

        SaveRevision(alert, 'reactivated')

        alert.status = 'active'
        alert.level = level
        alert.title = alert.originalTitle or 'EMERGENCY ALERT'
        alert.headline = headline
        alert.message = message
        alert.issuer = issuer.label
        alert.issuerId = issuer.id
        alert.playTone = playTone == true and level == 'emergency'
        alert.zones = zoneIds
        alert.zoneLabels = ZoneLabels(zoneIds)
        alert.details = details or alert.details or {}
        alert.updatedAt = os.time()
        alert.clearedAt = nil
        alert.sender = GetSenderName(src)

        SaveAlertRow(alert)

        local sent = Broadcast(
            alert,
            'REACTIVATED: ' .. alert.title,
            alert.playTone,
            alert.zones
        )

        Notify(src, ('Alert #%s reactivated and sent to %s player(s).'):format(alert.id, sent), 'success')
    end
)

RegisterNetEvent(
    'bs-eas:server:removeAlert',
    function(alertId)
        local src = source

        if not IsAllowed(src) then return end

        local id = tonumber(alertId)

        for index, alert in ipairs(AlertHistory) do
            if alert.id == id then
                if alert.status == 'active' then
                    Notify(src, 'Active alerts cannot be removed. Issue an All Clear first.', 'error')
                    return
                end

                if PersistenceEnabled then
                    DbQuery('DELETE FROM bs_eas_alerts WHERE id = ?', { id })
                end

                -- Revision and recipient rows are removed automatically
                -- by ON DELETE CASCADE.
                table.remove(AlertHistory, index)
                Delivered[id] = nil
                Recipients[id] = nil

                Notify(src, ('Alert #%s removed from the app.'):format(id), 'success')

                return
            end
        end
    end
)

-- Client periodically calls this while online.
-- 1. Entering an active alert zone delivers the latest revision once.
-- 2. If this player previously received an incident that was cleared while
--    they were offline, the pending All Clear is delivered regardless of location.
RegisterNetEvent(
    'bs-eas:server:checkZoneAlerts',
    function()
        local src = source

        for _, alert in ipairs(AlertHistory) do
            if alert.status == 'active'
                and alert.zones
                and #alert.zones > 0 then

                local inside = false

                for _, zoneId in ipairs(alert.zones) do
                    local zone = FindZone(zoneId)

                    if zone and PlayerInZone(src, zone) then
                        inside = true
                        break
                    end
                end

                if inside and not HasCurrentRevision(alert, src) then
                    local title = alert.updatedAt
                        and ('UPDATED: ' .. alert.title)
                        or alert.title

                    if SendToPlayer(
                        src,
                        title,
                        alert.headline,
                        alert.message,
                        alert.playTone == true
                    ) then
                        PersistDelivery(alert, src)
                    end
                end

            elseif alert.status == 'cleared'
                and WasRecipient(alert, src)
                and not HasCurrentRevision(alert, src) then

                if SendToPlayer(
                    src,
                    'ALL CLEAR',
                    alert.headline,
                    alert.message,
                    false
                ) then
                    PersistDelivery(alert, src)
                end
            end
        end
    end
)
