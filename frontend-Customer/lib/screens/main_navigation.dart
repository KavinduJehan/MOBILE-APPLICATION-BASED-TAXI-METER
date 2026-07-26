import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/trip_provider.dart';
import '../theme.dart';
import 'home_tab.dart';
import 'profile_tab.dart';
import 'qr_scan.dart';
import 'trips_tab.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final _qrTabActive = ValueNotifier<bool>(false);
  final _navigatorKeys = List.generate(4, (_) => GlobalKey<NavigatorState>());

  late final List<Widget> _screens = [
    const HomeTab(),
    const TripsTab(),
    QRScan(activeListenable: _qrTabActive),
    const ProfileTab(),
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
    _qrTabActive.value = index == 2;
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
      minimum: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Container(
        height: 62,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _FooterNavigationItem(
              label: 'Home',
              selected: selectedIndex == 0,
              onTap: () => onSelected(0),
              icon: const Icon(Icons.home_rounded, size: 22),
            ),
            _FooterNavigationItem(
              label: 'Trips',
              selected: selectedIndex == 1,
              onTap: () => onSelected(1),
              icon: _TripNavigationIcon(
                icon: Icons.directions_car_rounded,
                size: 22,
                showOngoing: hasOngoingTrip,
              ),
            ),
            _FooterNavigationItem(
              label: 'QR',
              selected: selectedIndex == 2,
              onTap: () => onSelected(2),
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 22),
            ),
            _FooterNavigationItem(
              label: 'Profile',
              selected: selectedIndex == 3,
              onTap: () => onSelected(3),
              icon: const Icon(Icons.person_rounded, size: 22),
            ),
          ],
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

  bool get _highlighted => widget.selected || _hovered || _focused;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: widget.selected,
        label: widget.label,
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          onShowFocusHighlight: (value) => setState(() => _focused = value),
          child: MouseRegion(
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTap,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Positioned(
                    bottom: 50,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: _hovered || _focused ? 1 : 0,
                        duration: const Duration(milliseconds: 300),
                        child: AnimatedScale(
                          scale: _hovered || _focused ? 1 : 0.5,
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOutBack,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Text(
                              widget.label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _highlighted
                          ? const Color(0xFF1E293B)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: widget.selected
                          ? Border.all(
                              color: AppTheme.primaryBlue.withValues(
                                alpha: 0.55,
                              ),
                            )
                          : null,
                    ),
                    child: IconTheme(
                      data: IconThemeData(
                        color: widget.selected
                            ? AppTheme.primaryBlue
                            : Colors.white,
                      ),
                      child: Center(child: widget.icon),
                    ),
                  ),
                ],
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
