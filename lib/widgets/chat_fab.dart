import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/main/support_chat_page.dart';

// ─── preference keys ──────────────────────────────────────────────────────────
const _kPrefVisible = 'chat_fab_visible';
const _kPrefX = 'chat_fab_x';
const _kPrefY = 'chat_fab_y';

// ─── sizing constants ─────────────────────────────────────────────────────────
const _kBtnSize = 58.0;
const _kTrashZoneH = 88.0;

/// Global notifier so the Settings panel can toggle the FAB visibility without
/// routing to the MainScreen.  Initial value is [true]; overwritten once
/// SharedPreferences are loaded.
final chatFabNotifier = ValueNotifier<bool>(true);

/// Draggable floating chatbot button that overlays every screen inside
/// [MainScreen].
///
/// Drag to anywhere on screen — position is persisted across sessions.
/// Drag into the bottom **trash zone** to hide it (re-enable in Settings).
/// Tap to open [SupportChatPage].
class ChatFab extends StatefulWidget {
  const ChatFab({super.key});

  @override
  State<ChatFab> createState() => _ChatFabState();
}

class _ChatFabState extends State<ChatFab> with SingleTickerProviderStateMixin {
  // ── state ─────────────────────────────────────────────────────────────────

  Offset? _pos; // null → use computed default bottom-right
  bool _visible = true;
  bool _prefsLoaded = false;

  /// Local area this widget actually occupies (set from [LayoutBuilder] each
  /// build) — NOT `MediaQuery.sizeOf`, which is the full device screen and
  /// includes the AppBar. [MainScreen]'s Scaffold has an AppBar, so the body
  /// Stack this widget lives in is shorter than the device screen; using the
  /// device size to place/clamp the button let it drift past the bottom of
  /// the actually-clipped local Stack, where it's out of paint/hit-test
  /// range and looks "stuck"/undraggable.
  Size _localSize = Size.zero;

  // drag tracking
  bool _isDragging = false;
  bool _overTrash = false;

  /// Where the finger went down (global) — used to tell a tap from a drag
  /// ourselves, see [_onPointerMove].
  Offset? _pointerDownPos;
  bool _dragArmed = false;

  // pulse animation while idle
  late final AnimationController _pulse;
  late final Animation<double> _pulseAnim;

  // ── lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.07).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
    _loadPrefs();
    chatFabNotifier.addListener(_onGlobalToggle);
  }

  @override
  void dispose() {
    _pulse.dispose();
    chatFabNotifier.removeListener(_onGlobalToggle);
    super.dispose();
  }

  // ── settings notifier ─────────────────────────────────────────────────────

  void _onGlobalToggle() {
    if (!mounted) return;
    setState(() => _visible = chatFabNotifier.value);
    _persistPrefs();
  }

  // ── SharedPreferences ─────────────────────────────────────────────────────

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final visible = prefs.getBool(_kPrefVisible) ?? true;
    final x = prefs.getDouble(_kPrefX);
    final y = prefs.getDouble(_kPrefY);
    // Sync global notifier without triggering listener loop.
    chatFabNotifier.removeListener(_onGlobalToggle);
    chatFabNotifier.value = visible;
    chatFabNotifier.addListener(_onGlobalToggle);
    setState(() {
      _visible = visible;
      _pos = (x != null && y != null) ? Offset(x, y) : null;
      _prefsLoaded = true;
    });
  }

  Future<void> _persistPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefVisible, _visible);
    if (_pos != null) {
      await prefs.setDouble(_kPrefX, _pos!.dx);
      await prefs.setDouble(_kPrefY, _pos!.dy);
    }
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  Offset _defaultPos(Size screen) => Offset(
        screen.width - _kBtnSize - 18,
        screen.height - _kBtnSize - 190,
      );

  Offset _clamp(Offset p, Size screen) => Offset(
        p.dx.clamp(0.0, screen.width - _kBtnSize),
        p.dy.clamp(0.0, screen.height - _kBtnSize - 80),
      );

  bool _hitTrash(Offset p, Size screen) =>
      p.dy + _kBtnSize / 2 >= screen.height - _kTrashZoneH;

  // ── gesture handlers ──────────────────────────────────────────────────────
  //
  // Raw `Listener` pointer events instead of `GestureDetector`'s onPan* —
  // GestureDetector's pan recognizer has to disambiguate against the tap
  // recognizer in the gesture arena, so it withholds roughly the first
  // 18-36 logical pixels of movement as "slop" before committing to a drag.
  // That reads as "moves a little, then catches up" on the first grab.
  // Pointer events have no arena/slop — every pixel of movement is reported
  // immediately — so we do the tap-vs-drag call ourselves with a small
  // fixed threshold instead.

  static const double _dragArmThreshold = 4.0;

  void _onPointerDown(PointerDownEvent event) {
    _pointerDownPos = event.position;
    _dragArmed = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    final screen = _localSize;
    if (screen == Size.zero) return;

    if (!_dragArmed) {
      final start = _pointerDownPos ?? event.position;
      if ((event.position - start).distance < _dragArmThreshold) return;
      _dragArmed = true;
      setState(() {
        _isDragging = true;
        _overTrash = false;
      });
    }

    final cur = _pos ?? _defaultPos(screen);
    final next = _clamp(cur + event.delta, screen);
    setState(() {
      _pos = next;
      _overTrash = _hitTrash(next, screen);
    });
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_dragArmed) {
      _finishDrag();
    } else {
      _onTap();
    }
    _dragArmed = false;
    _pointerDownPos = null;
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (_dragArmed) _finishDrag();
    _dragArmed = false;
    _pointerDownPos = null;
  }

  void _finishDrag() {
    if (_overTrash) {
      setState(() {
        _visible = false;
        _isDragging = false;
        _overTrash = false;
      });
      chatFabNotifier.removeListener(_onGlobalToggle);
      chatFabNotifier.value = false;
      chatFabNotifier.addListener(_onGlobalToggle);
      _persistPrefs();
    } else {
      setState(() {
        _isDragging = false;
        _overTrash = false;
      });
      _persistPrefs();
    }
  }

  void _onTap() {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SupportChatPage()),
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_prefsLoaded || !_visible) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;

    // Every child below is `Positioned`, so a bare `Stack` collapses to zero
    // size (no non-positioned child to size against) — it still paints via
    // overflow, but hit-testing then fails everywhere the button is actually
    // drawn. `SizedBox.expand` forces the Stack to the full available area
    // so drags/taps land where the button visually is.
    return SizedBox.expand(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screen = constraints.biggest;
          _localSize = screen;
          final pos = _pos ?? _defaultPos(screen);

          return Stack(
            children: [
              // ── trash zone ──────────────────────────────────────────────────────
              if (_isDragging)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: _kTrashZoneH,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: _overTrash
                          ? cs.error.withValues(alpha: 0.88)
                          : cs.errorContainer.withValues(alpha: 0.72),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(22),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedScale(
                          scale: _overTrash ? 1.3 : 1.0,
                          duration: const Duration(milliseconds: 180),
                          child: Icon(
                            Icons.delete_rounded,
                            color:
                                _overTrash ? Colors.white : cs.onErrorContainer,
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Устгах',
                          style: TextStyle(
                            color:
                                _overTrash ? Colors.white : cs.onErrorContainer,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ── FAB ────────────────────────────────────────────────────────────
              Positioned(
                left: pos.dx,
                top: pos.dy,
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: _onPointerDown,
                  onPointerMove: _onPointerMove,
                  onPointerUp: _onPointerUp,
                  onPointerCancel: _onPointerCancel,
                  child: ScaleTransition(
                    scale: _isDragging
                        ? const AlwaysStoppedAnimation(1.12)
                        : _pulseAnim,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: _kBtnSize,
                      height: _kBtnSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: _overTrash
                              ? [cs.error, cs.error.withValues(alpha: 0.8)]
                              : const [Color(0xFFFF4469), Color(0xFFff6b8a)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (_overTrash
                                    ? cs.error
                                    : const Color(0xFFFF4469))
                                .withValues(alpha: _isDragging ? 0.55 : 0.38),
                            blurRadius: _isDragging ? 22 : 14,
                            spreadRadius: _isDragging ? 4 : 1,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.support_agent_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
