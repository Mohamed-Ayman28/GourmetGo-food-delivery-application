import 'package:dartz/dartz.dart';
import '../entities/menu_entity.dart';

abstract class MenuRepository {
  Future<Either<String, List<CategoryEntity>>> getMenu();
  Future<Either<String, void>> addCategory(String name);
  Future<Either<String, void>> editCategory(String id, String name, bool isActive);
  Future<Either<String, void>> deleteCategory(String id);
  
  Future<Either<String, void>> addItem(MenuItemEntity item);
  Future<Either<String, void>> editItem(MenuItemEntity item);
  Future<Either<String, void>> deleteItem(String categoryId, String itemId);
}
