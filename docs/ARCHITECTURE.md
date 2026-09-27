# Focusward architecture

## Local-only rule

Focusward must not require or contact a backend. The application bundle contains every visual resource, including the Safari shield page. The native target intentionally contains no networking implementation.

## Enforcement flow

1. The user starts a timed session, activates Daily Limits, or uses both features.
2. Focusward saves each feature state in `UserDefaults`.
3. Focusward asks Safari for its current windows, tabs, and tab URLs through Apple Events.
4. Complete URLs exist only for the duration of a scan. Focusward extracts hostnames and does not log or persist the original URL strings.
5. A matching tab is navigated to the bundled `blocked.html` file.
6. The native timers remain authoritative. The countdown displayed by the HTML file is informational.

## Daily Limits

Daily Limits are independent from timed sessions. The user can activate either feature or both features.

While Daily Limits are active, every listed website is blocked. Each website has a separate daily break time. A break opens one website for a length that the user selects, up to the break time left for that day.

To start a break, the user selects the length, confirms, and then holds a button for 5 seconds. To turn off Daily Limits, the user confirms and holds the same button. A long press has no keyboard equivalent, so a keyboard-only user cannot complete these steps.

A break uses clock time. Time counts while Safari is in the background, while the Mac sleeps, and while Focusward is not running. A break reserves its full length when it starts. If the user ends a break early, Focusward charges the time used, rounded up to whole minutes.

Focusward resets all break time and ends all breaks at local midnight. Deactivation ends a break in progress and stops enforcement. Deactivation does not clear used break time. Configuration controls are available only while Daily Limits are inactive.

When both features apply to the same website, a timed session has priority. The user cannot start a break on a website that a running session blocks. A session start ends a break on a website that the session blocks, and Focusward charges only the time used.

## Intentional limits

- Safari only.
- Top-level tab URLs only.
- Reactive after navigation begins, not a network filter.
- Force Quit, process termination, and reboot remain emergency exits.
- No watchdog or login helper.
