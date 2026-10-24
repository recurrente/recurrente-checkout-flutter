import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:recurrente_checkout_flutter/recurrente_checkout_flutter.dart';

void main() => runApp(const CheckoutExampleApp());

/// Demonstrates the host lifecycle without creating a real checkout.
class CheckoutExampleApp extends StatelessWidget {
  /// Creates the example.
  const CheckoutExampleApp({super.key});

  @override
  Widget build(BuildContext context) =>
      const MaterialApp(home: CheckoutScreen());
}

/// Provide an authorized test checkout with --dart-define=CHECKOUT_URL=... .
class CheckoutScreen extends StatefulWidget {
  /// Creates the example checkout screen.
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  static const checkoutUrl = String.fromEnvironment('CHECKOUT_URL');
  final checkout = RecurrenteCheckoutController();
  bool closed = false;
  String status = 'El estado del pago se debe confirmar en tu backend.';

  void reconcile() {
    // Replace with an authenticated call to YOUR backend for this order.
    if (mounted) {
      setState(
        () => status = 'Consulta tu backend antes de confirmar o reintentar.',
      );
    }
  }

  Future<List<String>> pickFiles(FileSelectorParams params) async {
    final mimeTypes = params.acceptTypes
        .where((type) => type.contains('/'))
        .toList();
    final groups = mimeTypes.isEmpty
        ? <XTypeGroup>[]
        : [XTypeGroup(label: 'Comprobante', mimeTypes: mimeTypes)];
    final files = params.mode == FileSelectorMode.openMultiple
        ? await openFiles(acceptedTypeGroups: groups)
        : [
            await openFile(acceptedTypeGroups: groups),
          ].whereType<XFile>().toList();
    return files
        .map(
          (file) => Uri.tryParse(file.path)?.hasScheme == true
              ? file.path
              : Uri.file(file.path).toString(),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: closed || checkoutUrl.isEmpty,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) checkout.cancel();
    },
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Checkout de prueba'),
        actions: [
          TextButton(
            onPressed: () => checkout.cancel(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(padding: const EdgeInsets.all(12), child: Text(status)),
            Expanded(
              child: checkoutUrl.isEmpty
                  ? const Center(
                      child: Text(
                        'Define CHECKOUT_URL con un checkout de prueba autorizado.',
                      ),
                    )
                  : closed
                  ? const Center(
                      child: Text(
                        'Checkout cerrado. Verifica el pedido en tu backend.',
                      ),
                    )
                  : RecurrenteCheckout(
                      url: Uri.parse(checkoutUrl),
                      controller: checkout,
                      returnUrls: [Uri.parse('myapp://checkout/result')],
                      onSuccess: (_) => reconcile(),
                      onPaymentInProgress: (_) => reconcile(),
                      onReturn: (_) => reconcile(),
                      onFailure: (_) {
                        if (mounted) {
                          setState(
                            () => status =
                                'Intento rechazado. Puedes reintentar aquí.',
                          );
                        }
                      },
                      onCancel: () {
                        reconcile();
                        if (mounted) setState(() => closed = true);
                      },
                      onError: (_) => reconcile(),
                      onFileSelector: pickFiles,
                      onExternalNavigation: (_) {
                        // This demo does not automatically launch external links.
                        if (mounted) {
                          setState(
                            () => status =
                                'Tu app debe autorizar y abrir este enlace externo.',
                          );
                        }
                      },
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}
