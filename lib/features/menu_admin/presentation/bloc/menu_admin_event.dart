import 'package:equatable/equatable.dart';
import '../../domain/entities/menu_entity.dart';

abstract class MenuAdminEvent extends Equatable {
  const MenuAdminEvent();

  @override
  List<Object?> get props => [];
}

class FetchMenuEvent extends MenuAdminEvent {}

class AddCategoryEvent extends MenuAdminEvent {
  final String name;
  const AddCategoryEvent(this.name);
  @override
  List<Object?> get props => [name];
}

class EditCategoryEvent extends MenuAdminEvent {
  final String id;
  final String name;
  final bool isActive;
  const EditCategoryEvent({required this.id, required this.name, required this.isActive});
  @override
  List<Object?> get props => [id, name, isActive];
}

class DeleteCategoryEvent extends MenuAdminEvent {
  final String id;
  const DeleteCategoryEvent(this.id);
  @override
  List<Object?> get props => [id];
}

class AddMenuItemEvent extends MenuAdminEvent {
  final MenuItemEntity item;
  const AddMenuItemEvent(this.item);
  @override
  List<Object?> get props => [item];
}

class EditMenuItemEvent extends MenuAdminEvent {
  final MenuItemEntity item;
  const EditMenuItemEvent(this.item);
  @override
  List<Object?> get props => [item];
}

class DeleteMenuItemEvent extends MenuAdminEvent {
  final String categoryId;
  final String itemId;
  const DeleteMenuItemEvent({required this.categoryId, required this.itemId});
  @override
  List<Object?> get props => [categoryId, itemId];
}
