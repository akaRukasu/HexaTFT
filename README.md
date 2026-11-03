# Hexa TFT — iPhone companion

Native SwiftUI app, in French, intended to sit beside TFT on PC. Version 0.2 replaces the example-only landing screen with real native composition sheets and adds the full source websites inside the app.

- **Méta**: Blitz compositions, search by champion, style filters, favorites and sorting by average placement or top-4 rate. Source, patch and retrieval date are visible.
- **Composition**: portraits, 4×7 source board, equipped items, frequent item trios, recipes, temporary holders, augments, observed early boards and variants by level/stage. Hexa's general economy notes are labelled separately from observed Blitz data.
- **Partie**: a manually pinned composition and saved stage, with an option to keep the display awake while this screen is visible.
- **Plateau**: copy a source board into the saved personal editor or build your own.
- **Codex**: French champions, items, traits and augments from the same set as the native sheets; champion and item illustrations bundled for offline use.
- **Sources**: complete Mobalytics, MetaTFT and Blitz pages in WKWebView, with back/forward/home/reload, persistent web cookies and retained pages when switching sources. Source pages need a connection and can show their own consent, login or subscription screens.
- **Profil**: manual journal and local top-4 history, accessible from the person icon in Méta.

The supplied gold/emerald logo is the iPhone app icon and the in-app identity.

## Data and updates

`HexaTFT/Resources/meta.json` contains the bundled snapshot. Pull to refresh or use the refresh icon to fetch Blitz's currently published composition data. A validated refresh is saved atomically and remains available after restart; errors keep the last valid data. New-set data with unknown champions are rejected rather than mixing sets. A new release is needed to change the bundled reference and assets.

The visible website patch and Blitz's internal API patch identifier are different fields. Both are shown in their respective context; the app does not silently relabel the underlying statistics. Statistics describe the provider's WORLD / PLATINUM+ ranked sample, not guaranteed outcomes.

Native sheets currently import **Blitz**. Mobalytics and MetaTFT are consulted as full websites inside Hexa, not presented as imported native datasets. Provider-specific access restrictions and outages remain possible.

Refresh the bundled release data with Python 3 + Pillow:

```
python -m pip install pillow
python scripts/update_meta.py
python scripts/prepare_project.py
python -X utf8 scripts/check_content.py
```

The refresh tool discovers the set advertised by Blitz, fetches the French reference and downloads champion/item art into the asset catalog. Review data and asset checks before publishing a new release. No account keys are embedded in the iOS app.

## Build and validation

Open `HexaTFT.xcodeproj` with Xcode, choose the HexaTFT scheme and an iPhone running iOS 17 or newer. Set a signing team to install on a physical iPhone.

GitHub Actions validates bundled data, runs XCTest and the UI smoke test on an iPhone simulator, builds the release device app and uploads:

- `HexaTFT-unsigned`: an **unsigned** IPA. It still requires signing before installation.
- `native-test-results`: the Xcode results bundle.
- `interface-screenshots`: exported UI test attachments.

No automatic game-state detection or Riot account synchronization is implemented. This is an independent project using Riot game content and third-party source data, not an official Riot application.
