class ComponentData {
  const ComponentData({
    required this.id,
    required this.type,
    required this.order,
    required this.visible,
    required this.props,
  });

  final String id;
  final String type;
  final int order;
  final bool visible;
  final Map<String, String> props;

  factory ComponentData.fromJson(Map<String, dynamic> json) {
    final rawProps = json['props'] as Map<String, dynamic>? ?? {};
    return ComponentData(
      id: json['id'] as String,
      type: json['type'] as String,
      order: json['order'] as int? ?? 0,
      visible: json['visible'] as bool? ?? true,
      props: rawProps.map((k, v) => MapEntry(k, v.toString())),
    );
  }
}

class LayoutData {
  const LayoutData({required this.rootProps, required this.components});

  final Map<String, String> rootProps;

  // Ordered list of visible components (already filtered + sorted).
  final List<ComponentData> components;

  factory LayoutData.fromJson(Map<String, dynamic> json) {
    final rawRoot = json['props'] as Map<String, dynamic>? ?? {};
    final rootProps = rawRoot.map((k, v) => MapEntry(k, v.toString()));

    final children = (json['children'] as List<dynamic>? ?? [])
        .map((c) => ComponentData.fromJson(c as Map<String, dynamic>))
        .where((c) => c.visible)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    return LayoutData(rootProps: rootProps, components: children);
  }

  static LayoutData get empty => const LayoutData(
        rootProps: {},
        components: [],
      );

  ComponentData? operator [](String id) {
    try {
      return components.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
}
