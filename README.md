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
