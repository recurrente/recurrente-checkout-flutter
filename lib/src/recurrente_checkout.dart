import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'checkout_protocol.dart';
import 'recurrente_checkout_message.dart';

/// Receives a validated checkout event; confirm payment status on your backend.
typedef RecurrenteCheckoutCallback =
    void Function(RecurrenteCheckoutMessage message);

/// Attach to one checkout widget and call cancel when the user closes it.
class RecurrenteCheckoutController {
  VoidCallback? _cancel;

  /// Emits UI cancellation once; the host must then remove the checkout widget.
  void cancel() => _cancel?.call();
}

/// Hosted Recurrente checkout, with issuer authentication handled by checkout.
class RecurrenteCheckout extends StatefulWidget {
  /// Creates a hosted checkout. Keep its URL stable while payment is in progress.
  const RecurrenteCheckout({
    super.key,
    required this.url,
    this.controller,
    this.onCancel,
    this.onSuccess,
    this.onFailure,
    this.onPaymentInProgress,
    this.onWebViewCreated,
    this.onPageStarted,
    this.onPageFinished,
    this.onWebResourceError,
    this.onError,
    this.onExternalNavigation,
    this.onReturn,
    this.returnUrls = const [],
    this.onFileSelector,
    this.backgroundColor = Colors.transparent,
  });

  /// HTTPS checkout URL supplied by your backend.
  final Uri url;

  /// Optional controller for your close/back action.
  final RecurrenteCheckoutController? controller;

  /// UI cancellation only, not cancellation of a submitted charge.
  final VoidCallback? onCancel;

  /// Checkout reports success, at most once for this session.
  final RecurrenteCheckoutCallback? onSuccess;

  /// Retryable checkout failure; leave the checkout mounted.
  final RecurrenteCheckoutCallback? onFailure;

  /// Transfer submitted for processing; this is not a paid status.
  final RecurrenteCheckoutCallback? onPaymentInProgress;

  /// Called after bridge configuration and before loading the checkout.
  final ValueChanged<WebViewController>? onWebViewCreated;

  /// Underlying WebView navigation started.
  final ValueChanged<String>? onPageStarted;

  /// Underlying WebView navigation finished; not a payment signal.
  final ValueChanged<String>? onPageFinished;

  /// Underlying WebView resource error, separate from a payment decline.
  final ValueChanged<WebResourceError>? onWebResourceError;

  /// Configuration or missing picker error, separate from a payment decline.
  final ValueChanged<String>? onError;

  /// Host decides whether to launch an external link; never infer payment success.
  final ValueChanged<Uri>? onExternalNavigation;

  /// Matched return route; query your backend before treating it as paid.
  final ValueChanged<Uri>? onReturn;

  /// Exact scheme, host, path and required query parameters to intercept.
  final List<Uri> returnUrls;

  /// Android receipt upload. Return selected content/file URIs, or [] on cancel.
  final Future<List<String>> Function(FileSelectorParams)? onFileSelector;

  /// Background while the hosted content is loading.
  final Color backgroundColor;

  /// Only this hosted origin can send accepted checkout events.
  static const defaultAllowedOrigin = CheckoutProtocol.origin;

  /// Validates the trusted HTTPS URL and adds one embed=true parameter.
  static Uri embeddedUri(Uri url) => CheckoutProtocol.embeddedUri(url);

  @override
  State<RecurrenteCheckout> createState() => _RecurrenteCheckoutState();
}

class _RecurrenteCheckoutState extends State<RecurrenteCheckout> {
  late final WebViewController _controller;
  late final Future<void> _configuration;
  String _session = CheckoutProtocol.session();
  bool _closed = false;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    widget.controller?._cancel = _cancelSession;
    _controller = WebViewController();
    _configuration = _configure();
    unawaited(_load());
  }

  Future<void> _configure() async {
    final backgroundColor = widget.backgroundColor;
    await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    if (!mounted) return;
    await _controller.setBackgroundColor(backgroundColor);
    if (!mounted) return;
    await _controller.addJavaScriptChannel(
      'RecurrenteCheckoutBridge',
      onMessageReceived: (raw) {
        if (!mounted || _closed) return;
        final message = CheckoutProtocol.decode(raw.message, _session);
        if (message == null) return;
        switch (message.type) {
          case RecurrenteCheckoutMessage.paymentSuccessType:
            _closed = true;
            widget.onSuccess?.call(message);
          case RecurrenteCheckoutMessage.paymentFailedType:
            widget.onFailure?.call(message);
          case RecurrenteCheckoutMessage.paymentInProgressType:
            widget.onPaymentInProgress?.call(message);
        }
      },
    );
    if (!mounted) return;
    await _controller.setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: (request) {
          if (!mounted || _closed) return NavigationDecision.prevent;
          final uri = Uri.tryParse(request.url);
          if (uri == null) return NavigationDecision.prevent;
          if (CheckoutProtocol.matchesReturn(uri, widget.returnUrls)) {
            widget.onReturn?.call(uri);
            return NavigationDecision.prevent;
          }
          if (request.url == 'about:blank' ||
              request.url == '${CheckoutProtocol.shellOrigin}/') {
            return NavigationDecision.navigate;
          }
          if (!request.isMainFrame && uri.scheme == 'https') {
            return NavigationDecision.navigate;
          }
          widget.onExternalNavigation?.call(uri);
          return NavigationDecision.prevent;
        },
        onPageStarted: (url) {
          if (mounted) widget.onPageStarted?.call(url);
        },
        onPageFinished: (url) {
          if (mounted) widget.onPageFinished?.call(url);
        },
        onWebResourceError: (error) {
          if (mounted) widget.onWebResourceError?.call(error);
        },
      ),
    );
    if (!mounted) return;
    if (_controller.platform is AndroidWebViewController) {
      final android = _controller.platform as AndroidWebViewController;
      await android.setOnShowFileSelector((params) async {
        if (!mounted) return [];
        final callback = widget.onFileSelector;
        if (callback == null) {
          widget.onError?.call(
            'Configure onFileSelector to upload bank-transfer receipts',
          );
          return [];
        }
        return callback(params);
      });
      final cookies = WebViewCookieManager().platform;
      if (cookies is AndroidWebViewCookieManager) {
        await cookies.setAcceptThirdPartyCookies(android, true);
      }
    }
    if (mounted) widget.onWebViewCreated?.call(_controller);
  }

  Future<void> _load() async {
    final revision = ++_revision;
    _session = CheckoutProtocol.session();
    _closed = false;
    try {
      final html = CheckoutProtocol.html(widget.url, _session);
      await _configuration;
      if (!mounted || _closed || revision != _revision) return;
      await _controller.loadHtmlString(
        html,
        baseUrl: '${CheckoutProtocol.shellOrigin}/',
      );
    } catch (error) {
      if (mounted && revision == _revision) {
        widget.onError?.call(error.toString());
      }
    }
  }

  void _cancelSession() {
    if (_closed) return;
    _closed = true;
    widget.onCancel?.call();
  }

  @override
  void didUpdateWidget(covariant RecurrenteCheckout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._cancel = null;
      widget.controller?._cancel = _cancelSession;
    }
    if (oldWidget.url != widget.url) unawaited(_load());
    if (oldWidget.backgroundColor != widget.backgroundColor) {
      unawaited(_controller.setBackgroundColor(widget.backgroundColor));
    }
  }

  @override
  void dispose() {
    _closed = true;
    widget.controller?._cancel = null;
    ++_revision;
    unawaited(_controller.removeJavaScriptChannel('RecurrenteCheckoutBridge'));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _controller);
}
