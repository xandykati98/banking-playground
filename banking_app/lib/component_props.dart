import 'package:flutter/material.dart';

/// Reads a hex color string (e.g. "#RRGGBB") from [props] by [key].
/// Returns [fallback] if the key is missing or the value is not a valid hex.
Color propColor(Map<String, String>? props, String key, Color fallback) {
  final hex = props?[key];
  if (hex == null || hex.isEmpty) return fallback;
  try {
    return Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
  } catch (_) {
    return fallback;
  }
}
