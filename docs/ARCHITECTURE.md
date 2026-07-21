# Focusward architecture

## Local-only rule

Focusward must not require or contact a backend. The application bundle contains every visual resource, including the Safari shield page. The native target intentionally contains no networking implementation.

## Enforcement flow

1. The user starts a timed session in the native app.
2. The session end date and normalized domain rules are saved in `UserDefaults`.
3. Focusward asks Safari for its current windows, tabs, and tab URLs through Apple Events.
4. Complete URLs exist only for the duration of a scan. Focusward extracts hostnames and does not log or persist the original URL strings.
5. A matching tab is navigated to the bundled `blocked.html` file.
6. The native timer remains authoritative; the countdown displayed by the HTML file is informational.

## Intentional limits

- Safari only.
- Top-level tab URLs only.
- Reactive after navigation begins, not a network filter.
- Force Quit, process termination, and reboot remain emergency exits.
- No watchdog or login helper.
