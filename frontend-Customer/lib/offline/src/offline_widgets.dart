import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'navigation_service.dart';
import 'trip_session.dart';

String offlineErrorMessage(Object error, String fallback) {
  if (error is FormatException) {
    return error.message.replaceFirst(RegExp(r'^FormatException:\s*'), '');
  }
  if (error is StateError) return error.message.toString();
  return fallback;
}

/// Colours shared by every offline-trip screen. The brand blue comes from the
/// host app's theme so the Driver and Customer apps each keep their own primary.
class OfflineUi {
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
  static const panel = Color(0xFF161F33);
  static const stroke = Color(0x14FFFFFF);
  static const muted = Color(0xFF9CA3AF);
  static const accent = Color(0xFF69A8FF);
}

enum OfflineTone { info, success, warning, danger }

Color _toneColor(OfflineTone tone) => switch (tone) {
  OfflineTone.info => OfflineUi.accent,
  OfflineTone.success => OfflineUi.success,
  OfflineTone.warning => OfflineUi.warning,
  OfflineTone.danger => OfflineUi.danger,
};

/// Rounded dark panel used instead of plain Cards so sections look consistent.
class OfflinePanel extends StatelessWidget {
  const OfflinePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.highlight = false,
    this.onTap,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool highlight;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: highlight ? primary.withValues(alpha: 0.14) : OfflineUi.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: highlight ? primary.withValues(alpha: 0.55) : OfflineUi.stroke,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Inline message that replaces bare red/grey text.
class OfflineNotice extends StatelessWidget {
  const OfflineNotice(
    this.message, {
    super.key,
    this.tone = OfflineTone.info,
    this.icon,
    this.action,
    this.onAction,
  });
  final String message;
  final OfflineTone tone;
  final IconData? icon;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) {
    final color = _toneColor(tone);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              icon ??
                  switch (tone) {
                    OfflineTone.info => Icons.info_outline_rounded,
                    OfflineTone.success => Icons.check_circle_outline_rounded,
                    OfflineTone.warning => Icons.warning_amber_rounded,
                    OfflineTone.danger => Icons.error_outline_rounded,
                  },
              size: 20,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 1, right: 4),
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: color,
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: Text(action!),
            ),
        ],
      ),
    );
  }
}

/// Small coloured status label.
class OfflineStatusPill extends StatelessWidget {
  const OfflineStatusPill(
    this.label, {
    super.key,
    this.tone = OfflineTone.info,
    this.icon,
  });
  final String label;
  final OfflineTone tone;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final color = _toneColor(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Screen heading: coloured icon badge, title and a one-line explanation.
class OfflineHeader extends StatelessWidget {
  const OfflineHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: OfflineUi.accent),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.3,
                      color: OfflineUi.muted,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Label / value line used in offer and trip detail panels.
class OfflineInfoRow extends StatelessWidget {
  const OfflineInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });
  final IconData icon;
  final String label;
  final String value;
  final bool highlight;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(icon, size: 18, color: OfflineUi.muted),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(color: OfflineUi.muted, fontSize: 14),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: highlight ? const Color(0xFF4ADE80) : Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: highlight ? 16 : 14,
            ),
          ),
        ),
      ],
    ),
  );
}

class OfflineReadinessCard extends StatefulWidget {
  const OfflineReadinessCard({
    super.key,
    required this.accountReady,
    required this.accountLabel,
  });
  final bool accountReady;
  final String accountLabel;
  @override
  State<OfflineReadinessCard> createState() => _OfflineReadinessCardState();
}

class _OfflineReadinessCardState extends State<OfflineReadinessCard>
    with WidgetsBindingObserver {
  bool? _mapReady;
  bool _gps = false, _permission = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  Future<void> _check() async {
    try {
      final permission = await Geolocator.checkPermission();
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (mounted) {
        setState(() {
          _permission = [
            LocationPermission.always,
            LocationPermission.whileInUse,
          ].contains(permission);
          _gps = enabled;
        });
      }
    } catch (_) {}
    try {
      await OfflineNavigationService.instance.request('info', {});
      if (mounted) setState(() => _mapReady = true);
    } catch (_) {
      if (mounted) setState(() => _mapReady = false);
    }
  }

  Future<void> _enableGps() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
      } else if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      } else if (!await Geolocator.isLocationServiceEnabled()) {
        await Geolocator.openLocationSettings();
      }
      await _check();
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gpsOk = _gps && _permission;
    return OfflinePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ready for an offline trip',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OfflineStatusPill(
                _mapReady == null
                    ? 'Checking map…'
                    : _mapReady!
                    ? 'Map ready'
                    : 'Map unavailable',
                tone: _mapReady == null
                    ? OfflineTone.info
                    : _mapReady!
                    ? OfflineTone.success
                    : OfflineTone.warning,
                icon: Icons.map_rounded,
              ),
              GestureDetector(
                onTap: gpsOk ? null : _enableGps,
                child: OfflineStatusPill(
                  !_permission
                      ? 'Allow location'
                      : !_gps
                      ? 'Turn on GPS'
                      : 'Location ready',
                  tone: gpsOk ? OfflineTone.success : OfflineTone.warning,
                  icon: gpsOk ? Icons.gps_fixed : Icons.gps_off,
                ),
              ),
              OfflineStatusPill(
                widget.accountLabel,
                tone: widget.accountReady
                    ? OfflineTone.success
                    : OfflineTone.info,
                icon: widget.accountReady
                    ? Icons.check_circle
                    : Icons.info_outline,
              ),
            ],
          ),
          if (_mapReady == false)
            TextButton(onPressed: _check, child: const Text('Check map again')),
          const SizedBox(height: 8),
          const Text(
            'Maps and navigation work without mobile data.',
            style: TextStyle(fontSize: 12, color: OfflineUi.muted),
          ),
        ],
      ),
    );
  }
}

/// Three-step handshake progress. [stage] is the step in progress (0-based);
/// earlier steps show a tick. Pass [labels] for different wording.
class OfflineHandshakeSteps extends StatelessWidget {
  const OfflineHandshakeSteps({
    super.key,
    this.stage = 0,
    this.labels = const ['Scan driver', 'Show offer', 'Scan confirmation'],
  });
  final int stage;
  final List<String> labels;
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 15),
                  child: Container(
                    height: 2,
                    color: i <= stage
                        ? primary
                        : Colors.white.withValues(alpha: 0.12),
                  ),
                ),
              ),
            SizedBox(
              width: 84,
              child: Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < stage
                          ? OfflineUi.success
                          : i == stage
                          ? primary
                          : OfflineUi.panel,
                      border: Border.all(
                        color: i <= stage
                            ? Colors.transparent
                            : OfflineUi.stroke,
                      ),
                    ),
                    child: i < stage
                        ? const Icon(Icons.check, size: 18, color: Colors.white)
                        : Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: i == stage
                                  ? Colors.white
                                  : OfflineUi.muted,
                            ),
                          ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.2,
                      fontWeight: i == stage
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: i == stage ? Colors.white : OfflineUi.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class OfflineJourneyCard extends StatelessWidget {
  const OfflineJourneyCard({
    super.key,
    required this.trip,
    required this.driverMode,
    required this.onTap,
  });
  final TripSession trip;
  final bool driverMode;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final synced = trip.data['serverId'] != null;
    final active = !trip.completed;
    final status = active
        ? 'Trip in progress'
        : synced
        ? 'Synced'
        : driverMode
        ? 'Waiting to sync'
        : 'Saved on this phone';
    final tone = active
        ? OfflineTone.info
        : synced
        ? OfflineTone.success
        : OfflineTone.warning;
    final destination = trip.data['destination'];
    final other = trip.data[driverMode ? 'customerName' : 'driverName']
        ?.toString();
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: OfflinePanel(
        highlight: active,
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: active
                    ? primary.withValues(alpha: 0.35)
                    : Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                active
                    ? Icons.directions_car_rounded
                    : Icons.receipt_long_rounded,
                color: active ? Colors.white : OfflineUi.muted,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    active
                        ? 'Resume active trip'
                        : (other == null || other.isEmpty
                              ? 'Offline trip'
                              : other),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${destination is Map ? '${destination['name']} · ' : ''}${trip.distanceKm.toStringAsFixed(2)} km · Rs. ${trip.fare.toStringAsFixed(2)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: OfflineUi.muted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OfflineStatusPill(status, tone: tone),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: OfflineUi.muted),
          ],
        ),
      ),
    );
  }
}

/// Camera overlay: dimmed surround, a rounded scan window and a hint below it.
/// Place above a MobileScanner in a Stack.
class OfflineScannerOverlay extends StatelessWidget {
  const OfflineScannerOverlay({
    super.key,
    required this.hint,
    this.busy = false,
    this.hasError = false,
  });
  final String hint;
  final bool busy;
  final bool hasError;
  static const _size = 250.0;
  @override
  Widget build(BuildContext context) {
    final color = hasError
        ? OfflineUi.danger
        : busy
        ? OfflineUi.warning
        : OfflineUi.success;
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _ScanDimPainter(_size)),
          Center(
            child: Container(
              width: _size,
              height: _size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: color, width: 3),
              ),
              child: busy
                  ? Center(
                      child: CircularProgressIndicator(
                        color: color,
                        strokeWidth: 3,
                      ),
                    )
                  : null,
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.only(top: _size + 64),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  busy ? 'Checking…' : hint,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanDimPainter extends CustomPainter {
  _ScanDimPainter(this.window);
  final double window;
  @override
  void paint(Canvas canvas, Size size) {
    final hole = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: size.center(Offset.zero),
        width: window,
        height: window,
      ),
      const Radius.circular(24),
    );
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(hole);
    canvas.drawPath(path, Paint()..color = const Color(0x99000000));
  }

  @override
  bool shouldRepaint(_ScanDimPainter old) => old.window != window;
}

/// Haptic tick used when a handshake step succeeds.
void offlineTick() => HapticFeedback.mediumImpact();
