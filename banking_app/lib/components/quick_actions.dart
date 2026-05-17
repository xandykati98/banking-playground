import 'package:flutter/material.dart';
import '../component_props.dart';

class QuickActions extends StatelessWidget {
  const QuickActions({super.key, required this.props});

  final Map<String, String>? props;

  static const _actions = [
    (icon: Icons.hub_outlined, label: 'Pix area', isNew: false),
    (icon: Icons.arrow_upward_rounded, label: 'Transfer', isNew: false),
    (icon: Icons.receipt_outlined, label: 'Pay', isNew: false),
    (icon: Icons.trending_up_rounded, label: 'Invest', isNew: true),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: _actions
            .map((a) => _ActionButton(action: a, props: props))
            .toList(),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action, required this.props});

  final ({IconData icon, String label, bool isNew}) action;
  final Map<String, String>? props;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: propColor(
                    props, 'circleColor', const Color(0xFFF0F0F0)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                action.icon,
                size: 24,
                color: propColor(props, 'iconColor', Colors.black87),
              ),
            ),
            if (action.isNew)
              Positioned(
                top: -2,
                right: -8,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: propColor(
                        props, 'badgeColor', const Color(0xFF00C853)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'New',
                    style: TextStyle(
                      color: propColor(
                          props, 'badgeTextColor', Colors.white),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          action.label,
          style: TextStyle(
            fontSize: 12,
            color: propColor(props, 'labelColor', Colors.black87),
          ),
        ),
      ],
    );
  }
}
