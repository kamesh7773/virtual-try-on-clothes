# Style guide: Mirror launch video

This guide is drawn from the reference film: the wabi app launch, 80.5 s,
3840×2160, 60 fps. The source is [x.com/wabi/status/2104721766690222087](https://x.com/wabi/status/2104721766690222087)
and the local copy is `refs/reference.mp4`. I studied 161 frames, one every
0.5 s, in `refs/frames/`.

**Borrowed:** the film's grammar, meaning its pacing, transitions, camera
behaviour and the way text behaves.
**Not borrowed:** its words, glass orbs, black-dot logo, emoji, chat content,
characters or avatars. Everything that appears on screen in our film is Mirror's.

---

## 1. Structure

The reference has three kinds of footage and switches between them on a steady
rhythm:

| Mode | What it looks like | Share of runtime |
| --- | --- | --- |
| **Atmosphere** | A full-bleed rendered gradient world with one glossy hero object. Used only for the opening and the closing. | ~15 % |
| **Text card** | A flat off-white canvas holding one centred line of type and nothing else. | ~30 % |
| **Product** | A real app screen inside a white phone frame, floating on the same off-white canvas. | ~55 % |

The film opens in the atmosphere, spends its middle alternating between text
cards and product, and returns to the atmosphere for the logo. In that return,
the hero object turns into the logo.

## 2. Palette

### Measured from the reference

| Role | Hex | Notes |
| --- | --- | --- |
| Canvas | `#FDFDFD` | Never pure white. It sits under every text card and product shot. |
| Ink | `#0E0E0E` → `#000000` | Final colour of a fully settled word. |
| Ink, arriving | `#5A5A5A` | A word that is mid-fade-in. |
| Ink, leaving / pending | `#B4B4B4` | Words not yet active, and lines on their way out. |
| Phone frame | `#F7F7F7` | Plus a soft grey shadow, roughly `0 30px 60px rgba(0,0,0,.08)`. |
| Atmosphere, opening | `#1C0F75` · `#66168A` · `#D27DA5` · `#D96C3C` · `#982C20` | Navy to violet to rose to orange, with a dark horizon band. |
| Atmosphere, closing | `#742592` · `#CD6B9E` · `#EB8961` · `#EB6C26` | The same family, warmer, with a light that brightens to white. |

### Applied to Mirror

We keep the reference's neutral canvas and ink. The atmosphere colours are
replaced with Mirror's own stage colours, taken from `lib/core/theme/app_colors.dart`:

| Role | Hex | Source |
| --- | --- | --- |
| Canvas | `#FDFDFD` | Reference grammar |
| Ink / arriving / pending | `#0E0E0E` / `#5A5A5A` / `#B4B4B4` | Reference grammar |
| Atmosphere, deep | `#05100D` | Darker than `styleStage` |
| Atmosphere, body | `#091714` → `#0C1A15` | `styleStage`, `styleCard` |
| Atmosphere, mid | `#006554` | `styleDeepGreen` |
| Atmosphere, rim light / accent | `#16E0C9` | `styleTeal` |
| Accent on canvas | `#16E0C9` | Used in one place only: the burst when the cart badge pops |

Rules for colour:
- The off-white sections stay entirely neutral. Colour on those sections comes
  only from the app screenshots.
- Teal appears exactly once outside the atmosphere scenes.

## 3. Type

The reference uses a single neutral neo-grotesk, close to Inter Display or SF
Pro Display. Its shapes: two-storey "a", flat terminals, a tall x-height.

| Property | Reference | Mirror |
| --- | --- | --- |
| Family | Neo-grotesk (Inter/SF-like) | **Inter Display**. Montserrat appears only inside the app screenshots. |
| Weight | ~500, medium | 500 |
| Size, hero line | Ascender ≈ 8 % of frame height (~88 px at 1080p) | 120 px at 1920×1080 |
| Size, caption above phone | ~2 % of frame height | 36 px |
| Size, slot-list word | ~7 % of frame height | 112 px |
| Tracking | Slightly tight, about −0.02 em | −0.02 em |
| Case | Sentence case, never all caps | Sentence case |
| Alignment | One centred line. Words are placed at their final positions before they appear, so the line never re-centres. | Same |
| Lines on screen | 1, never 2 | 1 |

## 4. Shot lengths

There are only **2 hard cuts in 80 s**, at 43.8 s and 71.8 s. Every other
change is a continuous transition. In the table below, a "beat" means the time
between visual events.

| Unit | Reference | For our 15 s film |
| --- | --- | --- |
| Text card, held | 1.5 – 3.0 s | 1.0 – 1.4 s |
| Typewriter line | ~10 characters per second, then a 0.5 s hold | Same speed |
| Product passage | 3 – 5 s, with a visual event every ~1 s | 1.8 – 2.2 s, with a visual event every ~0.6 s |
| Slot-list word | ~1.0 s each | 0.5 s each |
| Logo lockup | ~5 s | 1.6 s |

Overall the reference runs at about 1 event per second. Our film compresses
that to about 1.6 events per second.

## 5. Transition types

These are ranked by how often they appear in the reference.

1. **Morph / match cut.** An element in one shot becomes an element in the
   next. In the reference, avatars converge into the avatar on a chat bubble,
   widgets fly from the phone onto a home screen, and the orbs turn into the
   logo.
2. **Zoom-reveal.** The view starts tight on UI with no frame visible. The
   camera pulls back and the phone frame forms around the UI.
3. **Whiteout.** The atmosphere brightens until it becomes the off-white
   canvas. The hard cut back into colour happens at the end.
4. **Burst-in / burst-out.** Many objects explode outward from centre
   (or converge onto it) with heavy motion blur. This lasts 0.5 s.
5. **Blur-to-sharp load.** A card shows a blurred placeholder, then resolves
   to the real image over about 0.6 s.
6. **Particle disintegrate.** Words dissolve into noise, used on a line that
   is being "undone".
7. **Hard cut.** Rare. It is saved for the jump back into the colour world.

## 6. Camera moves

The camera is virtual: it moves over the 2D layout, not through a 3D scene.

- **Push-in / pull-back** on the phone, scaling between about 1.00 and 0.85 over
  1 – 2 s on an expo-out ease. The phone is never still for more than ~0.8 s.
- **Vertical drift** that follows new content as it arrives, as if the frame
  were scrolling with a conversation.
- **Lateral slide.** The phone exits to one side as the next element arrives.
- **Tilt** is used only on small floating tiles, at −6° to −10°. It is never
  applied to the phone or the type.
- There is no handheld shake, no rotation of the frame and no rack focus.
  Depth comes from blur on moving objects.

## 7. Texture and grain

- **Off-white sections** have no grain, no vignette and no gradients. They
  look like clean print.
- **Atmosphere sections** are soft 3D renders: glossy materials with
  subsurface-style colour gradients, one large soft horizon, and a bright rim
  light. They are photographic in quality but contain no film grain.
- **Shadows** are soft and low-contrast. They exist only under the phone and
  under floating tiles.
- **Motion blur** is heavy on fast objects. Directional blur on elements
  entering or leaving can reach 40 px.
- **Depth of field.** Objects entering the frame start blurred and sharpen as
  they settle.

## 8. How text enters and exits

**Entrances** (in order of frequency):

1. **Word-by-word blur-in, in place.** Each word fades from 0 to 100 %
   opacity and from about 8 px of blur to 0. It holds at `#5A5A5A` for about
   0.15 s, then darkens to ink. Words start about 0.25 s apart.
2. **Typewriter with caret.** Characters appear one at a time with a thin
   blinking caret `|`. This is used once, for the opening line. On the
   gradient, the caret and type are white at 85 %.
3. **Tinted blur-in on gradient.** The text takes a darker tint of the
   atmosphere colour and arrives with more blur (about 20 px).
4. **Slot wheel.** A large word sits above the phone. Behind it is a stack of
   pending words in light grey, cropped by the phone. The stack rolls upward
   one row per beat, and the active row snaps to ink.

**Exits:**

1. **Fade to pending grey** (`#B4B4B4`), then a quick fade to nothing.
2. **Particle disintegrate**, used on part of a line, while the remaining
   words stay where they are.
3. **Push-out.** The next element, for example a phone rising from below,
   pushes the line out of frame.
4. **Converge into a mark.** Words fall away from either side of the mark one
   at a time until only the mark and the product name are left. The product
   name then changes into the domain.

## 9. Sound (not measured)

The reference has an audio track, but I could not listen to it. The edit
lands on a steady pulse of roughly 1 event per second. For Mirror, a minimal
electronic bed around 120 BPM fits the pacing in this guide. Soft UI ticks
should sit on the word entrances and a shutter click on the photo. Sourcing
the bed is a separate step.
