# ESO Addon Manager

A simple PowerShell-based tool to download and install popular Elder Scrolls Online (ESO) addons — complete with dependency resolution and OneDrive support.

![ESO](https://img.shields.io/badge/Game-Elder%20Scrolls%20Online-blue?logo=windows)

---

## ✅ Features

- ✅ Install multiple addons in one click via a graphical list
- 🔁 Automatically resolves and installs required dependencies
- 💾 Works with standard and OneDrive-based `Documents` folders
- 🧼 Cleans up temporary files after install
- 🎯 Downloads directly from trusted ESOUI CDN

---

## 🖥 Requirements

- Windows 10 or 11
- PowerShell 5.1 or later (included by default)
- Internet connection
- Execution policy: `RemoteSigned` or `Bypass`

---

## 🚀 Quick Start

1. 📥 [Download ESO-AddonManager.ps1](https://raw.githubusercontent.com/YOUR_USERNAME/ESO-Addon-Manager/main/ESO-AddonManager.ps1)
2. Right-click the file → **Run with PowerShell**

If you see a security warning, open PowerShell and run:

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

---

## 🧩 Addons Included

The script includes both main addons and their libraries:

🗺 Main Addons
- Dolgubon's Lazy Writ Crafter
- HarvestMap
- SkyShards
- Votan’s MiniMap

📚 Libraries (Dependencies)
- LibAddonMenu / LibAddonMenu-2.0
- LibMainMenu-2.0
- LibMapPins-1.0
- LibGPS
- LibMapPing
- LibChatMessage
- LibDebugLogger
- LibAsync
- LibMapData
- LibLazyCrafting
- LibHarvensAddonSettings
- CustomCompassPins
- MapPins

Addons are downloaded from ESOUI.com, and the list can be customized easily in the script.

---

## 💡 How It Works

The script presents a GUI for addon selection.
It downloads and extracts selected addons.
It parses .addon files for required libraries.
If a required library is listed and included in the script, it installs it automatically.
Extracts everything into your ESO AddOns folder (including OneDrive-based Documents folders)

---

## 🔒 Safety & Permissions

The script does not modify game files
It writes only to:
%USERPROFILE%\Downloads\ESO-MM (for zip downloads)
Documents\Elder Scrolls Online\live\AddOns (for addon installs)
No elevation (admin) required

---

## 🛠 Developer Notes

You can easily edit the $Addons array to add or remove mods.
Script uses PowerShell's Out-GridView to select addons.
Handles DependsOn, PCDependsOn, and ConsoleDependsOn tags in .addon files.

---

## 📬 Feedback or Issues?

Have a problem or want to suggest an addon? Open an issue or submit a pull request.

---

## 📄 License

This project is licensed under the MIT License.

---

## 🙌 Credits

Addon ZIPs are downloaded directly from the official ESOUI CDN.
All credit for the addons goes to their respective authors.
