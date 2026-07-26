import 'package:equatable/equatable.dart';

class MenuItemEntity extends Equatable {
  final String id;
  final String categoryId;
  final String categoryName;
  final String name;
  final String description;
  final double price;
  final double rating;
  final int calories;
  final String imageUrl;
  final bool isAvailable;
  final bool isPopular;

  const MenuItemEntity({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.name,
    required this.description,
    required this.price,
    required this.rating,
    required this.calories,
    required this.imageUrl,
    required this.isAvailable,
    required this.isPopular,
  });

  @override
  List<Object?> get props => [id, categoryId, categoryName, name, description, price, rating, calories, imageUrl, isAvailable, isPopular];
}

class CategoryEntity extends Equatable {
  final String id;
  final String name;
  final String imageUrl;
  final bool isActive;
  final List<MenuItemEntity> items;

  const CategoryEntity({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.isActive = true,
    this.items = const [],
  });

  @override
  List<Object?> get props => [id, name, imageUrl, isActive, items];
}
