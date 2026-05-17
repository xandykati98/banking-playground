import 'package:flutter/material.dart';
import '../component_props.dart';

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({
    super.key,
    required this.props,
    required this.selectedIndex,
    required this.onTap,
  });

  final Map<String, String>? props;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final selectedColor =
        propColor(props, 'selectedColor', Colors.black);
    final unselectedColor =
        propColor(props, 'unselectedColor', Colors.black38);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        color: propColor(props, 'backgroundColor', Colors.white),
        border: Border(
          top: BorderSide(
              color: propColor(
                  props, 'borderColor', const Color(0xFFEEEEEE))),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _NavItem(
              icon: Icons.home_outlined,
              label: 'Home',
              selected: selectedIndex == 0,
              selectedColor: selectedColor,
              unselectedColor: unselectedColor,
              onTap: () => onTap(0),
            ),
            _NavItem(
              icon: Icons.receipt_long_outlined,
              label: 'Statem.',
              selected: selectedIndex == 1,
              selectedColor: selectedColor,
              unselectedColor: unselectedColor,
              onTap: () => onTap(1),
            ),
            _NavItem(
              icon: Icons.credit_card_outlined,
              label: 'Card',
              selected: selectedIndex == 2,
              selectedColor: selectedColor,
              unselectedColor: unselectedColor,
              onTap: () => onTap(2),
            ),
            _NavItem(
              icon: Icons.auto_awesome_outlined,
              label: 'JIM',
              selected: selectedIndex == 3,
              selectedColor: selectedColor,
              unselectedColor: unselectedColor,
              onTap: () => onTap(3),
            ),
            _SellItem(
              props: props,
              selected: selectedIndex == 4,
              onTap: () => onTap(4),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.unselectedColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color selectedColor;
  final Color unselectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? selectedColor : unselectedColor;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 11, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SellItem extends StatelessWidget {
  const _SellItem({
    required this.props,
    required this.selected,
    required this.onTap,
  });

  final Map<String, String>? props;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: propColor(props, 'sellCircleColor',
                      const Color(0xFF1A1A1A)),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.circle,
                    size: 10,
                    color: propColor(
                        props, 'sellDotColor', const Color(0xFF00C853)),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Sell',
                style: TextStyle(
                  fontSize: 11,
                  color: propColor(
                      props, 'unselectedColor', Colors.black38),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
