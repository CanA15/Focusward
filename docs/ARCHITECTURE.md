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

Each website has a separate daily allowance. Focusward counts use only when Safari is the foreground application and the website is in the active Safari tab. A background tab does not consume time.

Focusward resets all daily usage at local midnight. Deactivation stops tracking and enforcement. Deactivation does not clear used time. Configuration controls are available only while Daily Limits are inactive.

When both features apply to the same website, a timed session has priority. Time blocked by a timed session does not consume the daily allowance.

## Intentional limits

- Safari only.
- Top-level tab URLs only.
- Reactive after navigation begins, not a network filter.
- Force Quit, process termination, and reboot remain emergency exits.
- No watchdog or login helper.
