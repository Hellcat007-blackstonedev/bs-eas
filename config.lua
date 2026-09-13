Config = {}

-- ============================================================
--  EMERGENCY ALERT SYSTEM - CONFIGURATION
-- ============================================================
-- This file contains the settings intended to be customised by the server owner.
-- Work through each section and adjust the values that suit your community.
-- Unless a setting specifically needs changing for your setup, the supplied defaults
-- can be left as they are.

-- ============================================================
--  GENERAL SETTINGS
-- ============================================================

-- Set the command authorised staff will use to open the EAS management menu.
-- Example: 'eas' will create the /eas command.
Config.Command = 'eas'

-- Player identity used for recipient tracking. 'license' is recommended and works
-- without any framework. Do not change this unless you know your server uses a
-- different persistent FiveM identifier type.
Config.PlayerIdentifierType = 'license'

-- Optional UI branding. Leave Enabled = false for the generic Emergency Alert System UI.
-- Enable it if you want the management console to display your community/server name.
Config.Branding = {
    Enabled = false,
    Name = 'Your Community',
    Subtitle = 'Authorised Communications Console'
}

-- Set the maximum number of characters operators can enter for alert headlines
-- and alert messages. Increase these only if your community regularly uses longer alerts.
Config.MaxHeadlineLength = 100
Config.MaxMessageLength = 900

-- Set the maximum number of characters allowed in each placeholder field such as
-- [AREA], [ROAD], or [DIRECTION].
Config.MaxDetailLength = 160

-- Set how many previous incidents are shown in the alert history.
Config.MaxHistory = 50

-- Set the volume of the critical EAS tone.
-- 0.0 = silent, 1.0 = full volume. A lower value is recommended for gameplay.
Config.AlertSoundVolume = 0.20

-- ============================================================
--  PERMISSIONS
-- ============================================================
-- Add the identifiers of staff who are allowed to open the EAS management menu
-- and issue, update, clear, reactivate, or remove alerts.
--
-- Discord identifiers are recommended for this resource:
--   discord:123456789012345678
--
-- Add one entry per authorised staff member. Keep the quotation marks and comma.
Config.AllowedIdentifiers = {
    'discord:123456789012345678',
}

-- ============================================================
--  ALERT DELIVERY / PHONE INTEGRATION
-- ============================================================
-- Choose how players on your server receive emergency alerts:
--   'auto'    = use Quasar Smartphone when available; otherwise use FiveM chat
--   'quasar'  = send through Quasar Smartphone; chat can be used as a fallback
--   'chat'    = use FiveM text chat only
--   'both'    = send every alert through both Quasar Smartphone and FiveM chat
--
-- Leave this set to 'auto' if you want the resource to work automatically on servers
-- with or without Quasar Smartphone installed.
Config.NotificationProvider = 'auto'

-- Quasar Smartphone integration settings.
-- Quasar Smartphone is optional. If your phone resource folder has been renamed,
-- change ResourceName below to match the exact folder/resource name.
Config.Quasar = {
    ResourceName = 'qs-smartphone',
    AppId = 'emergency_alerts',

    -- When enabled, FiveM chat will be used if Quasar Smartphone is unavailable
    -- or an alert cannot be delivered through the phone integration.
    FallbackToChat = true,
}

-- FiveM chat notification settings.
-- These settings are used when Config.NotificationProvider is 'chat' or 'both',
-- and can also be used as the fallback for unavailable Quasar Smartphone delivery.
Config.Chat = {
    Enabled = true,

    -- Text shown at the beginning of every chat-based emergency alert.
    Prefix = 'EMERGENCY ALERT',

    -- Font Awesome icon class displayed beside chat alerts.
    -- Examples: 'fas fa-bullhorn', 'fas fa-bell', 'fas fa-triangle-exclamation'.
    -- Set this to '' if you do not want an icon.
    Icon = 'fas fa-triangle-exclamation',
}

-- ============================================================
--  ALERT ISSUERS
-- ============================================================
-- Configure the agencies or organisations that can appear as an alert issuer.
-- The label is what operators see in the composer. The id is used internally and must
-- be unique. If you add a new issuer, its id can be used as defaultIssuer in templates.
Config.Issuers = {
    { id = 'government', label = 'State Government' },
    { id = 'lspd',       label = 'Police Department' },
    { id = 'safd',       label = 'Fire & Rescue' },
    { id = 'weather',    label = 'Weather Service' }
}


-- ============================================================
--  ALERT LEVELS
-- ============================================================
-- Configure the available alert severity levels.
-- 'label' is shown to players. 'defaultPlayTone' controls whether the critical EAS
-- tone is selected automatically when an operator chooses that severity.
Config.AlertLevels = {
    advice = { label = 'ADVICE', defaultPlayTone = false },
    warning = { label = 'WARNING', defaultPlayTone = false },
    emergency = { label = 'EMERGENCY WARNING', defaultPlayTone = true },
    all_clear = { label = 'ALL CLEAR', defaultPlayTone = false }
}


-- ============================================================
--  GEOGRAPHIC ALERT ZONES
-- ============================================================
-- Configure the geographic areas available for targeted alerts.
-- Each zone is a polygon created from GTA/FiveM vector2(x, y) coordinates. Players
-- inside a selected polygon can receive alerts from templates that have zoned = true.
--
-- You may rename the labels, replace the supplied coordinates, or add additional zones
-- for your own map. Keep every zone id unique. Optional minZ/maxZ values can be added
-- if a zone also needs a vertical limit; without them, the zone is treated as 2D.
Config.AlertZones = {
{
      id = 'los_santos',
      label = 'Los Santos',
      points = {
          vector2(2601.86, -3928.5),
          vector2(-976.28, -3990.62),
          vector2(-2223.65, -3317.48),
          vector2(-3291.51, -302.11),
          vector2(-1733.57, 565.21),
          vector2(3269.61, 3.25),

      }
  },
  {
      id = 'sandy_shores',
      label = 'Sandy and Surrounds',
      points = {
          vector2(3269.61, 3.25),
          vector2(4308.04, 5576.12),
          vector2(1948.29, 5246.54),
          vector2(1002.49, 4302.74),
          vector2(-3115.0, 4398.01),
          vector2(-3712.37, 901.08),
          vector2(-1733.57, 565.21),

      }
  },
  {
      id = 'paleto_bay',
      label = 'Paleto and Surrounds',
      points = {
          vector2(4308.04, 5576.12),
          vector2(1948.29, 5246.54),
          vector2(1002.49, 4302.74),
          vector2(-191.04, 7998.9),
          vector2(4003.92, 6568.81),

      }
  },
}


-- ============================================================
--  TEMPLATE PLACEHOLDER FIELDS
-- ============================================================
-- Placeholders let a template collect incident-specific information without requiring
-- an operator to edit the alert wording itself. Any [PLACEHOLDER] used in a configured
-- template automatically becomes an input field in the EAS composer.
--
-- Placeholder values are saved with the incident, converted to UPPERCASE in alerts,
-- and preserved through upgrades, downgrades, All Clear, and reactivation.
--
-- Add an entry below when you want a friendly label, example, or help text for a
-- placeholder. A placeholder that is not listed here will still work automatically,
-- but its raw placeholder name will be used as the field label.
Config.PlaceholderFields = {
    AREA = {
        label = 'Incident Area / Location',
        placeholder = 'e.g. Vinewood Hills, Lake Vinewood and surrounding streets',
        help = 'Human-readable area shown in the alert. This is separate from the delivery zones below.'
    },
    ROAD = {
        label = 'Evacuation / Access Road',
        placeholder = 'e.g. Senora Freeway',
        help = 'Road or route referenced by the alert message.'
    },
    DIRECTION = {
        label = 'Fire Movement Direction',
        placeholder = 'e.g. north-east / south / west',
        help = 'Direction the fire is currently moving. Placeholder values are rendered in uppercase in alerts.'
    },
    EVAC_DIRECTION = {
        label = 'Evacuation Direction',
        placeholder = 'e.g. southbound / west',
        help = 'Direction residents should travel when instructed to evacuate.'
    }
}

-- ============================================================
--  ALERT TEMPLATES
-- ============================================================
-- Configure the premade alert types available to operators in the EAS composer.
-- You can edit the supplied wording or add your own templates to suit your community.
--
-- Template fields:
--   id            = unique internal identifier; avoid changing it after the template is in use
--   label         = template name shown to operators
--   category      = category used to organise templates in the composer
--   description   = short explanation shown to operators
--   title         = alert type/title shown to recipients
--   defaultIssuer = issuer id from Config.Issuers
--   defaultLevel  = starting severity: advice, warning, or emergency
--   zoned         = true to require one or more geographic delivery zones
--
-- levelTemplates contains the headline and message used for each supported severity.
-- Add [PLACEHOLDER] anywhere incident-specific information is required. The composer
-- will create a separate field for it automatically, preserve the value through later
-- revisions, and insert it into the configured wording in UPPERCASE.
Config.Templates = {
  {
        id = 'custom',
        label = 'Custom Alert',
        category = 'General',
        description = 'Create an alert from scratch.',
        title = 'GENERAL',
        defaultIssuer = 'government',
        defaultLevel = 'emergency',
        zoned = false,
        levelTemplates = {
            advice = { headline = 'PUBLIC ADVICE', message = '' },
            warning = { headline = 'PUBLIC WARNING', message = '' },
            emergency = { headline = 'EMERGENCY WARNING', message = '' }
        }
    },
    {
    id = 'severe_weather',
    label = 'Severe Weather',
    category = 'Natural Hazards',
    description = 'Severe weather warning for dangerous weather conditions.',
    title = 'SEVERE WEATHER',
    defaultIssuer = 'weather',
    defaultLevel = 'warning',
    zoned = false,
    levelTemplates = {
        advice = {
            headline = 'SEVERE WEATHER ADVICE',
            message = 'Severe weather is affecting SAN ANDREAS and may produce dangerous conditions with little warning. Residents should remain indoors where possible, secure loose outdoor items, avoid unnecessary travel, and stay clear of floodwaters and damaged infrastructure. Continue monitoring Emergency Alerts for further information.'
        },
        warning = {
            headline = 'SEVERE WEATHER WARNING',
            message = 'Severe weather is affecting SAN ANDREAS and may produce dangerous conditions with little warning. Residents should remain indoors where possible, secure loose outdoor items, avoid unnecessary travel, and stay clear of floodwaters and damaged infrastructure. Continue monitoring Emergency Alerts for further information.'
        }
    }
},
    {
        id = 'earthquake',
        label = 'Earthquake Warning',
        category = 'Natural Hazards',
        description = 'Statewide earthquake warning.',
        title = 'EARTHQUAKE',
        defaultIssuer = 'weather',
        defaultLevel = 'emergency',
        zoned = false,
        levelTemplates = {
            emergency = {
                headline = 'EARTHQUAKE EMERGENCY WARNING',
                message = 'A significant earthquake has occurred in San Andreas. Strong aftershocks may occur without warning. Stay clear of damaged buildings, downed power lines, unstable structures and other hazards. Follow instructions from emergency services and monitor Emergency Alerts for further information.'
            }
        }
    },
    {
        id = 'tornado_warning',
        label = 'Tornado Warning',
        category = 'Weather',
        description = 'Premade tornado warning.',
        title = 'TORNADO',
        defaultIssuer = 'weather',
        defaultLevel = 'emergency',
        zoned = true,
        levelTemplates = {
            emergency = {
                headline = 'TORNADO EMERGENCY WARNING',
                message = 'A TORNADO EMERGENCY WARNING has been issued for [AREA]. Take shelter immediately in a basement or an interior room on the lowest floor of a sturdy building. Stay away from windows. Remain sheltered until the warning has expired or an all-clear is issued.'
            }
        }
    },
    {
        id = 'tsunami_warning',
        label = 'Tsunami Warning',
        category = 'Weather',
        description = 'Premade tsunami warning.',
        title = 'TSUNAMI',
        defaultIssuer = 'weather',
        defaultLevel = 'emergency',
        zoned = false,
        levelTemplates = {
            emergency = {
                headline = 'TSUNAMI EMERGENCY WARNING',
                message = 'A TSUNAMI EMERGENCY WARNING has been issued for coastal areas of SAN ANDREAS. Move immediately to higher ground and away from beaches, harbours, rivers and other coastal waterways. Do not return until authorities issue an all-clear.'
            }
        }
    },
    {
        id = 'wildfire',
        label = 'Wildfire',
        category = 'Fire & Rescue',
        description = 'Wildfire incident with optional geographic targeting.',
        title = 'WILDFIRE',
        defaultIssuer = 'safd',
        defaultLevel = 'advice',
        zoned = true,
        levelTemplates = {
            advice = {
                headline = 'WILDFIRE ADVICE - READY',
                message = 'A WILDFIRE READY WARNING is current for [AREA]. The fire is moving in a [DIRECTION] direction. Emergency crews are responding. There is currently no immediate threat to populated areas. Residents should remain aware of conditions and monitor Emergency Alerts for further information.'
            },
            warning = {
                headline = 'WILDFIRE WARNING - SET',
                message = 'A WILDFIRE SET WARNING is current for [AREA] and may pose a threat to nearby communities. The fire is moving in a [DIRECTION] direction. Conditions may change with little warning. Residents should remain prepared to leave if instructed, avoid the affected area and continue monitoring Emergency Alerts for updates.'
            },
            emergency = {
                headline = 'WILDFIRE EMERGENCY - GO',
                message = 'A WILDFIRE GO WARNING is current for [AREA] and now poses an immediate threat to life and property. The fire is moving in a [DIRECTION] direction. Evacuate immediately if instructed by emergency services. Do not delay. Follow designated evacuation routes and continue monitoring Emergency Alerts. For those evacuating, you need to leave in a [EVAC_DIRECTION] direction along [ROAD].'
            }
        }
    },
    {
        id = 'hazmat',
        label = 'Hazardous Materials',
        category = 'Fire & Rescue',
        description = 'Hazardous materials release or contamination incident.',
        title = 'HAZARDOUS MATERIALS',
        defaultIssuer = 'safd',
        defaultLevel = 'advice',
        zoned = true,
        levelTemplates = {
            advice = {
                headline = 'HAZARDOUS MATERIALS ADVICE',
                message = 'Emergency crews are responding to a hazardous materials incident in [AREA]. There is currently no immediate threat to the wider community. Avoid the immediate area and monitor Emergency Alerts for further information.'
            },
            warning = {
                headline = 'HAZARDOUS MATERIALS WARNING',
                message = 'A hazardous materials incident is affecting [AREA] and may pose a risk to surrounding areas. Avoid the affected area, close windows and doors where appropriate, and be prepared to shelter in place or evacuate if instructed. Monitor Emergency Alerts for updates.'
            },
            emergency = {
                headline = 'HAZARDOUS MATERIALS EMERGENCY WARNING',
                message = 'A hazardous materials incident in [AREA] poses an immediate threat to life and safety. Shelter in place or evacuate immediately as directed by emergency services. Close windows and doors, switch off outside-air ventilation where possible, and do not enter the affected area.'
            }
        }
    },
    {
        id = 'structure_fire',
        label = 'Structure Fire',
        category = 'Fire & Rescue',
        description = 'Major structure fire affecting the surrounding community.',
        title = 'STRUCTURE FIRE',
        defaultIssuer = 'safd',
        defaultLevel = 'advice',
        zoned = true,
        levelTemplates = {
            advice = {
                headline = 'STRUCTURE FIRE ADVICE',
                message = 'Emergency crews are responding to a significant structure fire in [AREA]. Smoke, emergency vehicles and road closures may affect the surrounding area. Avoid the incident scene and allow emergency crews to work.'
            },
            warning = {
                headline = 'STRUCTURE FIRE WARNING',
                message = 'A significant structure fire is affecting [AREA]. Nearby properties may be at risk and hazardous smoke conditions may be present. Avoid the area and be prepared to leave if instructed by emergency services. Residents affected by smoke should remain indoors where safe.'
            },
            emergency = {
                headline = 'STRUCTURE FIRE EMERGENCY WARNING',
                message = 'A major structure fire in [AREA] poses an immediate threat to nearby life and property. Evacuate the affected area immediately if instructed by emergency services. Do not enter the incident area and keep access routes clear for responding units.'
            }
        }
    }
}
