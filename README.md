# Intune PPPC Utility

<p align="center">
  <img src="Intune PPPC Utility/Assets.xcassets/AppIcon.appiconset/Intune PPPC Utility-macOS-Default-256x256@1x.png" alt="Intune PPPC Utility icon" width="128">
</p>

A native macOS utility for creating and editing **Privacy Preferences Policy Control (PPPC)** configuration profiles for deployment through **Microsoft Intune** as a Settings Catalog configuration policy.

---

## Overview

PPPC profiles control which applications are granted (or denied) access to protected macOS resources such as the camera, microphone, contacts, calendar, full disk access, and more. Intune manages these policies through its Graph API using a JSON-based configuration policy format — a format that is difficult to author by hand and easy to get wrong.

Intune PPPC Utility provides a native macOS document editor that reads and writes Intune's JSON format directly. Open an existing policy to inspect or modify it, or create a new one from scratch and save it ready to import into Intune.

## Why Use This App Instead of the Intune Console?

The Microsoft Intune admin center lets you configure PPPC settings directly, but it does not validate your entries before saving — and certain combinations that the console happily accepts will cause a profile to silently fail and never deploy to devices.

**Mixing Allowed and Authorization in the same entry** — Each app entry must use *either* the `Allowed` key (true/false) *or* the `Authorization` key (an enum) — never both. The Intune console will let you configure both simultaneously without warning, producing a profile that appears valid but fails schema validation when Intune tries to deliver it, leaving devices permanently stuck in a "Pending" state. Intune PPPC Utility enforces a single permission model per entry and makes the invalid combination impossible to create.

**Allow for Camera or Microphone** — macOS does not permit MDM to pre-approve access to the camera or microphone; these sensors can only be *denied* by policy. The Intune console offers Allow as an option anyway, producing a profile that deploys but has no effect. Intune PPPC Utility only offers Deny for these service types.

**Wrong authorization values for Input Monitoring and Screen Recording** — These service types support only `Deny` and `Allow Standard User to Set System Service` — the full Allow is not available via MDM policy. The console does not enforce this limit. Intune PPPC Utility restricts the available values automatically.

**Missing or invalid code requirements** — A profile entry with an empty or malformed code requirement is delivered by Intune but silently ignored by macOS, because macOS cannot verify the app's identity. Intune PPPC Utility provides a **Read from App Bundle…** button that reads the designated requirement directly from any installed app or command-line tool using `codesign`.

A profile built with Intune PPPC Utility is one that Intune can deliver and macOS can enforce.

## Features

- **24 PPPC service types** — covers every macOS privacy category manageable through an MDM profile, from Accessibility and Camera to System Policy All Files and Apple Events
- **Per-app entries** — configure one or more application entries per service type, each with its own identifier, code requirement, and permission value
- **Apple Events support** — define sender → receiver pairs, with a duplicate button to quickly add multiple receivers for the same sender app; common system receivers (Finder, System Events, etc.) available from a menu
- **TCC database import** — read your Mac's live privacy approvals from TCC.db and import them as a starting point for your profile
- **Mobileconfig import** — open an existing `.mobileconfig` PPPC payload and convert it to Intune JSON format in one step
- **Code requirement reading** — point to any app bundle or command-line tool and let the app read the designated code requirement directly via `codesign`
- **App icon resolution** — section headers display the real app icon and name for configured bundle IDs; command-line tool paths show a terminal indicator instead
- **Round-trip fidelity** — the Intune policy `id`, `createdDateTime`, name, and description are all preserved when opening and re-saving an existing file
- **Automatic updates** — built-in Sparkle update checking

## Requirements

- macOS 15 or later
- Xcode 26 (to build from source)

## Usage

1. **File > New** — creates a blank profile; set the Profile Name and Description in the sidebar
2. Click **+** (Add Service) to add a PPPC service type
3. Select the service in the sidebar, then click **Add App** to add an application entry
4. Fill in the **Identifier** (bundle ID or path) and use **Read from App Bundle…** to populate the Code Requirement automatically
5. **File > Save** — saves as a `.json` file ready to import into Intune

To import an existing profile: click **Import Mobileconfig…** in the toolbar and select a `.mobileconfig` file containing a `com.apple.TCC.configuration-profile-policy` payload.

To build a profile from your Mac's current privacy settings: click **Import from TCC…** and select which approvals to bring in.

## JSON Format

The app reads and writes Microsoft Graph API `deviceManagement/configurationPolicies` JSON. This is the same format produced and consumed by the Intune portal and the Graph API — no conversion step is required before importing.

## License

MIT
