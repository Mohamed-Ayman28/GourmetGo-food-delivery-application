import 'package:flutter/material.dart';

class ExtraItem {
  final String name;
  final double price;
  final IconData icon;

  const ExtraItem({
    required this.name,
    required this.price,
    required this.icon,
  });

  // ── Serialization ────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'name': name,
        'price': price,
        // Persist the icon as its integer codePoint + fontFamily so we can
        // reconstruct it. MaterialIcons always uses 'MaterialIcons'.
        'iconCodePoint': icon.codePoint,
        'iconFontFamily': icon.fontFamily ?? 'MaterialIcons',
        'iconFontPackage': icon.fontPackage,
      };

  factory ExtraItem.fromJson(Map<String, dynamic> json) {
    return ExtraItem(
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      icon: IconData(
        json['iconCodePoint'] as int? ?? Icons.star.codePoint,
        fontFamily:
            json['iconFontFamily'] as String? ?? 'MaterialIcons',
        fontPackage: json['iconFontPackage'] as String?,
      ),
    );
  }
}
