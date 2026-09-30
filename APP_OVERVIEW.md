# Mirror (virtual_try_on): App Overview

One place that explains what this app is, how it works, what the client has asked for so far, and what could come next.
Last reviewed: 2026-09-24, branch `development`, commit `3a8c13e`. All 190 tests pass.

> **Naming.** The same app goes by three names. **Mirror** is the current brand (app name, launcher label, wordmark). **LiveLook** is the older name, still used in the README title, the bundle ID `com.livelook.app` and the channel names (`livelook/decart`, `LiveLookBridge`). **virtual_try_on** is the package and folder name.

---

## 1. What the app is

**Mirror** is a Flutter app for iOS and Android, built by Maxaix, that lets a shopper **see sports apparel on themselves before they buy it**. It is built around DICK'S Sporting Goods.

The app contains two try-on engines, but only one of them is in use right now:

| Engine | What it does | Status |
|---|---|---|
| **Web mirror + product try-on** (current) | The app is an in-app browser that opens `https://mirror.maxaix.com/`. From there the shopper goes to a retailer (DICK'S). On any product page the app offers **"Try on"**. It sends the product photo to `mirror.maxaix.com/api/tryon`, shows the resulting image, and can then **add the product to the retailer's cart** for the shopper. | **Live. This is what the app opens on.** |
| **Live camera try-on (Decart)** (earlier) | Front camera plus Decart's realtime `lucy-vton` model. The live video shows you wearing the garment you pick from a strip of 8 bundled garments. | Built and verified on real iPhone and Android devices, but **no button leads to it**. |

The whole app is the browser. It starts on the mirror site with no app bar, address bar or menu. The home screen, the Decart live try-on and the History screen still exist and are routed, but the UI never opens them (see [§3](#3-screens-and-whats-reachable)).

---

## 2. The user journey (what actually happens)

1. **Launch.** A native splash screen, then the in-app browser opens `https://mirror.maxaix.com/` full-screen (edge to edge, because the mirror site handles the notch itself). A **loading cover** (Mirror wordmark, "ONE MOMENT", a sliding bar) hides the blank web view until the page first draws something.
2. **On the mirror site.** The site has four apparel cards: **golf, athletics, workout, sports**. Tapping one ("GET THIS STYLE") does not navigate. Instead the site posts `{"category","url"}` to a JavaScript channel named **`ShopLink`**, and the app opens that retailer URL as a full page.
3. **On the retailer (DICK'S).** The page scrolls and taps like a normal browser. A floating **Back** button appears once you are off the mirror's own site, because the iOS swipe would otherwise leave the whole screen.
4. **On a product page.** The app reads the product (name, image, brand, price) from the page's JSON-LD `Product` data or its OpenGraph tags. A **"Try on" pill** appears at the bottom and shows which of the four categories the product will be sent as.
5. **Tap "Try on".** The app downloads the product photo from the retailer and POSTs it as multipart (`category` + `image`) to `https://mirror.maxaix.com/api/tryon`. The service answers with an **image**, which is shown over the page in a zoomable **TryOnPreview**. Close it with the ✕ or a back gesture and you are back on the same product page.
6. **Tap "CHECKOUT" in the preview.** The app reads the page's attribute rows (Color, Size, Inseam, Width…) and asks the shopper for any value the page hasn't settled, one row at a time, in the page's order. It then presses the site's own **Add To Cart** button. If the add succeeds it opens the cart page. If it fails, it shows the site's own reason, such as "Please Select Size". If the page's controls can't be read, it closes the preview and says: *"Choose your options on the page, then tap Add To Cart."*
7. **In the background.** Every page load is saved to a **local history** along with what was tapped to get there. When a "flow" (mirror → retailer → …) ends, meaning the user returns to the mirror or the app goes to the background, the flow is **POSTed to `mirror.maxaix.com/api/history`**.

---

## 3. Screens and what's reachable

Routes live in [routes.dart](lib/core/routes/routes.dart) and [route_generator.dart](lib/core/routes/route_generator.dart). The initial route is hard-wired to the web view on the mirror.

| Route | Screen | Reachable from UI? | What it is |
|---|---|---|---|
| `/web-view` | [WebViewScreen](lib/features/web_view/views/web_view_screen.dart) | ✅ Start screen | The in-app browser: loading cover, back button, try-on pill, try-on preview, checkout. |
| `/` | [HomeScreen](lib/features/home/views/home_screen.dart) | ❌ | "CHOOSE A MODE": Virtual Try-On / Web View (destination sheet: Mirror, DICK'S) / History. |
| `/try-on` | [TryOnScreen](lib/features/try_on/views/try_on_screen.dart) | ❌ (only from Home) | Decart live camera try-on: permission gate, video, garment strip, start/end session. |
| `/url-history` | [UrlHistoryScreen](lib/features/web_view/views/url_history_screen.dart) | ❌ (only from Home) | Every page the browser opened, newest first. |
| `/url-visit` | [UrlVisitDetailScreen](lib/features/web_view/views/url_visit_detail_screen.dart) | ❌ (from History) | One visit: the tap, timings, URL broken into path and query, "OPEN AGAIN", copy URL. |

To reach the hidden screens again, change `RouteGenerator.initialRoute` back to `Routes.home`, or add an entry point such as a hidden gesture or a debug-only button.

---

## 4. How it works under the hood

### 4.1 In-app browser ([web_view_screen.dart](lib/features/web_view/views/web_view_screen.dart), ~2,350 lines)

- **Destinations** ([web_destination.dart](lib/features/web_view/models/web_destination.dart)):
  - `mirror`: `https://mirror.maxaix.com/`, `promotesFramedLinks: true`, `handlesOwnInsets: true`
  - `dicks_sporting_goods`: `https://www.dickssportinggoods.com/`, with a known `cartUrl` (`OrderItemDisplay?storeId=15108&catalogId=12301&langId=-1`)
- **Injected bridge script.** A large JavaScript string is injected into every page. It posts messages to the `LiveLookBridge` channel, and [web_bridge_message.dart](lib/features/web_view/models/web_bridge_message.dart) parses them. Parsing is strict, because any script on the page can post to the channel. Message types:
  - `tap`: what the user tapped (label, heading, source page), used by history
  - `product`: the product found on the page, or null
  - `options`: attribute groups, add-to-cart availability, cart link
  - `checkout`: `added` / `failed` / `timeout`, plus a reason
  - `painted`: first contentful paint, which lifts the loading cover
- **`ShopLink` channel.** Posted by the mirror site itself. It is accepted only while the browser is on the mirror's host.
- **Navigation rules** ([web_navigation_decision.dart](lib/features/web_view/models/web_navigation_decision.dart)):
  - `tel:`, `mailto:` and `intent://` are blocked.
  - On the mirror, a link that opens in an iframe to another host is lifted out and opened as a real page.
- **Loading cover.** It lifts on the first paint rather than on `onPageFinished`, because retail pages can take 10–20 s to fire `load`. It has a hard limit of 10 s. Load failures ignore cancellations (`NSURLErrorCancelled`, `net::ERR_ABORTED`) so that going back doesn't show a false error.
- **Camera and mic for the page.** The mirror site can ask for camera and microphone. On Android the app asks the OS for permission first, then grants it to the page. Any other permission request (location, MIDI…) is denied.
- **Back handling.** A back gesture first closes an open picker, then the try-on preview, then goes back one page in the browser. On the first page it closes the app.

### 4.2 Product try-on ([try_on_repository.dart](lib/features/web_view/repositories/try_on_repository.dart))

- **Category.** [try_on_category.dart](lib/features/web_view/models/try_on_category.dart) matches keywords against the product title first, then the URL path. The order is golf → sports → workout → athletics. Anything that doesn't match falls back to `sports`.
- **Image upload.** The product image is downloaded (up to 12 MB) and sent as a file rather than a link, because retailer CDNs often block other servers from fetching it.
- **Redirects.** They are followed manually and the form is re-POSTed each time, so a redirect doesn't turn the request into a GET.
- **Response parsing.** The response is read flexibly: `image`, `url`, `tryOnUrl`, `resultUrl`, … or a nested `data` object. A relative path is resolved against `mirror.maxaix.com`.
- **What is sent.** The request carries **only the product photo and a category**. No photo of the user is sent. Whoever appears in the result image is decided by the backend.

### 4.3 Checkout from the preview

- **Reading the options.** [web_purchase_options.dart](lib/features/web_view/models/web_purchase_options.dart) turns whatever headed attribute rows the page has into a list of `WebOptionGroup`s. Different products have different rows: a polo has Color + Size, golf pants add Inseam, shoes are expected to have Width (not yet tested).
- **What's already decided.** A value the page already shows as selected is used as-is. For color, the `?color=` in the URL is also used, because DICK'S does not preselect the swatch from the URL.
- **Pressing buttons.** The script uses a full pointer/mouse/click event sequence, because a bare `click()` doesn't register on DICK'S buttons. Success is detected from the site's own `"callOrigin":"main button","success":"true"` log line.
- **Plans.** [product_try_on_view_model.dart](lib/features/web_view/view_models/product_try_on_view_model.dart) decides between three:
  - `pick`: ask the shopper for the next missing option
  - `add`: every option is settled, so press Add To Cart
  - `guide`: the page's controls can't be read, so hand the shopper back to the page
- **Timeouts.** The script gives up after about 30 s. The app gives up after 40 s.

### 4.4 History and flow reporting

- **Local history.** [url_history_repository.dart](lib/features/web_view/repositories/url_history_repository.dart) stores visits in `shared_preferences`. Each visit records the URL, when it opened, the page title, the load time, any error, the trigger (`direct` / `link` / `element` / `frame` / `viewer` / `inPage`), and what was tapped.
- **Flow reporting.** [history_flow_view_model.dart](lib/features/web_view/view_models/history_flow_view_model.dart) tracks one journey. It reports only flows that reached a retailer. The payload is documented for the backend in [docs/url-history-payload.md](docs/url-history-payload.md).

### 4.5 Decart live try-on (hidden but working)

- **Why a native bridge.** Decart has no Dart SDK. The app wraps the native SDKs through platform channels:
  - Swift: [ios/Runner/Decart/](ios/Runner/Decart/), `decart-ios` 0.6.10 plus LiveKit 2.16.0
  - Kotlin: [android/.../decart/](android/app/src/main/kotlin/com/livelook/app/decart/), `decart-android` 0.7.10
- **Channels.** The MethodChannel `livelook/decart` and the EventChannel `livelook/decart/events` carry commands and events. The video is rendered through the platform view `livelook/decart_video`.
- **Session rules.** Sessions are capped at 60 s for billing, garment switches are debounced by 350 ms, and connecting times out after 45 s.
- **Catalog.** 8 bundled garments are listed in [assets/data/catalog.json](assets/data/catalog.json). Their prompts follow the VTON 3.5 prompting guide.
- **Device requirements.** iOS 17+ and a real device on both platforms. Simulators and emulators don't produce a stream.

---

## 5. Backend and external services

| Endpoint | Method | Auth | Used for |
|---|---|---|---|
| `https://mirror.maxaix.com/` | page | none | The start page (mirror site) |
| `https://mirror.maxaix.com/api/tryon` | POST multipart `category`, `image` | **none** | Product try-on image |
| `https://mirror.maxaix.com/api/history` | POST JSON | **none** | Browsing-flow reports |
| `https://api.decart.ai` + `wss://api.decart.ai` | SDK | `x-api-key` (Decart key) | Live camera try-on only |
| `https://www.dickssportinggoods.com/` | page | the shopper's own session | Retailer, cart |

The Dio interceptor attaches the Decart key **only** to Decart requests (`isDecartRequest`), never to `mirror.maxaix.com`.

---

## 6. Tech stack and architecture

- **Flutter**, Dart `>=3.10.0 <4.0.0`, **MVVM** under `lib/features/<feature>/{models,repositories,view_models,views}`. The rules are written up in [.github/rules/](.github/rules/).
- **State:** `hooks_riverpod` + `flutter_hooks` + `riverpod_annotation`. Providers are code-generated (`*.g.dart`).
- **Web:** `webview_flutter` plus the Android and WKWebView platform packages.
- **Networking:** `dio` + `pretty_dio_logger`, through [api_client.dart](lib/core/services/api_client.dart) and `BaseApiService`.
- **Storage:** `shared_preferences` (history), `flutter_secure_storage` (optional user Decart key).
- **Misc:** `permission_handler`, `connectivity_plus` (`InternetCheckerWidget`), `package_info_plus`, `toastification`, `flutter_screenutil` (design size 375×812), `awesome_notifications` (set up but unused).
- **Tooling:** `build_runner`, `flutter_gen_runner`, `flutter_launcher_icons`, `flutter_native_splash`.
- **Screen:** portrait only, edge to edge, black "stage" theme.

```
lib/
├── core/            config/env.dart, constants/, routes/, services/, theme/, widgets/
├── features/home/        HomeScreen (hidden)
├── features/try_on/      Decart live try-on (hidden)
└── features/web_view/    browser, product try-on, checkout, history  ← the live app
```

---

## 7. Flavors, config, running

| Flavor | Entry point | Bundle / app ID | Name |
|---|---|---|---|
| development | `lib/main_development.dart` | `com.livelook.app.dev` | Mirror Dev (green DEV banner) |
| staging | `lib/main_staging.dart` | `com.livelook.app.staging` | Mirror Staging (orange banner) |
| production | `lib/main.dart` | `com.livelook.app` | Mirror |

The env files are `.env.development`, `.env.staging` and `.env.production`. They are gitignored and **bundled into the app as assets**. They hold these keys: `API_BASE_URL`, `API_WS_BASE_URL`, `API_VERSION`, `DECART_REALTIME_MODEL`, `DECART_API_KEY`, `TOKEN_ENDPOINT`, `ENABLE_LOGS`, `ENABLE_ANALYTICS`, `ENABLE_CRASH_REPORTING`.

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run --flavor development -t lib/main_development.dart
flutter test          # 190 tests, all passing as of 2026-09-24
```

---

## 8. What the client has asked for so far

> There is no written client brief in the repo. This timeline is **reconstructed from git history and project notes**, so please confirm it against the actual client conversations.

| Date | Ask / change | Status |
|---|---|---|
| 2026-09-01 | Port the **LiveLook** Next.js Decart try-on web app to Flutter in strict MVVM, phase by phase. Scope was **try-on only**: no hand gestures, no voice control, no cart, no settings. | ✅ Done |
| 2026-09-02 | Live try-on working on **both iOS and Android** real devices. Garment prompts rewritten to the VTON 3.5 guide. Server-side token endpoint **deferred** (internal testers only). | ✅ Done / token deferred |
| 2026-09-07 | README and demo video (LinkedIn). | ✅ Done |
| 2026-09-11 | **In-app browser** with destinations (Mirror, DICK'S), a **history of every page opened**, and tracking of what the user tapped. | ✅ Done |
| 2026-09-12 | **Try-on on retailer product pages** through `mirror.maxaix.com/api/tryon`, using the 4 categories (golf / athletics / workout / sports). | ✅ Done |
| 2026-09-14 | **Rebrand to "Mirror"**, new icon and splash. App **opens straight into the mirror site** with no chrome. The mirror's cards hand links over through `ShopLink`. Try-on result shown as an image over the page. Branded loading cover. **Flow reporting to `/api/history`**. | ✅ Done |
| 2026-09-15 | Loading cover lifts on first paint (faster). **Checkout from the try-on preview**: pick color / size / inseam, add to cart on DICK'S, open the cart. | ✅ Done (DICK'S only) |
| 2026-09-16 | Camera and mic permission handling inside the web view (for the mirror site's own camera use). | ✅ Done |

---

## 9. Known gaps and risks (fix before a wider release)

1. **🔴 A Decart API key is in `.env.production`.** Right now all three env files, including production, hold a full `dct_*` key. Env files ship **unencrypted inside the IPA/APK**, so anyone can unzip the app and read the key. This contradicts [docs/api-key-security.md](docs/api-key-security.md) and the README, which both say production is blank. Blank it, or build the token endpoint and rotate the key.
2. **No auth on `/api/tryon` and `/api/history`.** Anyone can call them, which is a cost and spam risk on the backend.
3. **Hidden screens.** Home, Decart live try-on and History have no way in from the UI. Either link them or remove them.
4. **Checkout depends on DICK'S page layout.** The script reads DICK'S page structure, so a redesign breaks it. It falls back to "finish on the page". Only DICK'S has a known `cartUrl`. Shoes (Width) haven't been tested.
5. **Failed history sends are dropped.** There is no retry queue. The flow survives only in local history.
6. **DICK'S first-visit interstitial.** The first visit on a fresh install loads a blank bot-check page that costs about 3.4 s once.
7. **Stale docs and names.** The README still says "LiveLook", describes Home as the front door, and says tests cover only try-on. The bundle ID and channels still say `livelook`. [helpers.dart](lib/core/utils/helpers.dart) is empty. `NotificationService` is unused. Network timeouts are 300 s.
8. **Bundled Decart catalog.** The 8 bundled garments can only change through a new build. The plan is in [docs/dynamic-catalog.md](docs/dynamic-catalog.md) and is waiting on a choice of backend.

---

## 10. What more could be added (ideas to offer the client)

**High value, fits what already exists**
- **Try-on with the shopper's own photo.** Today only the product photo is sent, so the result shows whoever the backend chooses. Adding a selfie (captured once and reused) would make it *"see it on me"*.
- **Merge the two engines.** Add a **"Try live"** button on a product page that feeds the product photo into the Decart live camera session as the reference image. The native bridge already accepts any image.
- **Save, share and compare try-ons.** Keep a gallery of past try-on images, share to WhatsApp or Instagram, and view two side by side.
- **Wishlist / "tried on" list** linked back to each product page.

**Retail coverage**
- More retailers, each defined as a `WebDestination` with its cart URL and checkout tuning. Test footwear (Width) and more categories.
- Real-time price, stock and size availability shown in the preview (the options data already carries availability).

**Business and analytics**
- An analytics dashboard on top of `/api/history`: try-on → add-to-cart conversion, most-tried products, drop-off points. Also wire up the `ENABLE_ANALYTICS` / `ENABLE_CRASH_REPORTING` flags to real SDKs (e.g. Firebase Analytics + Crashlytics).
- Push notifications (the package is already installed), e.g. price drops on tried-on items or cart reminders.

**Production readiness**
- A token endpoint for Decart, auth or rate limits on the Maxaix APIs, a retry queue for history sends, a remote garment catalog, user accounts, localization (currently en-US only), and a proper App Store / Play Store release pipeline.
