# LiveLook — Virtual Try-On

Real-time virtual try-on for Flutter. Point the camera at yourself, pick a
garment from the strip, and the live video feed comes back wearing it — no
photo upload, no render step, no waiting.

The stream is produced by the [Decart](https://decart.ai) realtime `lucy-vton`
model. Decart ships no Dart SDK, so the app talks to the native Android and
iOS SDKs across a platform channel and renders the returned frames in a
platform view.

## Demo

[![LiveLook virtual try-on — watch the demo](assets/images/thumbnail.png)](https://lnkd.in/p/dak9WnFP)

▶️ **[Watch the demo on LinkedIn](https://lnkd.in/p/dak9WnFP)**

## How it works

The app opens straight into the in-app browser on the mirror
(`RouteGenerator.initialRoute`) — no menu in front of it, and no chrome of its
own around it: no app bar, no address, no back control, since the site draws
one itself. A back gesture walks the page history and closes the app from the
first page. While a page is on its way a `WebLoadingCover` sits over the
view, which otherwise paints nothing at all for the seconds a retailer's page
takes to arrive — an empty screen that reads as a broken app rather than as
waiting. It carries the wordmark and a segment shuttling along a track rather
than a progress bar, because the web view reports no progress to fill one
with, and it holds still for a user who has asked for less motion. It lifts on
`onPageFinished`, on a failure, or after 20 seconds, whichever comes first.

A failure here means the page is dead, not that a load was thrown away:
`isPageFailure` drops the cancellations both platforms report down the same
callback (`NSURLErrorCancelled`, `net::ERR_ABORTED`) and any error naming a
page other than the one now loading. Going back from a retailer cancels
whatever that page still had in flight, and without this the app answers a
successful back with a "try again" screen over a page that loaded fine. Once the browser has followed a link off the
destination's own site (`WebDestination.isOwnSite`), a `WebBackButton` floats
over the page —
on iOS the swipe gesture walks the app's routes, not the page history, so a
retailer navigated several pages deep would otherwise have no way back. The other screens — **Virtual Try-On**, the live Decart mirror
described below, and the browsing **History** — keep their routes and the home
screen that lists them, but nothing opens on them yet.

The mirror's four apparel cards hand their retailer link straight to the app:
tapping one navigates nowhere and posts `{"category","url"}` to a JavaScript
channel the site names **`ShopLink`**, which the app parses into a `ShopLink`
and opens as a full page. Honoured only while the browser is on the
destination's own site — every script on every page can reach that channel.

Before the site did that, a card opened the retailer inside an embedded
browser of its own, which rendered blank. A destination marked
`promotesFramedLinks` — the mirror is — still has such framed links turned
into real page loads, as a fallback for a page served from cache. That too
only applies on the destination's own host (`promotesFramedLinksOn`): once the
browser has followed a link out, the frames belong to the site it landed on. Every page the browser opens is written
silently to a local history. A page injected
into every site reports what the user tapped — the words on the card, the
heading above it, and the page it happened on — so each row records not just
the URL and its timings but the tap that led there. Tapping a row opens the
full record: the tap, the timings, and the URL broken into path and query.

A **flow** — one journey from the mirror out to a retailer — is reported to
`ApiEndpoints.history` when it ends: when the user returns to the mirror to
begin another, or when the app goes to the background. `HistoryFlowViewModel`
follows the journey by visit id and reads the rows back from the history at
the end, so each one carries the title and timings it only has once its page
finished. A flow that never left the mirror is dropped rather than sent —
somebody looking at the front page is not a journey — and a send that fails
leaves its reason on the state without costing the local history anything.
The envelope is documented for the backend in `docs/url-history-payload.md`.

On a page that publishes a product — its `Product` JSON-LD or its OpenGraph
tags — the browser offers a **try-on** over it. The page is read on a timer,
on every bridge injection, and the bridge itself goes in partway through the
load (`_bridgeProgress`) as well as on `onUrlChange`, so neither a page whose
load event is minutes away nor a site that navigates without loading is left
unread. A scan that finds nothing on the page the offer was already made for
is treated as the page still filling itself in; only leaving the page takes
the offer away. Tapping downloads the product
shot from the retailer and posts it to `ApiEndpoints.tryOn` as multipart form
data, alongside the `category` the product's name resolves to — one of `golf`,
`athletics`, `workout`, `sports`. The service answers with an image, which a
`TryOnPreview` lays over the page: zoomable, closed by the cross in its corner
or by a back gesture, and leaving the user on the product page they were
reading rather than navigating them off it. That endpoint is a full URL on a
different host from Decart's, so the Decart key is not attached to it
(`isDecartRequest`).

```
 Flutter (Dart)                  Platform channels              Native
┌──────────────────────┐        ┌──────────────────┐        ┌────────────────────┐
│ CatalogViewModel     │        │ livelook/decart  │        │ DecartPlugin       │
│  reads catalog.json  │        │  (MethodChannel) │───────▶│  Kotlin  /  Swift  │
│                      │        │                  │        │                    │
│ SessionViewModel     │───────▶│ .../events       │◀───────│ Decart SDK session │
│  owns the session    │        │  (EventChannel)  │        │  camera + WebRTC   │
│                      │        └──────────────────┘        │                    │
│ CameraViewModel      │        ┌──────────────────┐        │ DecartVideo        │
│  permission gate     │        │ PlatformView     │◀───────│  PlatformView      │
└──────────────────────┘        └──────────────────┘        └────────────────────┘
```

- **`DecartSessionService`** is a deliberately dumb wrapper over the method
  channel — it marshals arguments and surfaces errors, and holds no state.
- **`SessionViewModel`** owns everything the UI reacts to: connection status,
  the busy flag, and error messages pushed up from the SDK.
- **Sessions are capped at 60 seconds** (`SessionViewModel.autoDisconnectSeconds`)
  because a live session bills for its whole duration.
- **Garment switches are debounced 350 ms** so swiping through the strip
  uploads only the garment the user settles on, not every one they pass.
- **Connects time out after 45 s** — without that ceiling a stalled handshake
  pins the UI in `connecting`, where the only recovery is restarting the app.

## Project layout

```
lib/
├── core/                        # Shared plumbing — no feature knowledge
│   ├── config/env.dart          # Flavor-aware .env loading
│   ├── services/                # Api client, storage, permissions, dialogs
│   ├── routes/  theme/  widgets/  utils/  extensions/
│   └── constants/assets.gen.dart
├── features/home/                             # Front door: try-on or browser
│   └── views/                                 # home_screen + option tile
├── features/try_on/
│   ├── models/garment_model.dart
│   ├── repositories/catalog_repository.dart
│   ├── services/decart_session_service.dart   # Method/event channel bridge
│   ├── view_models/                           # camera / catalog / session
│   └── views/                                 # try_on_screen + widgets
└── features/web_view/                         # In-app browser
    ├── models/                                # Destinations, visits, taps
    ├── repositories/url_history_repository.dart  # History in shared prefs
    ├── utils/visit_format.dart                # Dates, durations, outcomes
    ├── view_models/url_history_view_model.dart
    └── views/                                 # browser, history, one visit

android/app/src/main/kotlin/com/livelook/app/decart/   # Kotlin bridge
ios/Runner/Decart/                                     # Swift bridge
assets/data/catalog.json                               # 8 bundled garments
assets/garments/                                       # their images
```

Architecture rules the code is held to live in [.github/rules/](.github/rules/) —
one file each for the core layer, view models, views, data layer, services, and
Riverpod codegen.

## Requirements

| | |
| --- | --- |
| Flutter | Dart SDK `>=3.10.0 <4.0.0` |
| Android | `com.github.DecartAI:decart-android:0.7.10` (JitPack) |
| iOS | `DecartSDK` via Swift Package Manager, deployment target **17.0** |
| Credentials | A Decart API key (`dct_*`) — see [Configuration](#configuration) |

Both platforms need a real device with a camera. Simulators and emulators
won't produce a usable stream.

## Getting started

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

Then create the env files (see below) and run a flavor:

```bash
flutter run --flavor development -t lib/main_development.dart
flutter run --flavor staging     -t lib/main_staging.dart
flutter run --flavor production  -t lib/main.dart
```

For iOS dev there's a helper script: [run_ios_dev.sh](run_ios_dev.sh). VS Code
launch configs are in [.vscode/launch.json](.vscode/launch.json).

## Configuration

Three gitignored env files drive the flavors: `.env.development`,
`.env.staging`, `.env.production`. Each is loaded by `flutter_dotenv` and read
through [lib/core/config/env.dart](lib/core/config/env.dart).

```bash
# ─── Decart ───────────────────────────────────────────────────────────
API_BASE_URL=https://api.decart.ai
API_WS_BASE_URL=wss://api.decart.ai
API_VERSION=v1

# Realtime virtual try-on model.
DECART_REALTIME_MODEL=lucy-vton-latest

# Long-lived Decart API key. ONLY set this in development/staging — it can
# mint client tokens, so it must never ship in a release binary.
DECART_API_KEY=dct_your_key_here

# Backend that mints ephemeral client tokens (POST -> {apiKey, expiresAt}).
# Required in production, optional in development.
TOKEN_ENDPOINT=

ENABLE_LOGS=true
ENABLE_ANALYTICS=false
ENABLE_CRASH_REPORTING=false
```

`SessionViewModel.prepare()` resolves a key in this order: a user-supplied key
in `SecureStorageService`, then `Env.decartApiKey`. Production is meant to
leave `DECART_API_KEY` blank and go through `TOKEN_ENDPOINT` instead.

> ⚠️ **A bundled `.env` is not encrypted.** Anyone with the APK or IPA can
> unzip it and read a `dct_*` key in plain text — no reverse engineering
> needed, and that key is a full account credential. The token-endpoint fix is
> scaffolded but unwired; the risk is currently accepted for internal testers
> only. Read [docs/api-key-security.md](docs/api-key-security.md) before
> shipping any build that leaves that group.

## The garment catalog

Eight garments ship in the bundle: [assets/data/catalog.json](assets/data/catalog.json)
holds the metadata, `assets/garments/` holds the images (~2.1 MB total).

Each entry pairs a photo with the prompt sent to the model:

```json
{
  "id": "m1",
  "name": "Textured Knit Polo",
  "type": "polo",
  "description": "Dark green textured knit polo with cream contrast collar and sleeve trim",
  "prompt": "Substitute the upper body garment with a dark green textured knit polo shirt with an open cream V-neck collar, cream short sleeve cuffs, and a small cream script logo on the chest",
  "image": "assets/garments/polo-green-textured.jpg"
}
```

Prompt wording matters more than the image does — the model leans on it
heavily, so garment prompts are written to be specific and consistent

Bundling keeps the catalog working with no network and no credentials.
Moving it server-side touches four files and is planned but not started —
see [docs/dynamic-catalog.md](docs/dynamic-catalog.md).

## Tech stack

- **State** — `hooks_riverpod` + `flutter_hooks` + `riverpod_annotation`
  (codegen via `riverpod_generator`)
- **Flavors** — `development` / `staging` / `production`, separate entry
  points and `.env.*` files, per-flavor iOS `.xcconfig`
- **Networking** — `dio` + `pretty_dio_logger`
- **Storage** — `flutter_secure_storage`, `shared_preferences`
- **UI** — `flutter_screenutil`, `flutter_svg`, `toastification`,
  `loading_animation_widget`
- **In-app browser** — `webview_flutter` (+ its Android/WKWebView platform
  packages, for camera prompts and inline media)
- **Notifications** — `awesome_notifications`
- **Utilities** — `connectivity_plus`, `permission_handler`, `package_info_plus`
- **Tooling** — `flutter_gen_runner`, `flutter_launcher_icons`,
  `flutter_native_splash`

## Code generation

After changing any Riverpod-annotated provider, run `build_runner`. After
adding or removing files under `assets/`, run `flutter_gen` to regenerate the
typed `AppAssets` class in [lib/core/constants/](lib/core/constants/).

```bash
# Riverpod providers + any other build_runner-based generators
dart run build_runner build --delete-conflicting-outputs

# Watch mode (regenerates on file changes)
dart run build_runner watch --delete-conflicting-outputs

# Asset class (AppAssets) — flutter_gen
dart run flutter_gen_runner
# or simply:
fluttergen -c pubspec.yaml
```

### App icon & splash screen

```bash
# Regenerate launcher icons from assets/icons/app_logo.png
dart run flutter_launcher_icons

# Regenerate native splash from assets/icons/app_splash.png
dart run flutter_native_splash:create

# Remove the native splash
dart run flutter_native_splash:remove
```

## Scaffolding a feature — VS Code task

A VS Code task creates the MVVM folder structure for a new feature so you
don't hand-make the folders every time.

1. Command Palette → **Tasks: Run Task**
2. Select **Flutter: Create MVVM Feature**
3. Pick the base folder (`lib/features`)
4. Enter the feature name (e.g. `auth`, `home`, `profile`)

This creates:

```
lib/features/<feature_name>/
├── model/
├── view/
├── viewmodel/
└── repository/
```

The task is defined in [.vscode/tasks.json](.vscode/tasks.json).

## Tests

```bash
flutter test
```

Coverage sits on the try-on feature: the catalog repository and view model,
the camera permission view model, the session view model, and a widget test
over the screen itself. Tests swap in a
[fake asset bundle](test/support/fake_asset_bundle.dart) and a fake permission
platform rather than touching real channels.

## Known gaps

| Item | Status |
| --- | --- |
| [API key ships inside the bundle](docs/api-key-security.md) | Open — deferred for internal testers, must be fixed before any external build |
| [Remote garment catalog](docs/dynamic-catalog.md) | Proposed — blocked on picking a backend |
