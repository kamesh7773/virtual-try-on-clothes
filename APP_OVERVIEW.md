# Mirror (virtual_try_on): App Overview

One place that explains what this app is, how it works, what has been asked for so far, and what could come next.
Last reviewed: 2026-10-01, branch `development`. All 234 tests pass.

> **Naming.** **Mirror** is the brand (app name, launcher label, wordmark). **LiveLook** is the older name, still used in the bundle ID `com.livelook.app` and the browser bridge's channel name (`LiveLookBridge`). **virtual_try_on** is the package and folder name.

---

## 1. What the app is

**Mirror** is a Flutter app for iOS and Android, built by Maxaix, that lets a shopper **see sports apparel styled on themselves before they buy it**. It is built around DICK'S Sporting Goods.

The app is a native kiosk flow (**Style Me**): one photo, four AI-styled looks, and a tap through to the matching shelf on dickssportinggoods.com. **Only the retailer opens in a web view.** Every other screen is Flutter, for performance.

Until 2026-10-01 the same flow ran as a web page (`mirror.maxaix.com`) inside the app's browser, and before that the app had a live-camera try-on engine (Decart). Both are gone: the flow was ported to Flutter screens, and the live engine, its native SDKs, its API key and its garment catalog were removed.

---

## 2. The user journey

1. **Launch.** Native splash, then the **intro**: a looping model video, the DICK'S logo, and a STYLE ME button. Tapping it clears whatever the last shopper left.
2. **Get Ready.** The app asks for the camera and shows the front camera inside a framing guide ("STEP BACK · FULL BODY IN FRAME", "LOOK HERE · STAND NATURALLY"). The shopper picks **MEN'S or WOMEN'S** and taps **TAKE MY PHOTO**, or picks a photo from the library instead. If the camera is blocked there is an OPEN SETTINGS button, and the picker still works.
3. **Upload.** The photo is straightened, shrunk to 1440 px and uploaded once (`POST /api/app/photo`) for a `photo_id` that lives six hours. **Nothing is styled yet.**
4. **Explore → Apparel.** Five departments, then the apparel shelves (Men's or Women's Apparel, Youth Apparel, Shoes, Accessories, Fan Shop). Each choice only sets who the looks are for and which shelf. Youth Apparel styles boys for a men's shopper and girls for a women's; every other row styles the shopper.
5. **Previews.** Opening this screen asks the styling service for **four looks at once** (golf, athletics, workout, sports) for that shopper and shelf. Each card shows a scanning animation until its look arrives (12–50 s), then GET THIS STYLE. The looks keep arriving if the shopper goes back a screen.
6. **The shelf.** Tapping a look opens the `shop_url` the service named for it, in the in-app browser, with a Back control from the first page. The shopper browses DICK'S like a normal site. **Only Men's / Women's Apparel, Youth Apparel and Shoes open DICK'S.** Under Accessories, Fan Shop and the other explore departments the looks are shown without GET THIS STYLE and a tap opens nothing. On a product page the browser still offers its own **product try-on** and **checkout** (see §4.2).
7. **In the background.** Every page the browser opens is saved to a local history with what was tapped to get there. When a journey ends it is reported to `mirror.maxaix.com/api/history`.

---

## 3. Screens and routes

Routes live in [routes.dart](lib/core/routes/routes.dart) and [route_generator.dart](lib/core/routes/route_generator.dart). The initial route is `Routes.styleIntro`.

| Route | Screen | On a shopper's path? | What it is |
|---|---|---|---|
| `/style` | [StyleIntroScreen](lib/features/style_me/views/style_intro_screen.dart) | ✅ Start | Video, logo, STYLE ME. Resets the session. |
| `/style/get-ready` | [GetReadyScreen](lib/features/style_me/views/get_ready_screen.dart) | ✅ | Camera permission, preview, MEN'S / WOMEN'S, capture, picker, privacy card. |
| `/style/explore` | [ExploreScreen](lib/features/style_me/views/explore_screen.dart) | ✅ | Five departments. |
| `/style/apparel` | [ApparelScreen](lib/features/style_me/views/apparel_screen.dart) | ✅ | The shelves. The other adult's row is hidden. |
| `/style/previews` | [LookPreviewsScreen](lib/features/style_me/views/look_previews_screen.dart) | ✅ | The four looks. Opening it generates them. |
| `/web-view` | [WebViewScreen](lib/features/web_view/views/web_view_screen.dart) | ✅ From a look | The retailer, with `initialUrl` set to the shelf. |
| `/` | [HomeScreen](lib/features/home/views/home_screen.dart) | ❌ | Browser destinations and History, for debugging. |
| `/url-history`, `/url-visit` | History screens | ❌ From Home | Every page opened; one visit in full. |

---

## 4. How it works under the hood

### 4.1 Style Me ([lib/features/style_me/](lib/features/style_me/))

- **Session** ([style_session_view_model.dart](lib/features/style_me/view_models/style_session_view_model.dart), kept alive across screens): the photo, its `UploadedPhoto` (id + expiry), `adult` (the MEN'S / WOMEN'S switch), `variant` and `dept` (what the looks are for), the heading, and the four `LookPreview`s with the request they were made for.
- **Lazy generation.** `showLooks()` is called only by the previews screen as it opens. Same shopper and shelf again → nothing is asked; a shelf that changed → all four afresh; a look that failed → that one again. The upload is shared: four looks wait on the one in flight.
- **Retries.** Three tries per look, 2 s then 5 s apart. A `generation_failed` is retried; a validation error is not. A `404 photo_expired` clears the id, uploads the photo again once, and continues. Results that come back after a reset or a new photo are dropped (a generation counter).
- **Links.** The service sends `shop_url` with each look and that wins. [style_catalog.dart](lib/features/style_me/models/style_catalog.dart) keeps the full table the web mirror used (per category × variant × dept) for a look that failed; a test pins all 32 links to what the site sent.
- **Camera.** [camera_view_model.dart](lib/features/style_me/view_models/camera_view_model.dart) is the permission gate; the screen owns the `camera` plugin controller and releases it before the next screen opens and while the app is in the background.
- **Photo.** [style_photo.dart](lib/features/style_me/models/style_photo.dart) bakes the EXIF rotation into the pixels and shrinks to 1440 px off the UI isolate.

### 4.2 In-app browser ([web_view_screen.dart](lib/features/web_view/views/web_view_screen.dart))

- **Destinations** ([web_destination.dart](lib/features/web_view/models/web_destination.dart)): `dicks_sporting_goods` with a known `cartUrl`; `mirror` is still defined for the destination sheet on the debug home screen.
- **Injected bridge.** A script injected into every page posts `tap`, `product`, `options`, `checkout` and `painted` messages to the `LiveLookBridge` channel; [web_bridge_message.dart](lib/features/web_view/models/web_bridge_message.dart) parses them strictly.
- **Product try-on** ([try_on_repository.dart](lib/features/web_view/repositories/try_on_repository.dart)): on a product page, the product shot is posted to `mirror.maxaix.com/api/tryon` with a category and the result is shown over the page.
- **Checkout**: the page's attribute rows are read, missing ones are asked for, and the site's own Add To Cart is pressed; success is read from the site's log line.
- **Back.** A back gesture closes a picker, then the preview, then walks the page history. Opened from a look (`initialUrl` set), the floating Back control shows from the first page and pops the screen once the page history is exhausted.
- **Permissions for the page.** Camera and microphone requests from a site are passed through after the OS grants them; anything else is denied.

### 4.3 History and flow reporting

Unchanged: [url_history_repository.dart](lib/features/web_view/repositories/url_history_repository.dart) stores visits in `shared_preferences`; [history_flow_view_model.dart](lib/features/web_view/view_models/history_flow_view_model.dart) reports a journey that reached the retailer, judged against the mirror's host. Payload in [docs/url-history-payload.md](docs/url-history-payload.md).

---

## 5. Backend and external services

| Endpoint | Method | Auth | Used for |
|---|---|---|---|
| `https://mirror.maxaix.com/api/app/photo` | POST multipart `photo`; DELETE `/{id}` | none | The snapshot, once |
| `https://mirror.maxaix.com/api/app/generate` | POST JSON `photo_id`, `category`, `variant`, `dept` | none | One look per call |
| `https://mirror.maxaix.com/api/tryon` | POST multipart `category`, `image` | none | Product try-on in the browser |
| `https://mirror.maxaix.com/api/history` | POST JSON | none | Browsing-flow reports |
| `https://www.dickssportinggoods.com/` | page | the shopper's own session | Retailer, cart |

The full styling API is in [docs/app-api.md](docs/app-api.md). The Dio client ([api_client.dart](lib/core/services/api_client.dart)) has no base URL and attaches no credentials.

---

## 6. Tech stack and architecture

- **Flutter**, Dart `>=3.10.0 <4.0.0`, **MVVM** under `lib/features/<feature>/{models,repositories,view_models,views}`. Rules in [.github/rules/](.github/rules/).
- **State:** `hooks_riverpod` + `flutter_hooks` + `riverpod_annotation`, code-generated providers.
- **Camera and media:** `camera`, `image_picker`, `image`, `video_player`.
- **Web:** `webview_flutter` plus the Android and WKWebView platform packages.
- **Networking:** `dio` + `pretty_dio_logger`, through `BaseApiService`.
- **Storage:** `shared_preferences` (history).
- **UI:** `flutter_screenutil` (375×812), `flutter_svg`, Montserrat and Caveat Brush bundled.
- **Screen:** portrait only, edge to edge, dark stage.

```
lib/
├── core/               config/env.dart, constants/, routes/, services/, theme/, widgets/
├── features/style_me/  the kiosk flow  ← the live app
├── features/web_view/  browser, product try-on, checkout, history
└── features/home/      browser + history list (debug)
```

---

## 7. Flavors, config, running

| Flavor | Entry point | Bundle / app ID | Name |
|---|---|---|---|
| development | `lib/main_development.dart` | `com.livelook.app.dev` | Mirror Dev (green DEV banner) |
| staging | `lib/main_staging.dart` | `com.livelook.app.staging` | Mirror Staging (orange banner) |
| production | `lib/main.dart` | `com.livelook.app` | Mirror |

The env files `.env.development`, `.env.staging` and `.env.production` are gitignored and bundled as assets. They hold `API_BASE_URL` (the host every service is on — the same in every flavor for now), `ENABLE_LOGS`, `ENABLE_ANALYTICS` and `ENABLE_CRASH_REPORTING`. No secrets ship in the app.

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run --flavor development -t lib/main_development.dart
flutter test
```

---

## 8. What has been asked for so far

> Reconstructed from git history and project notes; confirm against the client conversations.

| Date | Ask / change | Status |
|---|---|---|
| 2026-09-01 | Port the LiveLook live try-on (Decart) to Flutter. | ✅ Done, later removed |
| 2026-09-11 | In-app browser with destinations, a history of every page opened, and tap tracking. | ✅ Done |
| 2026-09-12 | Try-on on retailer product pages through `mirror.maxaix.com/api/tryon`. | ✅ Done |
| 2026-09-14 | Rebrand to **Mirror**. App opens straight into the mirror site. Flow reporting to `/api/history`. | ✅ Done, superseded |
| 2026-09-15 | Checkout from the try-on preview: pick colour / size / inseam, add to cart on DICK'S. | ✅ Done (DICK'S only) |
| 2026-10-01 | **Native Style Me flow.** Only DICK'S opens in the web view, for performance. The flow moves from the mirror site into Flutter screens, on the new app API (`/api/app/*`), with looks generated **only when the previews screen opens** so no generation is spent on a shopper who leaves. | ✅ Done |
| 2026-10-01 | **Remove Decart.** The live engine, native SDKs, API key, env vars, garment catalog and docs. | ✅ Done |

---

## 9. Known gaps and risks

1. **No auth on the Maxaix APIs.** `/api/app/*`, `/api/tryon` and `/api/history` take no token; anyone can call them, and a generation costs money.
2. **The intro video is bundled** (8.8 MB), which is most of the app's asset weight.
3. **`GET /api/app/looks` is not read.** The four looks' labels and taglines are in `StyleCatalog`, because the cards also need images and colours the API does not send. If the server's menu is meant to change, wire it.
4. **Checkout depends on DICK'S page layout.** A redesign breaks it; it falls back to "finish on the page".
5. **Failed history sends are dropped.** No retry queue.
6. **Names.** The bundle ID and the bridge channel still say `livelook`.
7. **Not yet verified on a device since the port:** the live camera preview's mirroring, a real capture, and real looks arriving. The flow is tested with a fake camera and a scripted service.

---

## 10. What more could be added

- **Save, share and compare looks**: a gallery of past looks, share to WhatsApp or Instagram, two side by side.
- **More retailers**, each a `WebDestination` with its cart URL and checkout tuning.
- **Analytics** on top of `/api/history`: look → shelf → add-to-cart conversion, drop-off points. Wire `ENABLE_ANALYTICS` / `ENABLE_CRASH_REPORTING` to real SDKs.
- **Production readiness**: auth or rate limits on the Maxaix APIs, a retry queue for history sends, user accounts, localization (en-US only), a release pipeline.
