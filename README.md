# VIU for iPhone

Personal native iOS client in development, targeting iOS 18 or later, including iPhone 16 Pro Max. This is an independent client for an existing VIU account.

## Current implementation

The SwiftUI app reads VIU's home page into native poster shelves, including its continue-watching and favourites sections. It includes filtering of loaded titles, artwork placeholders, loading and failure states, retry, system colours and accessibility labels. Sign-in uses VIU's actual page in WKWebView, sharing WebKit's persistent session with the catalogue reader. No credentials are collected by app code, no CAPTCHA is automated, and no API endpoints are assumed.

Title selection opens native details with artwork, synopsis, genres, year, runtime and rating. Movies have a native AVKit player with a fresh media URL resolved before each playback attempt, bounded waiting for VIU's asynchronous video setup, cancellation and failure handling. TV details include a native season picker and episode rows. Each episode play reloads the series, selects the requested season and episode using the site's existing controls, and verifies player identity plus a changed media source (or an already matching player) before using AVKit. Website access remains available as a fallback.

Movies and TV tabs now implement native catalogue grids, submitted search queries, retry and deduplicated load-more pages. The asynchronous page reader waits for VIU's loading indicator and a stable result set. These features remain unverified on iOS; browser investigation shows that the site can normalise requested pagination back to page one, so load-more stops when no new IDs are returned. Search may include both movies and series, matching VIU's own results.

The Live tab provides a native searchable channel list and resolves a fresh channel stream on selection. If the web player uses a browser-local blob URL, the reader uses VIU's visible VLC handoff link to obtain the HTTPS stream. A web TV guide and website player remain available as fallbacks. Stream credentials are used transiently and are never logged or stored in source.

This is an implementation in progress, not a finished native VIU client. Native saved-list updates, local playback resume and account/session controls are implemented but unverified on iOS. Playback progress is not synchronised with VIU; subtitles, AirPlay and Picture in Picture have not been verified. Readers depend on the observed website markup rather than a documented API. Authentication, rendering, episode selection and native playback on iOS remain unverified.

## Evidence collected

On 24 October 2026 the signed-in home page exposed eight catalogue shelves. The extraction logic returned 161 cards across those shelves, excluding carousel clones (titles may occur in multiple shelves). Cards provide title URLs, artwork, year and optional rating. The movie detail page inspected exposed an MP4 video source with an expiring URL; no stream URL or account credentials are saved in this repository. MP4 presence alone does not prove native playback compatibility or playback progress synchronisation. VIU's app guide describes Android TV support.

JavaScript syntax was checked with `node --check`; extraction selectors were exercised against the signed-in browser DOM. Those checks do not verify a Swift build or iPhone behaviour.

All ten Swift files passed a Tree-sitter Swift syntax parse on Windows, and both YAML configuration files passed YAML parsing. These checks caught and prompted correction of an ambiguous trailing-closure layout. Syntax parsing does not perform Swift type checking, linking or Apple SDK validation; the cloud Xcode build remains required.

Eight Node/jsdom adapter regression tests pass (`npm ci --ignore-scripts`, then `npm test`). Sanitised fixtures exercise clone and duplicate removal, title-link validation, loading versus empty states, stale episode/player identity, HTTPS media filtering, channel extraction and VLC handoff parsing. The cloud workflow runs these tests before compilation. Tests do not connect to VIU or require account credentials.

Detail selectors were also exercised on one movie and one TV series: movie metadata, synopsis, four genres and an HTTPS video source were present; TV metadata and 23 season selectors were present. VIU populated episode lists after a season selection. The TV page can retain an earlier video's source while another season is displayed, so the app intentionally does not treat that source as a selected episode.

Selecting season 1 of the inspected series produced nine episode rows. Selecting episode 1 changed the player label to the selected episode and changed the media source; no media URL was persisted. The native adapter checks those same identity signals and times out instead of playing an unconfirmed source.

The live channel route is `/live-tv`; `/livetv` redirects to a guide. A browser check extracted 1,298 distinct labelled channel links. One channel page exposed a browser-local video source alongside a visible VLC handoff containing an HTTPS HLS stream. No claim has been made that every listed channel is currently available or works with native playback.

## Build on a Mac

1. Install Xcode and XcodeGen from their official sources.
2. Run `xcodegen generate` from `ios/` to create `VIU.xcodeproj`.
3. Open the generated project in Xcode. Select your signing team and a unique bundle identifier.
4. Build for an iPhone 16 Pro Max simulator, then connect your iPhone and run the app on it. Device signing requires an Apple account; follow Xcode's signing prompts.

No Swift compilation, simulator run, device installation or VIU authentication has been verified in the Windows development environment.

The user currently has only a Windows PC and requires zero spending. A macOS build environment remains a delivery dependency, followed by testing on the physical iPhone.

## Free cloud build and sideloading

The manually triggered workflow at `.github/workflows/ios-build.yml` uses a standard GitHub-hosted macOS runner and produces `VIU-unsigned.ipa`. It compiles for a physical iPhone without signing credentials. An unsigned IPA must be signed by the user's sideloading tool before installation; it cannot be installed directly.

The workflow runs only in a public repository, where standard GitHub-hosted runners are free. It skips private repositories to avoid consuming quota or causing overage. It runs only on manual dispatch, cancels superseded builds, times out after 20 minutes and retains its small IPA artifact for one day. No paid runners, hosted Mac subscriptions or Apple Developer Program purchase are needed for this route. A free Apple account sideloading tool normally needs periodic refresh, such as AltStore Classic's seven-day refresh. Keep billing disabled and no payment method attached to ensure any account-wide limit stops usage instead of charging.

The source has not been uploaded to GitHub and this workflow has not been run. There is currently no Git remote or GitHub CLI available in this workspace. The user has now signed into GitHub; cloud build setup is in progress. Publishing source and obtaining access to an existing GitHub account remain prerequisites to executing the free public-repository build. VIU credentials, sessions and signed media URLs must never be included in source or build inputs.

References: [GitHub Actions billing](https://docs.github.com/en/actions/concepts/billing-and-usage), [GitHub billing limits](https://docs.github.com/en/billing/concepts/product-billing/github-actions), [AltStore Windows setup](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows).

## Integration investigation

- Inspect VIU after the user completes sign-in in the existing browser.
- Record actual navigation, catalogue structure, search, details, account features and media behaviour before designing the native screens.
- Establish whether a documented API exists. Otherwise assess the service's permitted integration path and session requirements before implementing one.
- Verify login, CAPTCHA and cookie behaviour on iOS. Browser cookies on this Windows computer do not automatically transfer to an iPhone.
- If the service includes video, verify stream formats, authentication, subtitles and any DRM before selecting a playback implementation.
- Build native features against verified responses, then test on the physical iPhone for accessibility, loading, network failures, session expiry and playback where applicable.
