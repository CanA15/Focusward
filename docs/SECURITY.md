# Security and privacy notes

## What Focusward can see

During an active session, Safari supplies Focusward with the complete address of every open Safari tab. Focusward extracts the hostname in memory so it can compare it with the blocklist. It does not log or persist the complete addresses, paths, query parameters, page titles, or page contents.

## What Focusward stores

Focusward stores only the normalized blocked domains, session end time, and optional early-end cooldown time in the app's local `UserDefaults` container. The bundled shield is a local HTML file with a restrictive Content Security Policy and no remote assets.

## Permissions and process boundary

- Focusward never runs as root and does not install a privileged helper.
- It does not edit `/etc/hosts`, DNS settings, proxies, firewall rules, or protected system files.
- macOS asks for Automation permission because Focusward reads and replaces Safari tab addresses.
- The current prototype is not App-Sandboxed while the Safari Apple Event integration is being validated. It still runs only with the signed-in user's permissions, and its source contains no general file-scanning or networking implementation.

## Enforcement limits

Focusward is a deliberate-friction tool, not a tamper-proof security boundary. It checks Safari approximately twice per second. A blocked page can therefore begin loading briefly before Safari is navigated away; navigating away normally stops that tab's audio and video. Picture-in-Picture, downloads already started, Safari updates, and Private Browsing behavior need hands-on regression testing before a stable release.

Force Quit, Activity Monitor, Terminal process termination, and reboot remain recovery paths. Deleting the app's local preferences or changing the system clock can also weaken a session. These limits are intentional consequences of staying free, local, unprivileged, and extension-free.
