# Noodoe Probe

An iOS **read-only diagnostic probe** for KYMCO Noodoe dashboards, designed to investigate how the dashboard actually connects and communicates with an iPhone.

**This app does not send commands or write to any Bluetooth characteristics.** It only discovers, reads, and logs information.

## Features

- **Accessories (ExternalAccessory / iAP2):** Lists connected accessories and their names, manufacturers, models, serial numbers, firmware and hardware versions, and `protocolStrings`. Supports passive, receive-only monitoring of `sunray.control` / `sunray.data`, with incoming bytes logged in hexadecimal.
- **BLE:** Scans for devices (optional name filter; default: `Noodoe`), displays advertisement data (including Solicited Service UUIDs), discovers all services and characteristics after connecting, reads characteristics, and subscribes to notifications. Device Information is read and decoded automatically, including the vendor ID in the PnP ID. The **Find system-connected BLE devices** function can locate devices that are already connected by iOS for ANCS and are no longer advertising.
- **Logs:** All events include timestamps and can be copied or shared. Logs are also saved to the app's Documents directory and can be accessed through the Files app as `probe-*.log`.

## Getting an Unsigned IPA (GitHub Actions)

1. Create a new repository on GitHub and push the contents of this folder, including `.github`.
2. After pushing to `main`, GitHub Actions automatically runs **Build unsigned IPA**. You can also start it manually from the Actions tab using `workflow_dispatch`.
3. When the workflow finishes, download the **`NoodoeProbe-unsigned-ipa`** artifact from the bottom of the workflow run page. Extract it to obtain `NoodoeProbe-unsigned.ipa`.
4. Pushing a tag such as `v1.0` also attaches the IPA to the GitHub Release.
5. Sign and install the IPA using your preferred sideloading tool.

## Recommended Test Procedure (Stock Firmware)

1. **Completely close** the official Noodoe app (swipe it away from the app switcher) to prevent it from competing for the same connection.
2. On your iPhone, open **Settings > Bluetooth**, then pair with and connect to `KYMCO Noodoe`.
3. Open Noodoe Probe and go to the **Accessories** tab. Check whether the dashboard and its protocol strings are listed, then enable passive monitoring if needed.
4. On the **BLE** tab, select **Find system-connected BLE devices** or scan for `Noodoe ANCS`. After connecting, inspect the services. The PnP ID and version strings in Device Information are read automatically.
5. **Be sure to tap Disconnect when testing is complete** so iOS can reclaim the ANCS connection; otherwise, the dashboard may temporarily stop receiving notifications.
6. Share the log file from the **Logs** tab. Before sharing, check whether it contains information you would rather keep private, such as serial numbers or device addresses.

## Known Limitations

- ExternalAccessory only lists accessories that **support protocol strings declared in the app's `Info.plist`**. This app currently declares `sunray.control` and `sunray.data` (identified in the official Noodoe app version 2.2.1). If an accessory is missing, it may use different protocol strings.
- The dashboard may wait for a handshake command from the phone before replying. Passive monitoring therefore may not receive any data.
- When using **Read all readable characteristics**, a characteristic that requires encryption may cause iOS to show a pairing request. Decline that request.
- This project was written in an environment without a Swift compiler and **has not yet been compiled**. If the first build fails, share the GitHub Actions error output so the issue can be fixed.
