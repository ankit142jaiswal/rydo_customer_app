import 'package:flutter/material.dart';

/// Lets screens shown as tabs inside HomeScreen (Rides, Wallet, Profile)
/// go "back" to the Home tab, since there is no route to pop.
class HomeTabScope extends InheritedWidget {
  final VoidCallback goHome;
  const HomeTabScope({super.key, required this.goHome, required super.child});

  static HomeTabScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HomeTabScope>();

  @override
  bool updateShouldNotify(HomeTabScope oldWidget) => goHome != oldWidget.goHome;
}

/// Back button used on every page:
///  - pops the current route when there is one,
///  - otherwise (a tab inside HomeScreen) switches back to the Home tab,
///  - shows nothing on the root screen.
class RydoBackButton extends StatelessWidget {
  final Color color;
  final bool filled;
  const RydoBackButton({super.key, this.color = Colors.white, this.filled = false});

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final scope = HomeTabScope.maybeOf(context);
    if (!canPop && scope == null) return const SizedBox.shrink();

    final button = IconButton(
      icon: Icon(Icons.arrow_back_rounded, color: color),
      tooltip: 'Back',
      onPressed: canPop ? () => Navigator.of(context).maybePop() : scope!.goHome,
    );
    if (!filled) return button;
    return Padding(
      padding: const EdgeInsets.all(6),
      child: CircleAvatar(backgroundColor: Colors.white, child: button),
    );
  }
}
