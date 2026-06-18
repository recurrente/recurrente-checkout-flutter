import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'recurrente_checkout_message.dart';

/// Callback for checkout events emitted by the Recurrente checkout page.
typedef RecurrenteCheckoutCallback = void Function(
  RecurrenteCheckoutMessage message,
);

/// Embeds a Recurrente checkout URL in a WebView.
///
/// This widget intentionally mirrors the JavaScript package: it only appends
/// `embed=true`, renders the checkout URL, and forwards checkout events to
/// Dart callbacks.
class RecurrenteCheckout extends StatefulWidget {
  /// Creates a Recurrente checkout WebView.
  const RecurrenteCheckout({
    super.key,
    required this.url,
    this.onSuccess,
    this.onFailure,
    this.onPaymentInProgress,
    this.onWebViewCreated,
    this.onPageStarted,
    this.onPageFinished,
    this.onWebResourceError,
    this.allowedOrigin = defaultAllowedOrigin,
    this.development = false,
    this.backgroundColor = Colors.transparent,
  });

  /// Recurrente checkout or product URL.
  final Uri url;

  /// Called when checkout emits `recurrente-plugin:payment-success`.
  final RecurrenteCheckoutCallback? onSuccess;

  /// Called when checkout emits `recurrente-plugin:payment-failed`.
  final RecurrenteCheckoutCallback? onFailure;

  /// Called when checkout emits `recurrente-plugin:payment-in-progress`.
  final RecurrenteCheckoutCallback? onPaymentInProgress;

  /// Called after the underlying WebView controller is created.
  final ValueChanged<WebViewController>? onWebViewCreated;

  /// Called when WebView navigation starts.
  final ValueChanged<String>? onPageStarted;

  /// Called when WebView navigation finishes.
  final ValueChanged<String>? onPageFinished;

  /// Called when the WebView reports a resource error.
  final ValueChanged<WebResourceError>? onWebResourceError;

  /// Expected checkout event origin.
  final String allowedOrigin;

  /// Allows checkout events from any origin, useful for local development.
  final bool development;

  /// WebView background color.
  final Color backgroundColor;

  /// Default production origin for checkout events.
  static const defaultAllowedOrigin = 'https://app.recurrente.com';

  /// Returns a checkout URI with `embed=true` present.
  static Uri embeddedUri(Uri url) {
    if (url.queryParameters['embed'] == 'true') {
      return url;
    }

    return url.replace(
      queryParameters: <String, String>{
        ...url.queryParameters,
        'embed': 'true',
      },
    );
  }

  @override
  State<RecurrenteCheckout> createState() => _RecurrenteCheckoutState();
}

class _RecurrenteCheckoutState extends State<RecurrenteCheckout> {
  static const _channelName = 'RecurrenteCheckoutBridge';

  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(widget.backgroundColor)
      ..addJavaScriptChannel(
        _channelName,
        onMessageReceived: _handleJavaScriptMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            widget.onPageStarted?.call(url);
          },
          onPageFinished: (url) {
            _installMessageBridge();
            widget.onPageFinished?.call(url);
          },
          onWebResourceError: (error) {
            widget.onWebResourceError?.call(error);
          },
        ),
      )
      ..loadRequest(RecurrenteCheckout.embeddedUri(widget.url));

    widget.onWebViewCreated?.call(_controller);
  }

  @override
  void didUpdateWidget(covariant RecurrenteCheckout oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.backgroundColor != widget.backgroundColor) {
      unawaited(_controller.setBackgroundColor(widget.backgroundColor));
    }

    if (oldWidget.url != widget.url) {
      unawaited(
        _controller.loadRequest(RecurrenteCheckout.embeddedUri(widget.url)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }

  void _installMessageBridge() {
    unawaited(
      _controller.runJavaScript('''
        (function () {
          if (window.__recurrenteCheckoutBridgeInstalled) return;
          window.__recurrenteCheckoutBridgeInstalled = true;

          window.addEventListener('message', function (event) {
            if (!event.data || !event.data.type) return;
            if (String(event.data.type).indexOf('recurrente-plugin:') !== 0) {
              return;
            }

            window.$_channelName.postMessage(JSON.stringify({
              origin: event.origin,
              data: event.data
            }));
          });
        })();
      ''').onError<Object>((_, _) {}),
    );
  }

  void _handleJavaScriptMessage(JavaScriptMessage message) {
    final decoded = _decodeMessage(message.message);
    if (decoded == null) {
      return;
    }

    final origin = decoded.origin;
    if (!widget.development && origin != widget.allowedOrigin) {
      return;
    }

    final checkoutMessage = RecurrenteCheckoutMessage(
      origin: origin,
      payload: decoded.payload,
    );

    switch (checkoutMessage.type) {
      case RecurrenteCheckoutMessage.paymentSuccessType:
        widget.onSuccess?.call(checkoutMessage);
      case RecurrenteCheckoutMessage.paymentFailedType:
        widget.onFailure?.call(checkoutMessage);
      case RecurrenteCheckoutMessage.paymentInProgressType:
        widget.onPaymentInProgress?.call(checkoutMessage);
    }
  }

  _DecodedCheckoutMessage? _decodeMessage(String rawMessage) {
    final Object? decoded;

    try {
      decoded = jsonDecode(rawMessage);
    } on FormatException {
      return null;
    }

    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final origin = decoded['origin'];
    final data = decoded['data'];

    if (origin is! String || data is! Map) {
      return null;
    }

    return _DecodedCheckoutMessage(
      origin: origin,
      payload: Map<String, dynamic>.from(data),
    );
  }
}

class _DecodedCheckoutMessage {
  const _DecodedCheckoutMessage({
    required this.origin,
    required this.payload,
  });

  final String origin;
  final Map<String, dynamic> payload;
}
