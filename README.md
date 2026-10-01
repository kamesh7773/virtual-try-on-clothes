# Mirror

See sports apparel styled on you, then shop it. A Flutter kiosk flow for
DICK'S Sporting Goods, built by Maxaix: take one full-body photo, get it
styled into four looks, and tap a look to open the matching shelf on
dickssportinggoods.com inside the app.

Every screen is native Flutter. The only web page is the retailer's.

## How it works

1. **Intro** (`StyleIntroScreen`) — the model video and STYLE ME. Every
   shopper starts here, and starting again clears the last shopper's session.
2. **Get Ready** (`GetReadyScreen`) — asks for the camera, shows the front
   camera inside a framing guide, MEN'S / WOMEN'S, TAKE MY PHOTO, or pick a
   photo instead. The camera runs only while this screen is on top.
3. **Explore** and **Apparel** — the departments and the shelves. Picking one
   sets who the looks are for (`variant`: men / women / boys / girls) and which
   shelf (`dept`: apparel / shoes). Nothing is generated yet.
4. **Previews** (`LookPreviewsScreen`) — opening this screen is what asks the
   styling service for the four looks, all at once. A look costs a generation,
   so a shopper who takes a photo and leaves costs nothing more than the
   upload. Looks already made for the same shopper and shelf are kept; a look
   that failed is asked for again (the service answers from its cache for one
   it did finish).
5. **The shelf** — tapping a finished look opens the `shop_url` the service
   named for it, in the in-app browser (`WebViewScreen`) with a back control
   from the first page. A look that failed opens the shelf from the app's own
   table (`StyleCatalog.shopUrl`).
   Only the shelves Dick's links exist for lead there: Men's / Women's
   Apparel, Youth Apparel (boys for a men's shopper, girls for a women's) and
   Shoes (always the shopper's own). Under Accessories, Fan Shop and the
   explore departments the looks are made and shown, with no GET THIS STYLE
   button and nothing behind the card (`ApparelTile.shops`).

The session lives in `StyleSessionViewModel` (kept alive across the screens):
the photo, its server id, who the looks are for, and the four `LookPreview`s.

### The styling service

Documented in [docs/app-api.md](docs/app-api.md). All on `mirror.maxaix.com`,
no token:

| Call | What for |
| --- | --- |
| `POST /api/app/photo` (multipart `photo`) | Uploads the snapshot once; answers a `photo_id` good for six hours. Sent as soon as the photo is taken. |
| `POST /api/app/generate` (`photo_id`, `category`, `variant`, `dept`) | One look per call; answers `image` and `shop_url`. Four in parallel, 170 s timeout, up to three tries. A `404 photo_expired` uploads the photo again once. |
| `DELETE /api/app/photo/{id}` | Best effort, when the session resets or the photo is replaced. |

### The in-app browser

`WebViewScreen` is a `webview_flutter` page with no chrome of its own. It
still carries everything the browser learned when the app was browser-first:

- A **loading cover** until the page's first paint, with a 20 s ceiling.
- A **product try-on** on any retailer page that publishes `Product` JSON-LD
  or OpenGraph tags: the product shot is posted to `ApiEndpoints.tryOn` with a
  category (`golf`, `athletics`, `workout`, `sports`), and the result is laid
  over the page. From there, **checkout**: the page's own attribute rows are
  read and asked for, then its Add To Cart is pressed.
- A **local history** of every page opened, with what was tapped to get there,
  and a **flow report** to `ApiEndpoints.history` when a journey ends. The
  payload is in [docs/url-history-payload.md](docs/url-history-payload.md).

## Project layout

```
lib/
├── core/                      # Shared plumbing — no feature knowledge
│   ├── config/env.dart        # Flavor flags from .env.*
│   ├── constants/             # ApiEndpoints, AppAssets (generated)
│   ├── routes/                # Routes, RouteGenerator, typed arguments
│   ├── services/              # Dio client, storage, permissions, dialogs
│   └── theme/  widgets/  utils/  extensions/
├── features/style_me/         # The kiosk flow
│   ├── models/                # StyleCatalog, StylePhoto, LookPreview
│   ├── repositories/          # StyleMeRepository — the styling service
│   ├── view_models/           # StyleSessionViewModel, CameraViewModel
│   └── views/                 # intro, get ready, explore, apparel, previews
├── features/web_view/         # In-app browser, product try-on, checkout, history
└── features/home/             # Browser + history list, for debugging; not on a shopper's path

assets/style_me/               # Tiles, logo, intro video (8.8 MB), backdrop
assets/fonts/                  # Montserrat, Caveat Brush
docs/app-api.md                # The styling service
docs/url-history-payload.md    # The flow report
```

Architecture rules the code is held to live in [.github/rules/](.github/rules/).

## Requirements

| | |
| --- | --- |
| Flutter | Dart SDK `>=3.10.0 <4.0.0` |
| iOS | deployment target 17.0 |
| Device | A real one, with a front camera. The Get Ready screen falls back to the photo picker without one. |

## Getting started

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

Create the env files (below) and run a flavor:

```bash
flutter run --flavor development -t lib/main_development.dart
flutter run --flavor staging     -t lib/main_staging.dart
flutter run --flavor production  -t lib/main.dart
```

For iOS dev there is [run_ios_dev.sh](run_ios_dev.sh). VS Code launch configs
are in [.vscode/launch.json](.vscode/launch.json).

## Configuration

Three gitignored env files drive the flavors: `.env.development`,
`.env.staging`, `.env.production`, loaded by `flutter_dotenv` and read through
[lib/core/config/env.dart](lib/core/config/env.dart). They name the host
the services are on and hold the switches; none of the app's services takes
a token.

```bash
# The same host in every flavor for now. ApiEndpoints adds the paths.
API_BASE_URL=https://mirror.maxaix.com

ENABLE_LOGS=true
ENABLE_ANALYTICS=false
ENABLE_CRASH_REPORTING=false
```

## Tech stack

- **State** — `hooks_riverpod` + `flutter_hooks` + `riverpod_annotation`
  (codegen via `riverpod_generator`)
- **Camera** — `camera` for the snapshot, `image_picker` for the alternative,
  `image` to straighten and shrink it
- **In-app browser** — `webview_flutter` (+ its Android/WKWebView platform
  packages, for camera prompts and inline media)
- **Networking** — `dio` + `pretty_dio_logger`
- **Storage** — `shared_preferences` (history)
- **UI** — `flutter_screenutil`, `flutter_svg`, `video_player`
- **Flavors** — `development` / `staging` / `production`, separate entry
  points and `.env.*` files, per-flavor iOS `.xcconfig`
- **Tooling** — `flutter_gen_runner`, `flutter_launcher_icons`,
  `flutter_native_splash`

## Code generation

After changing any Riverpod-annotated provider, run `build_runner`. After
adding or removing files under `assets/`, it also regenerates the typed
`AppAssets` class in [lib/core/constants/](lib/core/constants/).

```bash
dart run build_runner build --delete-conflicting-outputs
dart run build_runner watch --delete-conflicting-outputs
```

### App icon & splash screen

```bash
dart run flutter_launcher_icons          # from assets/icons/app_logo.png
dart run flutter_native_splash:create    # from assets/icons/app_splash.png
```

## Tests

```bash
flutter test
```

The Style Me tests pin the link table to what the web mirror sent shoppers,
run the session against a scripted styling service (parallel looks, retries,
an expired photo id, a reset mid-flight), and lay the screens out at two phone
sizes with a fake camera and permission platform. The browser tests cover the
bridge messages, navigation rules, product try-on, checkout options and the
history. Nothing touches the network or a real channel.
