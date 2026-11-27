# Stash

An iPhone app that saves links and notes in one tap and shows them as a two-column grid of cards.
Built in SwiftUI from the [Stash product spec](https://claude.ai/artifact/KTaSF3dJjUVCPgAJXyYxsc) and the
[mockup](https://claude.ai/artifact/Tv9UEFav4BVcoQypSST5o7). No Mac needed: GitHub Actions builds, tests and packages it.

## What it does

- **Share Sheet saving.** In Safari, YouTube or any app, tap Share and pick Stash. The Save to Stash card shows the
  title, image and page description, an automatic collection and a Read later choice (Not now, Tonight, Tomorrow, Weekend).
- **Auto summaries.** One or two sentences written on the phone with Apple's Foundation Models (iOS 26 with Apple
  Intelligence). Other phones use the page's own description.
- **Smart collections and tags.** Places, Recipes, Reading and Shopping, picked from the page's structured data,
  the site and its words. You can move an item by hand (Stash keeps your choice) and add your own tags.
- **Read later.** Reminders as local notifications that open the item; unread items get a blue dot and a count on the
  filter button and the app icon.
- **Places.** A map with a pin, the name and address, and Open in Maps.
- **Offline copy.** The article text is saved with the link and opens in a serif reader with a text size control,
  even in Airplane Mode. Search covers it too.
- **Notes** with checklists share the grid, search and tags.

## Layout

| Path | What |
| --- | --- |
| `Packages/StashKit` | Models, HTML metadata and article extraction, summaries fallback, collection classifier, reminders, JSON store and Share inbox. Unit tested with `swift test`. |
| `Stash/` | The SwiftUI app. |
| `StashShare/` | The Share Extension. |
| `Shared/` | Theme, Liquid Glass helpers and the Save to Stash card, used by both. |
| `StashUITests/` | UI tests that tour every screen and save screenshots. |
| `project.yml` | XcodeGen spec; CI generates `Stash.xcodeproj` from it. |

The app and the extension share data through the App Group `group.com.altmihai31.stash`. The extension only drops a
small file in `Inbox/`; the app picks it up the next time it opens and finishes the work (summary, collection,
offline copy, map). If the App Group does not survive signing, the extension hands the save to the app through
`stash://save?...` instead, so saving still works.

## CI

`.github/workflows/ios.yml` runs on every push on a macOS runner:

1. `swift test` for StashKit.
2. XcodeGen, then the UI tests in the iPhone Simulator with demo data (`-StashDemo YES`, no network).
   Screenshots are uploaded as the `screenshots` artifact and pushed to the `ci-screenshots` branch.
3. A Release build for devices with signing off, ad-hoc signed with the App Group entitlements, zipped as
   `Stash.ipa` and uploaded as the `Stash-ipa` artifact. Builds of `main` also go to the `latest` pre-release.

## Install on an iPhone from Windows

1. Open the latest run under **Actions**, download the **Stash-ipa** artifact and unzip it (or take `Stash.ipa`
   from the `latest` release once this is merged).
2. Open Sideloadly, connect the iPhone, drop in `Stash.ipa`, enter your Apple ID and press Start.
3. On the iPhone: Settings > General > VPN & Device Management, trust your Apple ID. Turn on Developer Mode if asked.
4. In Safari, tap Share, swipe to the end of the app row, tap More and turn on Stash.

With a free Apple ID the app expires after 7 days (reinstall the same way, your data stays) and it uses two of the
ten app IDs a free account may register per week, one for the app and one for the Share Extension. If Sideloadly
complains about the extension, the app still works without it: paste links with the + button.
