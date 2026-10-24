# VIU for iPhone

An independent personal iOS client for an existing VIU account. Targets iOS 18 or later, including iPhone 16 Pro Max.

## Current build

The latest verified test build is [GitHub Actions run 5](https://github.com/knemc/viu-ios/actions/runs/40120149228), built from commit `17ccef38c21c4d3d60903369c4500b1e410b636c` on 24 October 2026.

- Physical-iPhone Release compilation passed.
- Eight JavaScript adapter regression tests passed.
- Three native UI tests passed on an iPhone 16 Pro Max simulator running iOS 18.5. They check all five tabs, account controls, confirmation cancellation, landscape window geometry, large text and navigation after local sign-out.
- Exported portrait, landscape and large-text screenshots were inspected. Dark appearance has not been visually verified; the simulator did not apply the requested dark launch preference.
- The generated icon was inspected from the packaged app. Its generator also checks that the monogram was drawn before writing the image.
- Artifact SHA-256 and IPA structure were verified locally: arm64 physical iOS, minimum iOS 18.0, iPhone device family, expected bundle identifier, app icon and all four website adapters.

The unsigned IPA is saved locally at `deliverables/VIU-unsigned.ipa`, with a verification record and simulator screenshots alongside it. Deliverables are excluded from Git. The IPA SHA-256 is `810615c10fefcd2415de916ff13b8eb4cae57a7da9751dbb5e6fa06e06f865b2`.

This is a test build, not a fully verified release. Signing, installation and real VIU login/playback on the physical iPhone remain outstanding.

## Features implemented

- Native Home shelves for VIU recommendations, continue watching and favourites, with poster artwork and title filtering.
- Native Movies and TV catalogue grids, submitted searches and deduplicated load-more results. Load more uses VIU's actual infinite-scroll flow instead of reloading page-number URLs.
- Native title details, synopsis, genres, rating, year and runtime.
- Season selection and episode rows, with episode identity verified before opening native playback.
- AVKit playback with a freshly resolved media link, failure handling and local movie/episode resume positions. Live channels do not resume.
- Native searchable Live TV channels, resolving HTTPS streams from the site's video or visible VLC handoff.
- Favourite and watch-later controls that reload the title page to confirm the site's saved state.
- Account links, local progress clearing and local sign-out. Sign-out switches immediately to an isolated persistent cookie profile, resets all native views and removes old website data in the background.
- System colours, Dynamic Type, VoiceOver labels, landscape support and a reproducible app icon.

VIU's own pages remain available for sign-in/CAPTCHA, account settings, saved lists, the TV guide and playback fallback.

## Integration and verification limits

The app reads the authenticated website's rendered markup rather than using a documented API. Website changes can require adapter maintenance. Credentials and CAPTCHA responses are entered only into VIU's own page. Cookies persist in WebKit's profile data store. Signed media links are resolved transiently and are never included in source or build inputs.

Browser investigation verified eight home shelves, movie/TV metadata, asynchronous season/episode selection, a movie MP4 source and a live HLS handoff. Scrolling the movie catalogue increased the card count from 400 to 800 and advanced VIU's page state; native pagination now follows that interaction. A live channel-list check returned 1,298 distinct labelled channels. Availability of every channel has not been verified.

The simulator tests use a signed-out session and do not prove authenticated catalogue loading, native stream compatibility, saved-list persistence or resume with real media. Those flows require device testing after sideloading. Website progress synchronisation, subtitles, AirPlay and Picture in Picture remain unverified. Native resume is local to this iPhone and is cleared on sign-out. No saved-list changes were performed against the live account during development.

## Free cloud build

The manual workflow `.github/workflows/ios-build.yml` runs only in a public repository, using a standard GitHub-hosted macOS runner. It skips private repositories to avoid consuming private quota or causing overage. It has a 20-minute timeout, cancels superseded runs and retains artifacts for one day. No paid runner, Mac subscription or Apple Developer Program membership is used.

In GitHub, open Actions, select **Build VIU for sideloading**, and choose **Run workflow** on `main`. Download the `VIU-unsigned-ipa` artifact and extract its `.ipa`. The simulator screenshots are a separate artifact.

A sideloading tool must sign the IPA before installation. The free Apple-account route with AltStore Classic normally requires refreshing apps every seven days. The user handles signing/sideloading; no Apple credentials are supplied to the build workflow. Keep billing disabled and no payment method attached if account-wide limits must stop usage rather than charge.

References: [GitHub Actions billing](https://docs.github.com/en/actions/concepts/billing-and-usage), [billing limits](https://docs.github.com/en/billing/concepts/product-billing/github-actions), [AltStore Windows setup](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows), [AltStore refreshing](https://faq.altstore.io/altstore-classic/your-altstore).

## Build on a Mac

1. Install Xcode and XcodeGen from their official sources.
2. From the repository root, run `swift ios/generate-icon.swift`.
3. In `ios/`, run `xcodegen generate` and open `VIU.xcodeproj`.
4. Select your signing team and a unique bundle identifier to install directly, or use the unsigned cloud-build route above.

For the JavaScript regression checks, run `npm ci --ignore-scripts` followed by `npm test`. The native UI target is `VIUUITests`; the cloud workflow selects an available iPhone simulator and runs the `VIU` test scheme.
