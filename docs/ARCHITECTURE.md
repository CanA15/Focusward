# Focusward architecture

## Local-only rule

Focusward must not require or contact a backend. The application bundle contains every visual resource, including the Safari shield page. The native target intentionally contains no networking implementation.

## Enforcement flow

1. The user starts a timed session, activates Daily Limits, or uses both features.
2. Focusward saves each feature state in `UserDefaults`.
3. Focusward asks Safari for its current windows, tabs, and tab URLs through Apple Events. These requests run on a background queue, so a slow Safari reply or a permission prompt does not block the user interface.
4. Complete URLs exist only for the duration of a scan. Focusward extracts hostnames and does not log or persist the original URL strings.
5. A matching tab is navigated to the bundled `blocked.html` file.
6. The native timers remain authoritative. The countdown displayed by the HTML file is informational.

## Confirm and hold

To end a timed session early, the user confirms and then holds a button for 5 seconds. Daily Limits use the same steps to start a break and to turn off Daily Limits. A long press has no keyboard equivalent, so a keyboard-only user cannot complete these steps.

While a timed session or Daily Limits are active, an ordinary quit is refused. A logout, restart, or shutdown can still quit Focusward.

## Daily Limits

Daily Limits are independent from timed sessions. The user can activate either feature or both features.

While Daily Limits are active, every listed website is blocked. Each website has a separate daily break time. A break opens one website for a length that the user selects, up to the break time left for that day.

To start a break, the user selects the length, confirms, and then holds a button for 5 seconds. To turn off Daily Limits, the user confirms and holds the same button.

A break uses clock time. Time counts while Safari is in the background, while the Mac sleeps, and while Focusward is not running. A break reserves its full length when it starts. If the user ends a break early, Focusward charges the time used, rounded up to whole minutes.

Focusward resets all break time and ends all breaks at local midnight. Deactivation ends a break in progress and stops enforcement. Deactivation does not clear used break time. Configuration controls are available only while Daily Limits are inactive.

Each rule also applies to its subdomains, so Daily Limits do not accept two rules that cover the same hostnames. For example, `m.youtube.com` cannot be added when `youtube.com` is in the list.

When both features apply to the same website, a timed session has priority. The user cannot start a break on a website when a session rule overlaps the Daily Limits rule. A session start ends a break on a website when a session rule overlaps that website's rule, and Focusward charges only the time used. A website added during a session has the same effect.

During a timed session, the user can add websites to the session list. The user cannot remove websites until the session ends.

## Intentional limits

- Safari only.
- Top-level tab URLs only.
- Reactive after navigation begins, not a network filter.
- Force Quit, process termination, and reboot remain emergency exits.
- No watchdog or login helper.
