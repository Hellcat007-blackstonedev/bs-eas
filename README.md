# bs-EAS

A standalone Emergency Alert System for FiveM with configurable alert templates, geographic targeting, optional Quasar Smartphone integration, persistent phone alert history, and automatic chat fallback.

![Screenshot of bs-eas UI to publish emergency alerts](https://imgur.com/CthsC2L.png)

## Features

- Standalone — no QBCore/ESX dependency
- Discord identifier whitelist for EAS operators
- FiveM licence-based recipient tracking
- Advice, Warning, Emergency Warning and All Clear states
- Geographic delivery zones
- Persistent incident history when using Quasar Smartphone
- Automatic chat fallback when Quasar/SQL is unavailable
- Configurable issuers, templates, placeholders and UI branding
- Placeholder values persist between updates and render in uppercase
- Optional critical EAS tone

> [!NOTE]
> Please note that pre-made templates in this script have been included for Night's Natural Disasters. You can remove them if you won't be needing them but I figured I'd leave them in so you know how to structure warning templates.

## Installation

1. Drop `bs-eas` into your resources folder.
2. Edit `config.lua` and add your authorised Discord identifiers.
3. Add this to `server.cfg`:

```cfg
ensure bs-eas
```

For chat-only use, that is all you need.

![Screenshot of the chat based emergency alert](https://imgur.com/CV4moUn.png)

[OPTIONAL] 4. Drop `bs-eas.sql` into your SQL database. (This is for those of you who want to use Quasar smartphone for your alerts.)

> [!TIP]
> The custom alert icons show up in the EAS tablet, but will not show in chat message alerts. They were put in for Quasar Phone to display but obviously if you don't have Quasar phone, you can only use the chat alert feature.

### Quasar Smartphone

> **Important:** Installing and starting Quasar Smartphone is not enough by itself. You **must add the bs-EAS app entry to Quasar's `Config.PhoneApplications`** or the Emergency Alerts app will not appear on the phone.

For phone alerts, start `oxmysql` and `qs-smartphone` before bs-EAS:

```cfg
ensure oxmysql
ensure qs-smartphone
ensure bs-eas
```

bs-EAS automatically creates/updates its SQL tables when phone persistence is enabled.

Then add the Emergency Alerts app to `qs-smartphone/config/main.lua` inside `Config.PhoneApplications`. **This step is required for Quasar phone integration:**

```lua
{
    id = 'emergency_alerts',
    label = 'Emergency Alerts',
    icon = 'emergency_alerts.webp',
    category = 'Utilities',
    sizeMb = 48,
    iframe = {
        url = 'https://cfx-nui-bs-eas/web/app.html'
    }
},
```

The app ID must match:

```lua
Config.Quasar.AppId = 'emergency_alerts'
```

![Screenshot of the Quasar phone alert app with an alert active](https://imgur.com/E5DLb3w.png)

> [!NOTE]
> To get the app icon to work on Quasar's smartphone, follow the file path in `app icon path` and drop the `emergency_alerts.webp` image file in the apps icons path in your Quasar phone resource pathway.


## Delivery Modes

Set `Config.NotificationProvider` to:

- `auto` — Quasar + SQL when available, otherwise chat
- `quasar` — Quasar preferred, with configured chat fallback
- `chat` — FiveM chat only; no SQL required
- `both` — phone and chat

## Permissions

Add authorised staff Discord identifiers in `config.lua`:

```lua
Config.AllowedIdentifiers = {
    'discord:123456789012345678',
}
```

Operators open the console with:

```text
/eas
```

The command can be changed with `Config.Command`.

## Branding

The UI is generic by default. To display your community name in the management console:

```lua
Config.Branding = {
    Enabled = true,
    Name = 'Your Community',
    Subtitle = 'Authorised Communications Console'
}
```

## Notes

Chat-only incidents are kept in memory for the current server session and are not written to SQL. Quasar phone mode uses `oxmysql` so alert history, revisions and recipient state survive restarts.

Developed by **Blackstone Development**.

## Need Help?
You can join our development Discord here: https://discord.gg/dw5KbvB9MJ


## Licence

Copyright © 2026 Blackstone Development. All rights reserved.

This software is provided free of charge for use on FiveM servers. Private modifications are permitted.

**Redistribution, resale, repackaging and unauthorised publication of the source code are prohibited.**

See [LICENSE.md](LICENSE.md) for the full Blackstone Development Software Licence (BDSL) terms.
