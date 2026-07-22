# Focusward

Focusward is a local-only Safari website blocker for macOS. It adds deliberate friction between an impulse and a distracting website without installing a browser extension, running a server, or modifying protected system files.

It runs as your normal macOS user: no administrator password, root helper, paid Apple Developer membership, or hosted service is required. Xcode signs development builds locally with an ad-hoc “Sign to Run Locally” identity.

## Prototype goals

- Monitor open Safari tabs through Apple Events.
- Match only normalized hostnames against a local blocklist.
- Replace blocked tabs with a bundled `blocked.html` shield.
- Keep sessions and settings on the Mac.
- Offer quick durations plus a custom hours-and-minutes session up to 30 days.
- Make ordinary quitting during a session require a cancelable cooldown.

## Privacy boundary

Focusward has no backend, analytics, crash uploader, update checker, or remote assets. Safari provides complete tab URLs to the app, but Focusward extracts the hostname in memory and does not persist or log paths, query parameters, or browsing history.

## Development

Requirements:

- macOS 14 or later
- Xcode 26 or later

### Install like a normal macOS app

Quit Focusward if it is already running, then run:

```sh
./install.sh
```

Focusward builds a universal Release app locally, creates `dist/Focusward.dmg`, and opens the disk image. Drag **Focusward** onto the **Applications** shortcut in that Finder window. The installed app then lives at `/Applications/Focusward.app`, just like a conventional Mac app. Finder may request an administrator password when copying into the system Applications folder.

No Apple Developer account, persistent root helper, backend, or network connection is used. The disk image and app are built and signed locally. Finder's normal one-time administrator authorization may still be required to write to `/Applications`. To update later, pull the latest source, run `./install.sh` again, and replace the existing app when Finder asks.

Use `./install.sh --no-open` to create the disk image without opening Finder. The generated `dist/` directory is ignored by Git and should not be committed.

### Debug, Release, and generated builds

Xcode's **Debug** and **Release** configurations are project settings and should remain in the repository. Debug is used while developing and running tests; Release is optimized for the app placed in the DMG. The actual generated apps and intermediate files under `build/`, `DerivedData/`, and `dist/` are local build products. They are ignored by Git, can be deleted safely, and are recreated when needed.

### Run from Xcode

Open `Focusward.xcodeproj` in Xcode, select **My Mac**, and run the `Focusward` scheme. The first Safari interaction causes macOS to ask whether Focusward may control Safari. Choose **Allow**; if it was previously denied, enable Focusward under **System Settings → Privacy & Security → Automation**.

To try a session:

1. Open Safari.
2. Add a domain such as `youtube.com` in Focusward.
3. Choose a duration and start the session.
4. Visit the domain in any Safari tab. Focusward replaces that tab with its bundled local shield page.

During an active session, ordinary Quit starts a cancelable early-end flow that advances only while the Focusward window is in front. Force Quit, Activity Monitor, process termination, and reboot remain intentional emergency exits.

Command-line build:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project Focusward.xcodeproj \
  -scheme Focusward \
  -configuration Debug \
  -derivedDataPath /tmp/FocuswardDerived \
  build
```

Run the local unit tests with:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project Focusward.xcodeproj \
  -scheme Focusward \
  -derivedDataPath /tmp/FocuswardDerived \
  -destination 'platform=macOS' \
  test
```

This repository is currently an MVP.
