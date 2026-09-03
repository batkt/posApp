import 'dart:async';

import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/payment_display_config.dart';
import '../models/auth_model.dart';
import '../models/cart_model.dart';
import '../models/sales_model.dart';
import '../payment/pos_payment_core.dart';
import '../screens/shared/receipt_screen.dart';
import '../services/background_watchdog_service.dart';
import '../services/pos_transaction_service.dart';
import '../services/socket_service.dart';
import '../services/terminal_tulbur_signal_service.dart';
import '../services/unipos_service.dart';
import '../utils/mnt_amount_formatter.dart';
import '../utils/pos_native_debug_log.dart';

/// Listens for mobile-initiated card payment requests (`terminalTulburKhuseelt`)
/// and automatically opens UniPOS card payment terminal on this POS device.
class KioskTerminalPaySignalListener extends StatefulWidget {
  const KioskTerminalPaySignalListener({super.key, required this.child});

  final Widget child;

  @override
  State<KioskTerminalPaySignalListener> createState() =>
      _KioskTerminalPaySignalListenerState();
}

class _KioskTerminalPaySignalListenerState
    extends State<KioskTerminalPaySignalListener>
    with WidgetsBindingObserver {
  Timer? _timer;
  StreamSubscription? _socketSub;
  final TerminalTulburSignalService _svc = TerminalTulburSignalService();
  final Set<String> _handledIds = {};
  bool _pollInFlight = false;
  bool _isProcessingCardRequest = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      debugPrint('>>> [KioskTerminalPaySignalListener] Non-Android platform detected (iPad/iOS/Web) — disabling remote terminal listener');
      return;
    }
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listenSocket();
      _armTimer();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('>>> [KioskTerminalPaySignalListener] App RESUMED — checking pending card requests');
      _poll();
    }
  }

  void _listenSocket() {
    _socketSub?.cancel();
    _socketSub = SocketService.instance.terminalTulburKhuseeltStream.listen((data) {
      final item = TerminalPaySignalItem.tryParse(data);
      if (item != null && !_handledIds.contains(item.id) && !_isProcessingCardRequest) {
        debugPrint('>>> [KioskTerminalPaySignalListener] Socket.IO card request received: ${item.id}');
        _processPayRequest(item);
      }
    });
  }

  void _armTimer() {
    _timer?.cancel();
    if (!mounted) return;
    final auth = context.read<AuthModel>();
    if (auth.posSession == null) return;
    final pollInterval = SocketService.instance.isConnected
        ? const Duration(seconds: 8)
        : const Duration(seconds: 3);
    _timer = Timer.periodic(pollInterval, (_) => _poll());
    _poll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _socketSub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (!mounted || _pollInFlight || _isProcessingCardRequest) return;
    _pollInFlight = true;
    final auth = context.read<AuthModel>();
    final session = auth.posSession;
    if (session == null) {
      _pollInFlight = false;
      return;
    }

    List<TerminalPaySignalItem> list;
    try {
      list = await _svc.fetchPending(
        baiguullagiinId: session.baiguullagiinId,
        salbariinId: session.salbariinId,
      );
    } catch (_) {
      _pollInFlight = false;
      return;
    }

    if (!mounted || list.isEmpty) {
      _pollInFlight = false;
      return;
    }

    for (final item in list) {
      if (!_handledIds.contains(item.id) && !_isProcessingCardRequest) {
        await _processPayRequest(item);
        break;
      }
    }
    _pollInFlight = false;
  }

  Future<void> _processPayRequest(TerminalPaySignalItem item) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (_handledIds.contains(item.id) || _isProcessingCardRequest) {
      debugPrint('>>> [KioskTerminalPaySignalListener] Skipping duplicate/concurrent card pay request: ${item.id}');
      return;
    }
    _isProcessingCardRequest = true;
    _handledIds.add(item.id); // Permanently remember to prevent infinite loops on resume!
    final auth = context.read<AuthModel>();
    final session = auth.posSession;
    PosNativeDebugLog.record(
      'KioskPaySignal',
      'EXECUTING CARD PAY REQUEST',
      <String, dynamic>{
        'id': item.id,
        'amountMnt': item.amountMnt,
        'initiatorNer': item.initiatorNer,
        'tailbar': item.tailbar,
      },
      baiguullagiinId: session?.baiguullagiinId,
      salbariinId: session?.salbariinId,
    );
    debugPrint('>>> [KioskTerminalPaySignalListener] EXECUTING CARD PAY REQUEST: ${item.id} (${item.amountMnt}₮) from ${item.initiatorNer}');

    final messenger = ScaffoldMessenger.of(context);

    // Protect active UniPOS transaction from watchdog disruption for 2 minutes
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        terminalWatchdogHeartbeatKey,
        DateTime.now().add(const Duration(minutes: 5)).toIso8601String(),
      );
    } catch (_) {}
    try {
      // If app is currently backgrounded/minimized, bring MainActivity to foreground first
      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        debugPrint('>>> [KioskTerminalPaySignalListener] App backgrounded — bringing MainActivity to foreground before UniPOS launch');
        try {
          await const AndroidIntent(
            action: 'android.intent.action.MAIN',
            category: 'android.intent.category.LAUNCHER',
            package: 'mn.posease.mobile.terminal.pos',
            componentName: 'mn.posease.mobile.terminal.pos.MainActivity',
            flags: <int>[
              Flag.FLAG_ACTIVITY_NEW_TASK,
              Flag.FLAG_ACTIVITY_CLEAR_TOP,
              Flag.FLAG_ACTIVITY_SINGLE_TOP,
            ],
          ).launch();
          await Future.delayed(const Duration(milliseconds: 600));
        } catch (e) {
          debugPrint('Failed to bring MainActivity to foreground: $e');
        }
      }

      if (mounted && WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        try {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                'Картын төлбөрийн хүсэлт (${MntAmountFormatter.formatTugrik(item.amountMnt)}) — ПОС нээж байна...',
              ),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.blue.shade800,
            ),
          );
        } catch (_) {}
      }

      // Auto-launch UniPOS payment terminal
      final res = await UniPosService.purchase(amount: item.amountMnt);
      PosNativeDebugLog.record('KioskPaySignal', 'UNIPOS PURCHASE RESPONSE', res);
      UniPosService.requireSuccessfulTerminalCardPayment(res);

      // Re-bring MainActivity to foreground immediately after purchase completes on touchscreen devices
      try {
        await const AndroidIntent(
          action: 'android.intent.action.MAIN',
          category: 'android.intent.category.LAUNCHER',
          package: 'mn.posease.mobile.terminal.pos',
          componentName: 'mn.posease.mobile.terminal.pos.MainActivity',
          flags: <int>[
            Flag.FLAG_ACTIVITY_NEW_TASK,
            Flag.FLAG_ACTIVITY_CLEAR_TOP,
            Flag.FLAG_ACTIVITY_SINGLE_TOP,
          ],
        ).launch();
        await Future.delayed(const Duration(milliseconds: 300));
      } catch (e) {
        debugPrint('Failed to re-bring MainActivity to foreground: $e');
      }

      await _svc.markCompleted(item.id);
      debugPrint('>>> [KioskTerminalPaySignalListener] Card payment successfully completed for ${item.id}');

      if (mounted) {
        final sales = context.read<SalesModel>();
        final auth = context.read<AuthModel>();
        final session = auth.posSession;

        final due = (sales.isSaleEmpty || sales.total <= 0) ? item.amountMnt : sales.total;
        final std = PosPaymentCore.calculateStandardSaleTotals(due);
        final tw = CashierTotals(
          cappedDiscount: 0,
          net: std.net,
          vat: std.vat,
          nhhat: 0,
          total: due,
        );

        String? guilgeeMongoId;
        String finalOrderNo = PaymentDisplayConfig.generateOrderPreview();

        if (session != null) {
          try {
            final svc = PosTransactionService();
            var orderNo = sales.guilgeeniiDugaar;
            if (orderNo == null || orderNo.isEmpty) {
              final d = await svc.fetchZakhialgiinDugaar(
                baiguullagiinId: session.baiguullagiinId,
              );
              if (d != null && d.isNotEmpty) {
                orderNo = d;
                sales.setGuilgeeniiDugaar(d);
              }
            }

            if (orderNo != null && orderNo.isNotEmpty) {
              finalOrderNo = orderNo;
            }

            if (item.baraanuud.isNotEmpty) {
              sales.clearSale();
              for (int i = 0; i < item.baraanuud.length; i++) {
                final raw = item.baraanuud[i];
                if (raw is Map) {
                  final b = Map<String, dynamic>.from(raw);
                  final double price = (b['price'] ?? b['zakhialakhPrice'] ?? b['hudaldahUne'] ?? 0).toDouble();
                  final double qty = (b['quantity'] ?? b['too'] ?? b['tooShirkheg'] ?? 1).toDouble();
                  final String rawCode = (b['code'] ?? b['dotooCode'] ?? '').toString();
                  final String rawBarCode = (b['barCode'] ?? (b['barKoduud'] is List && (b['barKoduud'] as List).isNotEmpty ? b['barKoduud'][0] : null) ?? rawCode).toString();

                  final p = Product(
                    id: (b['id'] ?? b['_id'] ?? 'item_${item.id}_$i').toString(),
                    name: (b['name'] ?? b['ner'] ?? 'Бараа').toString(),
                    description: (b['description'] ?? b['tailbar'] ?? '').toString(),
                    price: price,
                    category: (b['category'] ?? b['angilal'] ?? '').toString(),
                    imageUrl: (b['imageUrl'] ?? b['zurag'] ?? '').toString(),
                    code: rawCode.isNotEmpty ? rawCode : 'CARD',
                    barCode: rawBarCode.isNotEmpty ? rawBarCode : 'CARD',
                    khemjikhNegj: (b['khemjikhNegj'] ?? 'ш').toString(),
                    noatBodohEsekh: b['noatBodohEsekh'] ?? true,
                  );
                  sales.addToSale(p, customPrice: price);
                  if (qty > 1) {
                    sales.updateSaleQuantity(p.id, qty.round());
                  }
                }
              }
            } else if (sales.isSaleEmpty) {
              sales.addToSale(
                Product(
                  id: 'card_pay_${item.id}',
                  name: item.tailbar.isNotEmpty ? item.tailbar : 'Картын төлбөр',
                  description: 'Картын хүсэлтийн төлбөр',
                  price: item.amountMnt,
                  category: 'Картын төлбөр',
                  imageUrl: '',
                  code: 'CARD',
                  barCode: 'CARD',
                  khemjikhNegj: 'шир',
                  noatBodohEsekh: true,
                  ajilUilchilgeeEsekh: true,
                ),
              );
            }

            final saveResp = await svc.submitGuilgeeniiTuukh(
              session: session,
              sales: sales,
              paymentTurul:
                  PosTransactionService.paymentMethodToTurul(PosPaymentCore.methodCard),
              niitUne: due,
              tulsunDun: due,
              hariult: 0,
              hungulsunDun: 0,
              noatiinDun: std.vat,
              noatguiDun: std.net,
              nhatiinDun: 0,
              guilgeeniiDugaar: finalOrderNo,
              webTaxContext: sales.webTaxContext,
            );
            guilgeeMongoId =
                PosTransactionService.parseGuilgeeniiMongoIdFromSaveResponse(saveResp);
          } catch (e) {
            debugPrint('Error submitting guilgeenii tuukh after card payment: $e');
          }
        }

        final List<CartItem> receiptItems = (!sales.isSaleEmpty && sales.currentSaleItems.isNotEmpty)
            ? sales.currentSaleItems
                .map((i) => CartItem(product: i.product, quantity: i.quantity))
                .toList()
            : [
                CartItem(
                  product: Product(
                    id: 'card_pay_${item.id}',
                    name: item.tailbar.isNotEmpty ? item.tailbar : 'Картын төлбөр',
                    description: 'Картын хүсэлтийн төлбөр',
                    price: item.amountMnt,
                    category: 'Картын төлбөр',
                    imageUrl: '',
                    code: 'CARD',
                    barCode: 'CARD',
                    khemjikhNegj: 'шир',
                    noatBodohEsekh: true,
                    ajilUilchilgeeEsekh: true,
                  ),
                  quantity: 1,
                ),
              ];

        final completed = (!sales.isSaleEmpty && sales.currentSaleItems.isNotEmpty)
            ? sales.completeCashierSale(
                paymentMethod: PosPaymentCore.methodCard,
                discountMnt: 0,
                totalsSnapshot: tw,
                orderId: finalOrderNo,
              )
            : CompletedSale(
                id: finalOrderNo,
                items: receiptItems
                    .map((i) => SaleItem(
                          product: i.product,
                          unitPrice: i.product.price,
                          retailUnitPrice: i.product.price,
                          quantity: i.quantity,
                        ))
                    .toList(),
                subtotal: due,
                tax: std.vat,
                total: due,
                paymentMethod: PosPaymentCore.methodCard,
                timestamp: DateTime.now(),
                noatguiSum: std.net,
              );

        if (mounted) {
          final slip = CashierSlipTotals(
            grossSubtotal: completed.subtotal,
            discount: completed.discount,
            noatgui: completed.noatguiSum,
            noat: completed.tax,
            nhat: completed.nhhat,
            payable: completed.total,
          );

          // Always reset cart & sales model so main screen returns to a clean state
          sales.clearSale();

          // Pop active payment modals/dialogs so user lands directly on root main screen
          final nav = Navigator.of(context, rootNavigator: true);
          if (nav.canPop()) {
            nav.popUntil((route) => route.isFirst);
          }

          debugPrint('>>> [KioskTerminalPaySignalListener] REDIRECTING TO RECEIPT SCREEN orderNo=$finalOrderNo, total=$due');
          PosNativeDebugLog.record(
            'KioskPaySignal',
            'REDIRECTING TO RECEIPT SCREEN',
            <String, dynamic>{
              'orderNo': finalOrderNo,
              'total': due,
              'guilgeeMongoId': guilgeeMongoId,
            },
          );

          await nav.push(
            MaterialPageRoute(
              builder: (ctx) => ReceiptScreen(
                items: completed.items
                    .map((i) => CartItem(product: i.product, quantity: i.quantity))
                    .toList(),
                total: completed.total,
                paymentMethod: completed.paymentMethod,
                orderNumber: completed.id,
                guilgeeniiMongoId: guilgeeMongoId,
                cashierSlipTotals: slip,
              ),
            ),
          );
        }
      }
    } on Exception catch (e) {
      PosNativeDebugLog.record('KioskPaySignal', 'PAYMENT EXCEPTION / CANCELLED', '$e');
      debugPrint('>>> [KioskTerminalPaySignalListener] UniPOS transaction cancelled/failed: $e');
      // Cancel on backend so it is marked cancelled instead of staying pending
      try {
        await _svc.cancelRequest(item.id);
      } catch (_) {}

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Картын гүйлгээ цуцлагдлаа/алдаа гарлаа'),
            backgroundColor: Colors.orange.shade800,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      _isProcessingCardRequest = false;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          terminalWatchdogHeartbeatKey,
          DateTime.now().toIso8601String(),
        );
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
