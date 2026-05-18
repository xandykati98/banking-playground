import 'package:flutter/material.dart';
import '../../component_props.dart';

class AccountSection extends StatelessWidget {
  const AccountSection({
    super.key,
    required this.props,
    required this.balanceVisible,
  });

  final Map<String, String>? props;
  final bool balanceVisible;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your account',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: propColor(props, 'titleColor', Colors.black),
            ),
          ),
          const SizedBox(height: 12),
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                  color: propColor(
                      props, 'cardBorderColor', const Color(0xFFE8E8E8))),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'InfinitePay CDB',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: propColor(
                            props, 'productNameColor', Colors.black87),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      balanceVisible ? r'R$ 10,00' : r'R$ ••••',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color:
                            propColor(props, 'balanceColor', Colors.black),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: propColor(props, 'buttonBorderColor',
                            const Color(0xFFE0E0E0))),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  child: Text(
                    'Invest',
                    style: TextStyle(
                      color: propColor(
                          props, 'buttonTextColor', Colors.black87),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
