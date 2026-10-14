import 'package:flutter/material.dart';

const List<String> kCategories = [
  'Konsumsi',
  'Transportasi',
  'Kesehatan',
  'Belanja',
  'Lainnya',
];

const Color kPrimary = Color(0xFF12A37A);
const Color kPrimaryDark = Color(0xFF0E8A68);
const Color kBg = Color(0xFFF1F6F5);
const Color kTextDark = Color(0xFF1F2D3D);
const Color kTextGrey = Color(0xFF6B7C8A);
const Color kBorder = Color(0xFFD5E0DE);
const Color kError = Color(0xFFD64545);

Color categoryColor(String? c) {
  switch (c) {
    case 'Konsumsi':
      return const Color(0xFF12A37A);
    case 'Transportasi':
      return const Color(0xFF3B82F6);
    case 'Kesehatan':
      return const Color(0xFFE5484D);
    case 'Belanja':
      return const Color(0xFF8B5CF6);
    default:
      return const Color(0xFF8A97A3);
  }
}

IconData categoryIcon(String? c) {
  switch (c) {
    case 'Konsumsi':
      return Icons.restaurant_outlined;
    case 'Transportasi':
      return Icons.directions_car_outlined;
    case 'Kesehatan':
      return Icons.medical_services_outlined;
    case 'Belanja':
      return Icons.shopping_basket_outlined;
    default:
      return Icons.receipt_long_outlined;
  }
}
