# Browsing history payload

What the app sends to the backend for the in-app browser's history. Example
body: [`url-history-payload.example.json`](url-history-payload.example.json).

`POST https://mirror.maxaix.com/api/history` · `application/json` · no token.

One request carries **one flow**: a single journey from the mirror out to a
retailer. The app sends it when that journey ends — when the user comes back
to the mirror to start another, or when they put the app down. A flow that
never left the mirror is not sent at all, so every batch has at least one
visit to a retailer in it.

## Envelope

| Field | Type | Notes |
| --- | --- | --- |
| `schemaVersion` | int | `1`. Bumped only when a field changes meaning. |
| `sentAt` | string | UTC ISO-8601, when the batch left the device. |
| `app.id` | string | Package id — differs per flavor. |
| `app.version` / `app.build` | string | From `package_info_plus`. |
| `app.flavor` | string | `development` \| `staging` \| `production`. |
| `device.platform` | string | `android` \| `ios`. |
| `device.osVersion` | string | The OS build string, as the platform reports it. |
| `visits` | array | The pages of this one flow, newest first. |

## A visit

One page load in the browser. A row is written the moment the page starts
loading, so an in-flight or failed page is still reported.

| Field | Type | Notes |
| --- | --- | --- |
| `id` | string | `<microsecondsSinceEpoch>-<counter>`. Unique per device; use it with the device to dedupe re-sent batches. |
| `url` | string | The page that loaded. |
| `destinationId` | string | Which entry point the session began from: `mirror` or `dicks_sporting_goods`. |
| `openedAt` | string | UTC ISO-8601, when loading started. |
| `title` | string? | The page's own title. Absent while loading and on failure. |
| `loadTimeMs` | int? | Start to finish. Absent while loading and on failure. |
| `error` | string? | Present only when the main frame failed. |
| `trigger` | string | How the page was reached — see below. |
| `tappedLabel` | string? | Words on the thing that was tapped, truncated to 200 chars. |
| `tappedContext` | string? | The heading that tapped thing sat under. |
| `sourceUrl`, `sourceTitle` | string? | The page the tap happened on. |

Optional fields are **omitted**, not sent as `null`.

`loadTimeMs` absent **and** `error` absent means the page was still loading
when the batch was sent — a later batch may carry a completed row with the
same `id`, so upsert on `id` rather than insert.

## `trigger` values

| Value | Meaning |
| --- | --- |
| `direct` | Opened by the app — a destination, or a row reopened from history. |
| `link` | An ordinary `<a>` on the page. |
| `element` | A card or button carrying the URL as an attribute. |
| `frame` | The site tried to open it in an embedded frame; the app lifted it out. |
| `viewer` | Unwrapped from a viewer page that held the real link in its query. |
| `inPage` | The site navigated itself — redirect, form, script. |
