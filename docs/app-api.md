# Style Mirror — App API

Base URL: `http://127.0.0.1:8000` (local) · `https://<host>` (production)

All paths are prefixed with `/api`. Always send `Accept: application/json`.
No authentication yet.

---

## POST /api/app/photo

Upload the photo once, keep the `photo_id`.

**Params** — send either form:

| Param | Type | Required | Notes |
| --- | --- | --- | --- |
| `photo` | file | yes | `multipart/form-data`. JPEG/PNG/WebP, max 12 MB. |
| `photo` | string | yes | `application/json`. `data:image/jpeg;base64,...` or bare base64. |

**Response `201`**

```json
{
  "success": true,
  "photo_id": "ph_koajwbs1x3bhrz6ghigckruz",
  "width": 1100,
  "height": 1100,
  "bytes": 148981,
  "expires_at": "2026-10-01T13:15:24+00:00",
  "expires_in": 21600
}
```

Valid for 6 hours. Server resizes to 1440px, fixes EXIF rotation and strips
metadata — the app does not need to.

---

## GET /api/app/photo/{photo_id}

Is the id still usable?

**Response `200`**

```json
{ "success": true, "photo_id": "ph_koaj...", "bytes": 148981 }
```

**Response `404`** — expired or unknown. Upload again.

---

## DELETE /api/app/photo/{photo_id}

**Response `200`**

```json
{ "success": true }
```

---

## GET /api/app/looks

The menu. Read once at startup instead of hard-coding it.

**Response `200`**

```json
{
  "success": true,
  "looks": [
    { "category": "golf",      "label": "Golf",      "tagline": "Course-ready" },
    { "category": "athletics", "label": "Athletics", "tagline": "Built to perform" },
    { "category": "workout",   "label": "Workout",   "tagline": "Train harder" },
    { "category": "sports",    "label": "Sports",    "tagline": "Game day" }
  ],
  "variants": [
    { "variant": "men",   "label": "Men's" },
    { "variant": "women", "label": "Women's" },
    { "variant": "boys",  "label": "Boys'" },
    { "variant": "girls", "label": "Girls'" }
  ],
  "depts": [
    { "dept": "apparel", "label": "Apparel" },
    { "dept": "shoes",   "label": "Shoes" }
  ]
}
```

---

## POST /api/app/generate

One look per call. `application/json`.

**Params**

| Param | Required | Values | Default |
| --- | --- | --- | --- |
| `photo_id` | yes | from the upload call | — |
| `category` | yes | `golf` · `athletics` · `workout` · `sports` | — |
| `variant` | no | `men` · `women` · `boys` · `girls` | `men` |
| `dept` | no | `apparel` · `shoes` | `apparel` |

**Request**

```json
{
  "photo_id": "ph_koajwbs1x3bhrz6ghigckruz",
  "category": "golf",
  "variant": "women",
  "dept": "shoes"
}
```

**Response `200`**

```json
{
  "success": true,
  "photo_id": "ph_koajwbs1x3bhrz6ghigckruz",
  "category": "golf",
  "label": "Golf",
  "tagline": "Course-ready",
  "variant": "women",
  "dept": "shoes",
  "image": "https://<host>/storage/adcampaign/8f2c....webp",
  "shop_url": "https://www.dickssportinggoods.com/f/womens-golf-shoes",
  "cached": false,
  "test": false
}
```

`image` → show it. `shop_url` → the "GET THIS STYLE" button (do not hard-code these).
`test: true` means generation is switched off server-side and this is a placeholder.

**Menu → params**

| Customer tapped | `variant` | `dept` |
| --- | --- | --- |
| Men's Apparel | `men` | `apparel` |
| Women's Apparel | `women` | `apparel` |
| Youth Apparel | `boys` | `apparel` |
| Girls' Apparel | `girls` | `apparel` |
| Shoes (after Men's) | `men` | `shoes` |
| Shoes (after Women's) | `women` | `shoes` |

---

## POST /api/tryon

Try one specific garment on the customer. Different from `/api/app/generate`:
here **you** supply the shirt, and only the scene comes from `category`.

`multipart/form-data`.

**Params**

| Param | Required | Values |
| --- | --- | --- |
| `image` | yes | the garment file (shirt / T-shirt), max 12 MB |
| `category` | yes | `golf` · `athletics` · `workout` · `sports` — scene only, does not pick the garment |
| `photo_id` | no | from the upload call. **Send it.** See below. |

**Response `200`**

```json
{
  "success": true,
  "image": "https://<host>/storage/tryon/8f2c....webp",
  "url": "https://<host>/storage/tryon/8f2c....webp"
}
```

**Always send `photo_id`.** Without it the server falls back to a single shared
slot that holds one photo for the whole server. That is correct for the in-store
kiosk — one device, one customer at a time — but in the app two customers
uploading within the same few minutes overwrite each other, and the second
upload's face comes back on the first customer's try-on. Naming the photo removes
that completely.

Uploading via `POST /api/app/photo` also refreshes that shared slot, so older app
builds that do not send `photo_id` still work; they just cannot be relied on when
two people are in flight at once.

---

## Errors

| Status | `code` | Meaning |
| --- | --- | --- |
| `422` | — | Validation — bad or missing param. See `errors`. |
| `404` | `photo_expired` | `photo_id` gone (generate and try-on both). Upload again, then retry. |
| `422` | `generation_failed` | Provider failed. `message` has the reason. Retry is safe. |

---

## Three things that matter

1. **Call generate 4× in parallel**, one per category — not in sequence. Each takes
   12–50s; sequential is 3+ minutes on one connection and mobile networks drop it.
2. **HTTP timeout at least 90s.** The server allows the provider 150s.
3. **Retry is free.** Results cache for 6 hours per `(photo, category, variant, dept)`,
   so a retry returns `"cached": true` instead of generating again.
