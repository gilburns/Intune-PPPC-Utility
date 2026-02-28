# Intune PPPC Utility

<p align="center">
  <img src="Intune PPPC Utility/Assets.xcassets/AppIcon.appiconset/Intune PPPC Utility-macOS-Default-256x256@1x.png" alt="Intune PPPC Utility icon" width="128">
</p>

A macOS utility for creating and editing **Privacy Preferences Policy Control (PPPC)** configuration profiles for deployment through **Microsoft Intune**.

---

## Overview

PPPC profiles control which applications are granted (or denied) access to protected macOS resources such as the camera, microphone, contacts, calendar, full disk access, and more. Intune manages these policies through its Graph API using a JSON-based configuration policy format — a format that is difficult to author by hand.

Intune PPPC Utility provides a native macOS document editor that reads and writes Intune's JSON format directly. Open an existing policy to inspect or modify it, or create a new one from scratch and save it ready to import into Intune.

## Features

- **24 PPPC service types** — covers every macOS privacy category manageable through an MDM profile, from Accessibility and Camera to System Policy All Files and Apple Events
- **Per-app entries** — configure one or more application entries per service type, each with its own identifier, code requirement, and permission value
- **Apple Events support** — define sender → receiver pairs, with a duplicate button to quickly add multiple receivers for the same sender app; common system receivers (Finder, System Events, etc.) available from a menu
- **Mobileconfig import** — open an existing `.mobileconfig` PPPC payload and convert it to Intune JSON format in one step
- **Code requirement reading** — point to any app bundle or command-line tool and let the app read the designated code requirement directly via `codesign`
- **App icon resolution** — section headers display the real app icon and name for configured bundle IDs; command-line tool paths show a terminal indicator instead
- **Round-trip fidelity** — the Intune policy `id`, `createdDateTime`, name, and description are all preserved when opening and re-saving an existing file

## Requirements

- macOS 15.6 or later
- Xcode 26 (to build from source)

## Usage

1. **File > New** — creates a blank profile; set the Profile Name and Description in the sidebar
2. Click **+** (Add Service) to add a PPPC service type
3. Select the service in the sidebar, then click **Add App** to add an application entry
4. Fill in the **Identifier** (bundle ID or path) and use **Read from App Bundle…** to populate the Code Requirement automatically
5. **File > Save** — saves as a `.json` file ready to import into Intune

To import an existing profile: click **Import Mobileconfig…** in the toolbar and select a `.mobileconfig` file containing a `com.apple.TCC.configuration-profile-policy` payload.

## JSON Format

The app reads and writes Microsoft Graph API `deviceManagement/configurationPolicies` JSON. This is the same format produced and consumed by the Intune portal and the Graph API — no conversion step is required before importing.

## License

MIT
