## 0.1.0-rc.0

- Install the origin/frame-checked bridge before checkout loads; catch early success.
- Preserve retry after failure, pending transfer events and at-most-once success.
- Add exact return routes, external navigation, Android receipt picker and UI cancel.
- Isolate reload sessions and preserve repeated query parameters.
- Remove unrestricted `development` and custom `allowedOrigin` options. All mobile
  checkouts must use the hosted HTTPS origin, including sandbox checkout URLs.
- Native screenshots, real issuer 3DS and release acceptance remain pending.

## 0.0.1

- Initial Flutter WebView wrapper for Recurrente Checkout.
