# Shotlist: Mirror launch, 15 s, 16:9

- **Format:** 1920×1080, 60 fps, 15.0 s
- **Style:** follows [style_guide.md](style_guide.md), which takes its grammar from the wabi launch film
- **Message:** one photo, four looks of you, and a tap to shop them at DICK'S
- **Tagline:** "See it on you. Then shop it."

## Assets

All imagery is Mirror's own.

**How the screens are made.** The screenshots in `refs/app_screens/` are a
**UI reference only**. Every app screen is rebuilt in HTML at full
resolution, using Montserrat and the images from `assets/style_me/`. The
rebuilt screens have no status bar, no DEV ribbon and no blur.

**The shopper.** The shopper is a **fictional person**; no real face appears
anywhere in the film.
- **Source photo:** `refs/shopper/source.jpg`, one full-body photo of a
  made-up man, supplied by you.
- **Looks:** the four looks are made by the real Mirror service
  (`POST /api/app/photo`, then `POST /api/app/generate` for golf, athletics,
  workout and sports, with variant `men` and dept `apparel`). They are saved
  at full size to `refs/shopper/look_<category>.jpg`.
- **Golf try-on:** the full-bleed shot in S6 uses `look_golf`.
- **Get Ready camera:** the camera view in S3 uses the source photo, mirrored.

**Brands.** DICK'S and the marks on the products are used as-is, as cleared
by you.

The screenshot keys below now name the screen each rebuild is modelled on.

| Key | File | Used in |
| --- | --- | --- |
| `GET_READY` | `refs/app_screens/12_get_ready_mens.png` | S3 |
| `LOADING` | `refs/app_screens/08_loading_mirror.png` | S3 |
| `GRID` | `refs/app_screens/03_looks_grid_mens.png` | S5, S6 (and crops of its four tiles) |
| `TRYON` | `refs/app_screens/02_tryon_result_golf_checkout.png` | S6 |
| `PRODUCT` | `refs/app_screens/01_product_page_tryon_bar.png` | S7 |
| `CART` | `refs/app_screens/10_cart.png` | S7 |
| `DICKS_LOGO` | `assets/style_me/dicks_logo.svg` | S9 |
| Wordmark | "Mirror" in Inter Display 600, −0.02 em, matching `MirrorWordmark` | S1, S9 |

**Not used:**
- `07_looks_grid_womens.png`: it shows a man's photo under Women's Apparel and
  would read as a bug.
- The remaining screenshots: no shot needs them.

Every rebuilt screen sits inside a white phone frame with 44 px corner
radius.

---

## Timeline

| # | Time | Mode | Length |
| --- | --- | --- | --- |
| S1 | 0.0 – 2.0 | Atmosphere | 2.0 s |
| S2 | 2.0 – 3.2 | Atmosphere → whiteout | 1.2 s |
| S3 | 3.2 – 5.0 | Product | 1.8 s |
| S4 | 5.0 – 6.2 | Text card | 1.2 s |
| S5 | 6.2 – 8.4 | Product + slot wheel | 2.2 s |
| S6 | 8.4 – 10.4 | Product → match cut | 2.0 s |
| S7 | 10.4 – 12.2 | Product | 1.8 s |
| S8 | 12.2 – 13.4 | Text card | 1.2 s |
| S9 | 13.4 – 15.0 | **Hard cut** → Atmosphere lockup | 1.6 s |

The film has one hard cut, at 13.4 s. Every other change is a continuous
transition, per the style guide.

---

## Shots

### S1 · 0.0 – 2.0 · Opening: the mirror in its world

- **Picture:** A full-bleed rendered world in Mirror green. A deep `#05100D`
  sky runs down to a curved horizon lit along its edge with `#16E0C9`. Above
  the horizon floats a single **tall glass mirror pane**: portrait, rounded
  corners, edges catching teal light. Its reflection shows below it on the
  glossy floor. This pane is our hero object, standing in for the reference's
  orb. It stays upright and turns slowly, about 8° over the shot.
- **Camera:** Slow push-in, scale 1.00 → 1.06.
- **Text:**
  - 0.5 s: "Introducing" blurs in. White at 85 %, 64 px, centred just under
    the pane.
  - 1.0 s: "Introducing" fades out. The typewriter starts in the same spot:
    **"a new kind of mirror|"**, 20 characters at about 10 characters per
    second, ending at 1.9 s with the caret blinking.
- **Sound:** A low swell. A soft tick on each character.

### S2 · 2.0 – 3.2 · "that styles you" → whiteout

- **Picture:** The camera rises past the pane, which leaves the top of the
  frame. The horizon flattens and the gradient pales: green, then mint, then
  `#FDFDFD`. This is the reference's whiteout grammar.
- **Text:** **"that styles you"** blurs in word by word (20 px blur), tinted
  `#006554`. As the background turns white, the tint settles to ink.
- **Exit:** By 3.1 s only the white canvas and the ink line are left. The line
  fades to `#B4B4B4` and disappears as S3 arrives.

### S3 · 3.2 – 5.0 · One photo

- **Picture:** Zoom-reveal. The shot opens tight on `GET_READY`, showing the
  teal framing brackets and the shopper with no phone frame visible. The
  camera pulls back (scale 1.6 → 1.0, expo-out) and the white phone frame
  forms around the screen, centred at 82 % of frame height.
- **4.3 s:** The shutter button on screen pulses, and a full-frame white flash
  lasts 3 frames.
- **4.4 s:** Inside the phone, the screen cross-fades to `LOADING` ("Mirror ·
  ONE MOMENT"). Its progress bar sweeps once.
- **Camera:** A slight push back in (1.0 → 1.04) during the loading screen.
- **Sound:** A shutter click at 4.3 s.

### S4 · 5.0 – 6.2 · Text card

- **Picture:** The phone drops out of frame downward with motion blur, leaving
  the off-white canvas.
- **Text:** **"One photo. Four looks."**, 120 px, word by word: 5.10, 5.35,
  5.60, 5.85. Each word arrives grey `#5A5A5A` and darkens to ink. The words
  are placed at their final centred positions from the start, so the line
  never shifts.
- **Exit:** At 6.1 s a phone rising from below pushes the line up and out.

### S5 · 6.2 – 8.4 · Slot wheel: the four looks

This shot uses the reference's slot-list grammar.

- **Picture:** The phone sits centre-low. Above it is one large active word at
  112 px in ink. Behind the phone is a stack of the other category words in
  `#B4B4B4`, cropped by the phone's edges.
- **Sequence:** Each look's tile from `GRID` is cropped and fills the phone
  screen edge to edge, with the shopper's real generated look. Each of the
  four beats lasts 0.5 s. The wheel rolls up one row per beat:

  | Time | Word | Screen |
  | --- | --- | --- |
  | 6.3 | **Golf** | Golf look |
  | 6.8 | **Athletics** | Athletics look |
  | 7.3 | **Workout** | Workout look |
  | 7.8 | **Sports** | Sports look |

- **On each change:** The image cross-fades from about 10 px of blur to sharp,
  using the reference's blur-to-sharp load.
- **Camera:** A steady push-in, 0.92 → 1.00, across the whole shot.
- **Sound:** A tick on each roll of the wheel.

### S6 · 8.4 – 10.4 · All four, then pick one (match cut)

- **8.4 s:** The words fall away. The phone pulls back (1.0 → 0.88) and its
  screen becomes the full `GRID`: four looks, with "SEE YOURSELF STYLED / MEN'S
  APPAREL". Each tile resolves from blur to sharp, 0.1 s apart.
- **9.2 s:** A soft tap ripple lands on the Golf tile's **GET THIS STYLE**.
- **9.4 s, match cut:** The Golf tile lifts out of the phone and scales to fill
  the frame. The phone fades behind it. The tile becomes full-bleed `TRYON`:
  the shopper in the red polo on the golf course, cropped 16:9 around them.
  This uses the reference's morph grammar.
- **10.0 s:** The camera pulls back into a phone frame showing `TRYON` with
  its white **CHECKOUT** bar.
- **Camera:** Pull-back, then a fast scale-up on the match cut, then a
  pull-back again.

### S7 · 10.4 – 12.2 · Shop it

- **Picture:** The phone slides 18 % to the left while the screen changes to
  `PRODUCT` (Tailgate Print Golf Polo, $75.00). A small caption fades in above
  the phone at 36 px: "Opens right on DICK'S".
- **11.2 s:** The screen scrolls into `CART`: "Cart (1 item) · $75.00".
- **11.5 s:** The cart badge "1" pops with a **teal `#16E0C9` sparkle burst**,
  six to eight small marks with motion blur. This is the only place teal
  appears outside the atmosphere scenes, and it stands in for the reference's
  heart-reaction burst.
- **Camera:** A lateral slide, then a 0.5 s hold on the cart.
- **Sound:** A bright two-note chime on the badge.

### S8 · 12.2 – 13.4 · Tagline

- **Picture:** The phone exits right with motion blur, leaving the off-white
  canvas.
- **Text:** **"See it on you. Then shop it."**, word by word from 12.3 s, one
  word every 0.18 s. Each word arrives grey and darkens to ink.
- **Hold:** From 12.9 s to 13.2 s.
- **Exit:** At 13.2 s the line fades to `#B4B4B4`.

### S9 · 13.4 – 15.0 · Hard cut → lockup

- **13.4 s, hard cut:** The film cuts back into the S1 world, lit brighter, as
  the reference does at its own close. The glass mirror pane turns to face the
  camera and shrinks into a **rounded app tile**: the glass square shows the
  teal rim and a sliver of reflection, tilted −8° with a soft shadow.
- **13.9 s:** The world brightens to the off-white canvas. The tile stays,
  and **"Mirror"** blurs in to its right in ink at 96 px. The tile and the
  word form a centred lockup.
- **14.3 s:** Under the lockup, a small line at 30 px in `#5A5A5A`:
  "at [DICK'S logo] Sporting Goods". The logo is the real SVG at 40 px height.
- **14.6 – 15.0 s:** Hold. The film ends on the lockup with no fade to black,
  as the reference does.
- **Sound:** The bed resolves on the lockup.

---

## Decisions (2026-10-03)

1. **Shopper:** a fictional man. You supply one source photo, and the Mirror
   service generates the four looks at full size, using 4 generations.
2. **Screens:** rebuilt in HTML from the screenshots, not used as images.
3. **Brands:** used as they are, no approval step for now.
4. **3D world:** the glass pane and its world are built in HTML/CSS/WebGL.
   No pre-rendered 3D.
5. **Music:** still open. The plan is a minimal electronic bed around
   120 BPM, picked during the build.
