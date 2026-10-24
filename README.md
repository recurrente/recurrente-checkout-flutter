# Recurrente Checkout Flutter

Release candidate for a hosted Recurrente checkout inside a mobile WebView. This builds on the existing package; it is **not published to pub.dev by this change**. It does not collect card details in native fields or provide a native 3DS2 SDK.

## Install

```yaml
dependencies:
  recurrente_checkout_flutter:
    path: ../recurrente-checkout-flutter
```

Flutter 3.38+, Dart 3.10+, Android API 24+ / iOS 13+ as required by `webview_flutter`. macOS metadata is retained from the initial package but this delivery's native acceptance scope is iOS/Android; desktop behavior is not verified.

## Integrate

Your backend creates the checkout with its own Recurrente credentials and passes only the hosted HTTPS URL to the app. Keep that URL stable during payment. Never include API keys in the mobile app.

```dart
final checkout = RecurrenteCheckoutController();

// Inside your page's SafeArea, with the application's close/back control:
RecurrenteCheckout(
  url: checkoutUrlFromYourBackend,
  controller: checkout,
  returnUrls: [Uri.parse('myapp://checkout/result')],
  onSuccess: (_) => refreshOrderFromYourBackend(),
  onPaymentInProgress: (_) => refreshOrderFromYourBackend(), // Pending, NOT paid.
  onFailure: (_) { /* Leave this checkout open for retry. */ },
  onReturn: (_) => refreshOrderFromYourBackend(),
  onCancel: () { refreshOrderFromYourBackend(); closeCheckoutScreen(); },
  onError: (message) { /* Recovery UI; no automatic new charge. */ },
  onExternalNavigation: (uri) { /* Open only host-approved URLs. */ },
  onFileSelector: (params) async {
    // Android: open your app's file picker with params.acceptTypes/mode.
    // Return selected content:// or file:// URIs; return [] on cancellation.
    return pickReceiptFiles(params);
  },
);
// Close/back: checkout.cancel(); onCancel must remove the widget.
```

The complete [example](example/lib/main.dart) uses a system file selector and deliberately requires an explicit test checkout URL. It does not create a checkout or expose API credentials.

## Events and lifecycle

- `recurrente-plugin:payment-success`: checkout reports a `checkoutId`; at most once per session. Confirm server state before fulfillment.
- `recurrente-plugin:payment-failed`: validation/decline, sometimes without `checkoutId`. A later retry can succeed; don't close the view automatically.
- `recurrente-plugin:payment-in-progress`: bank transfer submitted/processing, **not paid**. Use backend reconciliation/webhooks.
- `onReturn`: scheme, host, path and configured query values match one of `returnUrls`. A custom success redirect may replace the success postMessage. A return URL is not payment proof.
- `onCancel`: UI cancellation only. It does not cancel/refund a payment already submitted. Unmount the widget, then reconcile the order.
- Network errors, process interruption, app background/resume and expired checkout are not payment failures by themselves. Verify backend status before retrying/recreating a checkout. The host owns platform back/dismissal and lifecycle restoration.

The bridge is installed before the iframe loads, checks exact origin and frame, filters event fields and rejects stale sessions. Checkout URLs must be HTTPS on `app.recurrente.com`; existing query values and fragments are preserved, with exactly one `embed=true`. Do not override the configured JavaScript channel or navigation delegate through `onWebViewCreated`.

## Native integration and 3DS

The existing hosted checkout owns card entry, subscriptions, installments, balance/login, saved cards, bank transfers and issuer authentication. The wrapper preserves HTTPS subframe navigation; it does not enable a method unavailable to the merchant. Failure/pending are distinct from success, and nested issuer messages cannot directly trigger payment success.

**Release gate:** test real issuer frictionless/challenge/decline/cancel/timeout cases on iOS and Android, receipt selection/upload/cancel, return routes, external links, close/back, background/resume, offline recovery, and accessibility. Capture native screenshots (checkout, errors, keyboard and challenge) and complete design review. Protocol tests alone are not that evidence. The normal sandbox skips issuer authentication, so it cannot prove a bank challenge.

Android bank receipts require `onFileSelector`; without it the wrapper reports a configuration error instead of pretending upload succeeded. iOS WKWebView uses the system picker. Add any privacy usage descriptions your picker needs. Android apps need INTERNET permission. TLS remains enforced; do not add a broad cleartext or ATS exception.

Wallets, passkeys, popup-based authentication and payment apps require separate platform/domain/entitlement validation. The package does not promise their availability. `webview_flutter` popup handling differs by platform; verify required links and use a host-designed browser fallback when necessary. Such fallback must reconcile the checkout on app return; it is not implemented automatically by this package.

## Migration from 0.0.1

The unbounded `development` option and custom `allowedOrigin` were removed. Sandbox checkouts still use the trusted hosted origin. `onWebViewCreated`, page/resource callbacks, background color and payment callbacks remain available. `onPageFinished` is no longer responsible for installing the bridge, avoiding missed parser-time events.

## Verify

```sh
flutter pub get
flutter analyze
flutter test
dart pub publish --dry-run
```

No publish command without `--dry-run` is part of this change. The generated `lib/src/checkout_shell.dart` comes from `recurrente-checkout/mobile/shared/checkout-shell.html`. [Shared SDK contract and validation matrix](https://github.com/recurrente/recurrente-checkout/tree/mobile-sdks-5093663664/mobile).

Sources: [Recurrente sandbox guide](https://docs.recurrente.com/guias-espanol/comenzar/primer-pago-de-prueba), [webview_flutter](https://pub.dev/packages/webview_flutter), and the current hosted checkout's event/authentication controllers (reviewed 2026-10-23).
