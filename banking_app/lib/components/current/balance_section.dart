import 'package:flutter/material.dart';
import '../../component_props.dart';

class BalanceSection extends StatelessWidget {
  const BalanceSection({
    super.key,
    required this.props,
    required this.visible,
  });

  final Map<String, String>? props;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 400),
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  color: propColor(props, 'amountTextColor', Colors.black),
                ),
                child: Text(visible ? r'R$ 12.847,33' : r'R$ ••••'),
              ),
              const Spacer(),
              Icon(
                Icons.chevron_right,
                color: propColor(props, 'chevronColor', Colors.black38),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  border: Border.all(
                      color: propColor(
                          props, 'addBorderColor', Colors.black45)),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add,
                  size: 12,
                  color: propColor(props, 'addIconColor', Colors.black45),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'New Balance  >',
                style: TextStyle(
                  color: propColor(props, 'subtitleColor', Colors.black45),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
