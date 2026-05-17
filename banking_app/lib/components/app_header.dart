import 'package:flutter/material.dart';
import '../component_props.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.props,
    required this.balanceVisible,
    required this.onToggleBalance,
  });

  final Map<String, String>? props;
  final bool balanceVisible;
  final VoidCallback onToggleBalance;

  @override
  Widget build(BuildContext context) {
    final iconColor = propColor(props, 'iconColor', Colors.black87);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: propColor(
                  props, 'avatarBackgroundColor', const Color(0xFFB3E0F2)),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person,
              color: propColor(
                  props, 'avatarIconColor', const Color(0xFF4A90D9)),
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            r'$dos-',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.search, size: 22, color: iconColor),
            onPressed: () {},
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: Icon(
              balanceVisible
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 22,
              color: iconColor,
            ),
            onPressed: onToggleBalance,
            visualDensity: VisualDensity.compact,
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: Icon(Icons.notifications_outlined,
                    size: 22, color: iconColor),
                onPressed: () {},
                visualDensity: VisualDensity.compact,
              ),
              Positioned(
                right: 8,
                top: 8,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: propColor(
                        props, 'notificationBadgeColor', Colors.red),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.qr_code_scanner, size: 22, color: iconColor),
            onPressed: () {},
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
