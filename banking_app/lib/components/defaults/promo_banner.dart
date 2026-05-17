import 'package:flutter/material.dart';
import '../../component_props.dart';

class PromoBanner extends StatelessWidget {
  const PromoBanner({super.key, required this.props});

  final Map<String, String>? props;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            propColor(props, 'gradientStart', const Color(0xFF4A1D96)),
            propColor(props, 'gradientEnd', const Color(0xFF7C3AED)),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Reduce your fees\nwith InfinitePay',
                style: TextStyle(
                  color: propColor(props, 'titleColor', Colors.white),
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
              ),
            ),
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                backgroundColor:
                    propColor(props, 'ctaBackground', Colors.white),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
              ),
              child: Text(
                'Learn more',
                style: TextStyle(
                  color: propColor(props, 'ctaTextColor', Colors.black87),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
