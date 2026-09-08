import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/trip_provider.dart';
import '../theme.dart';
import 'home_tab.dart';
import 'profile_tab.dart';
import 'qr_scan.dart';
import 'settings_tab.dart';
import 'trips_tab.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 2;
  final _qrTabActive = ValueNotifier<bool>(false);
  final _navigatorKeys = List.generate(5, (_) => GlobalKey<NavigatorState>());

  late final List<Widget> _screens = [
    const ProfileTab(),
    QRScan(activeListenable: _qrTabActive),
    const HomeTab(),
    const TripsTab(),
    const SettingsTab(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TripProvider>().load(refresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasOngoingTrip = context.watch<TripProvider>().hasOngoingTrip;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final navigator = _navigatorKeys[_currentIndex].currentState;
        if (navigator != null && navigator.canPop()) {
          navigator.pop();
          return;
        }
        SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: IndexedStack(
          index: _currentIndex,
          children: List.generate(
            _screens.length,
            (index) => Navigator(
              key: _navigatorKeys[index],
              onGenerateRoute: (_) =>
                  MaterialPageRoute(builder: (_) => _screens[index]),
            ),
          ),
        ),
        bottomNavigationBar: _FooterNavigationBar(
          selectedIndex: _currentIndex,
          hasOngoingTrip: hasOngoingTrip,
          onSelected: _selectDestination,
        ),
      ),
    );
  }

  void _selectDestination(int index) {
    _qrTabActive.value = index == 1;
    if (index == _currentIndex) {
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
      return;
    }
    setState(() => _currentIndex = index);
  }

  @override
  void dispose() {
    _qrTabActive.dispose();
    super.dispose();
  }
}

class _FooterNavigationBar extends StatelessWidget {
  const _FooterNavigationBar({
    required this.selectedIndex,
    required this.hasOngoingTrip,
    required this.onSelected,
  });

  final int selectedIndex;
  final bool hasOngoingTrip;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Container(
        height: 74,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: Color(0x80000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
            BoxShadow(
              color: Color(0x4D000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              _FooterNavigationItem(
                label: 'Profile',
                selected: selectedIndex == 0,
                onTap: () => onSelected(0),
                icon: const Icon(Icons.person_rounded, size: 22),
              ),
              _FooterNavigationItem(
                label: 'QR',
                selected: selectedIndex == 1,
                onTap: () => onSelected(1),
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 22),
              ),
              _FooterNavigationItem(
                label: 'Home',
                selected: selectedIndex == 2,
                onTap: () => onSelected(2),
                icon: const Icon(Icons.home_rounded, size: 22),
              ),
              _FooterNavigationItem(
                label: 'Trips',
                selected: selectedIndex == 3,
                onTap: () => onSelected(3),
                icon: _TripNavigationIcon(
                  icon: Icons.directions_car_rounded,
                  size: 22,
                  showOngoing: hasOngoingTrip,
                ),
              ),
              _FooterNavigationItem(
                label: 'Settings',
                selected: selectedIndex == 4,
                onTap: () => onSelected(4),
                icon: const Icon(Icons.settings_rounded, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterNavigationItem extends StatefulWidget {
  const _FooterNavigationItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Widget icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_FooterNavigationItem> createState() => _FooterNavigationItemState();
}

class _FooterNavigationItemState extends State<_FooterNavigationItem> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  bool get _highlighted => widget.selected || _hovered || _focused || _pressed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Semantics(
          button: true,
          selected: widget.selected,
          label: widget.label,
          child: Tooltip(
            message: widget.label,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                onHover: (value) => setState(() => _hovered = value),
                onFocusChange: (value) => setState(() => _focused = value),
                onHighlightChanged: (value) => setState(() => _pressed = value),
                borderRadius: BorderRadius.circular(12),
                splashColor: AppTheme.primary.withValues(alpha: 0.12),
                highlightColor: Colors.transparent,
                hoverColor: Colors.transparent,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedScale(
                      scale: _pressed ? 0.94 : 1,
                      duration: const Duration(milliseconds: 120),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: _highlighted
                              ? const Color(0xFF4B5563)
                              : const Color(0xFF374151),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: widget.selected || _hovered || _focused
                                ? AppTheme.primary
                                : Colors.transparent,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: _highlighted ? 0.24 : 0.14,
                              ),
                              blurRadius: _highlighted ? 6 : 3,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconTheme(
                          data: IconThemeData(
                            color: widget.selected
                                ? AppTheme.accent
                                : AppTheme.mutedText,
                          ),
                          child: Center(child: widget.icon),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: widget.selected
                            ? AppTheme.accent
                            : AppTheme.mutedText,
                        fontSize: 9,
                        fontWeight: widget.selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TripNavigationIcon extends StatefulWidget {
  const _TripNavigationIcon({
    required this.icon,
    required this.size,
    required this.showOngoing,
  });

  final IconData icon;
  final double size;
  final bool showOngoing;

  @override
  State<_TripNavigationIcon> createState() => _TripNavigationIconState();
}

class _TripNavigationIconState extends State<_TripNavigationIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _opacity = Tween<double>(
      begin: 0.25,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _TripNavigationIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showOngoing != widget.showOngoing) _syncAnimation();
  }

  void _syncAnimation() {
    if (widget.showOngoing) {
      _controller.repeat(reverse: true);
    } else {
      _controller
        ..stop()
        ..value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(widget.icon, size: widget.size),
        if (widget.showOngoing)
          Positioned(
            top: -5,
            right: -7,
            child: FadeTransition(
              opacity: _opacity,
              child: Semantics(
                label: 'Ongoing trip',
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFF24D17E),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF070B12),
                      width: 2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x9924D17E),
                        blurRadius: 7,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
