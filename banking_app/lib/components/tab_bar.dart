import 'package:flutter/material.dart';
import '../component_props.dart';

class DashboardTabBar extends StatelessWidget {
  const DashboardTabBar({
    super.key,
    required this.props,
    required this.selectedIndex,
    required this.onTap,
  });

  final Map<String, String>? props;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  static const _tabs = ['Account', 'Sales', 'Coins'];

  @override
  Widget build(BuildContext context) {
    final selectedColor =
        propColor(props, 'selectedTextColor', Colors.black);
    final unselectedColor =
        propColor(props, 'unselectedTextColor', Colors.black38);
    final underlineColor =
        propColor(props, 'underlineColor', Colors.black);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(_tabs.length, (i) {
          final selected = i == selectedIndex;
          return GestureDetector(
            onTap: () => onTap(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(right: 24),
              padding: const EdgeInsets.only(bottom: 8),
              decoration: selected
                  ? BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                            color: underlineColor, width: 2.5),
                      ),
                    )
                  : null,
              child: Text(
                _tabs[i],
                style: TextStyle(
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 15,
                  color: selected ? selectedColor : unselectedColor,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
