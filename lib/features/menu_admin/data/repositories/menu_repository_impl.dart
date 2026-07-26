import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/menu_entity.dart';
import '../../domain/repositories/menu_repository.dart';
import '../models/menu_model.dart';

class MenuRepositoryImpl implements MenuRepository {
  final FirebaseFirestore _firestore;

  MenuRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<Either<String, List<CategoryEntity>>> getMenu() async {
    try {
      final categoriesSnapshot = await _firestore.collection('menu_categories').get();
      final itemsSnapshot = await _firestore.collection('menu_items').get();

      final List<MenuItemModel> allItems = itemsSnapshot.docs.map((doc) {
        final data = doc.data();
        return MenuItemModel(
          id: data['id'] ?? doc.id,
          categoryId: data['categoryId'] ?? '',
          categoryName: data['categoryName'] ?? '',
          name: data['name'] ?? '',
          description: data['description'] ?? '',
          price: (data['price'] as num?)?.toDouble() ?? 0.0,
          rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
          calories: (data['calories'] as num?)?.toInt() ?? 0,
          imageUrl: data['imageUrl'] ?? '',
          isAvailable: data['isAvailable'] ?? true,
          isPopular: data['isPopular'] ?? false,
        );
      }).toList();

      final List<CategoryModel> categories = categoriesSnapshot.docs.map((doc) {
        final data = doc.data();
        final catId = data['id'] ?? doc.id;
        final catItems = allItems.where((item) => item.categoryId == catId).toList();
        
        return CategoryModel(
          id: catId,
          name: data['name'] ?? '',
          imageUrl: data['imageUrl'] ?? '',
          isActive: data['isActive'] ?? true,
          items: catItems,
        );
      }).toList();

      return Right(categories);
    } catch (e) {
      return Left('Error connecting to Firebase: $e');
    }
  }

  @override
  Future<Either<String, void>> addCategory(String name) async {
    try {
      final id = const Uuid().v4();
      await _firestore.collection('menu_categories').doc(id).set({
        'id': id,
        'name': name,
        'imageUrl': 'https://images.unsplash.com/photo-1550547660-d9450f859349',
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return const Right(null);
    } catch (e) {
      return Left('Failed to add category: $e');
    }
  }

  @override
  Future<Either<String, void>> editCategory(String id, String name, bool isActive) async {
    try {
      await _firestore.collection('menu_categories').doc(id).update({
        'name': name,
        'isActive': isActive,
      });
      return const Right(null);
    } catch (e) {
      return Left('Failed to edit category: $e');
    }
  }

  @override
  Future<Either<String, void>> deleteCategory(String id) async {
    try {
      final batch = _firestore.batch();
      
      batch.delete(_firestore.collection('menu_categories').doc(id));

      // Delete all items under this category
      final itemsSnapshot = await _firestore
          .collection('menu_items')
          .where('categoryId', isEqualTo: id)
          .get();

      for (var doc in itemsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      return const Right(null);
    } catch (e) {
      return Left('Failed to delete category: $e');
    }
  }

  @override
  Future<Either<String, void>> addItem(MenuItemEntity item) async {
    try {
      final id = const Uuid().v4();
      await _firestore.collection('menu_items').doc(id).set({
        'id': id,
        'categoryId': item.categoryId,
        'categoryName': item.categoryName,
        'name': item.name,
        'description': item.description,
        'price': item.price,
        'rating': item.rating,
        'calories': item.calories,
        'imageUrl': item.imageUrl,
        'isAvailable': item.isAvailable,
        'isPopular': item.isPopular,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return const Right(null);
    } catch (e) {
      return Left('Failed to add item: $e');
    }
  }

  @override
  Future<Either<String, void>> editItem(MenuItemEntity item) async {
    try {
      await _firestore.collection('menu_items').doc(item.id).update({
        'name': item.name,
        'description': item.description,
        'price': item.price,
        'rating': item.rating,
        'calories': item.calories,
        'imageUrl': item.imageUrl,
        'isAvailable': item.isAvailable,
        'isPopular': item.isPopular,
      });
      return const Right(null);
    } catch (e) {
      return Left('Failed to edit item: $e');
    }
  }

  @override
  Future<Either<String, void>> deleteItem(String categoryId, String itemId) async {
    try {
      await _firestore.collection('menu_items').doc(itemId).delete();
      return const Right(null);
    } catch (e) {
      return Left('Failed to delete item: $e');
    }
  }
}
