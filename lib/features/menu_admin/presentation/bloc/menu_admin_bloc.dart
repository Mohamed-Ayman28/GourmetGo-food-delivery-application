import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/menu_repository.dart';
import 'menu_admin_event.dart';
import 'menu_admin_state.dart';

class MenuAdminBloc extends Bloc<MenuAdminEvent, MenuAdminState> {
  final MenuRepository repository;

  MenuAdminBloc({required this.repository}) : super(MenuInitial()) {
    on<FetchMenuEvent>(_onFetchMenu);
    on<AddCategoryEvent>(_onAddCategory);
    on<EditCategoryEvent>(_onEditCategory);
    on<DeleteCategoryEvent>(_onDeleteCategory);
    on<AddMenuItemEvent>(_onAddMenuItem);
    on<EditMenuItemEvent>(_onEditMenuItem);
    on<DeleteMenuItemEvent>(_onDeleteMenuItem);
  }

  Future<void> _onFetchMenu(FetchMenuEvent event, Emitter<MenuAdminState> emit) async {
    emit(MenuLoading());
    final result = await repository.getMenu();
    result.fold(
      (error) => emit(MenuError(error)),
      (categories) => emit(MenuLoaded(categories)),
    );
  }

  Future<void> _onAddCategory(AddCategoryEvent event, Emitter<MenuAdminState> emit) async {
    final result = await repository.addCategory(event.name);
    if (result.isRight()) {
      add(FetchMenuEvent()); // Refetch to update local state
    }
  }

  Future<void> _onEditCategory(EditCategoryEvent event, Emitter<MenuAdminState> emit) async {
    final result = await repository.editCategory(event.id, event.name, event.isActive);
    if (result.isRight()) {
      add(FetchMenuEvent());
    }
  }

  Future<void> _onDeleteCategory(DeleteCategoryEvent event, Emitter<MenuAdminState> emit) async {
    final result = await repository.deleteCategory(event.id);
    if (result.isRight()) {
      add(FetchMenuEvent());
    }
  }

  Future<void> _onAddMenuItem(AddMenuItemEvent event, Emitter<MenuAdminState> emit) async {
    final result = await repository.addItem(event.item);
    if (result.isRight()) {
      add(FetchMenuEvent());
    }
  }

  Future<void> _onEditMenuItem(EditMenuItemEvent event, Emitter<MenuAdminState> emit) async {
    final result = await repository.editItem(event.item);
    if (result.isRight()) {
      add(FetchMenuEvent());
    }
  }

  Future<void> _onDeleteMenuItem(DeleteMenuItemEvent event, Emitter<MenuAdminState> emit) async {
    final result = await repository.deleteItem(event.categoryId, event.itemId);
    if (result.isRight()) {
      add(FetchMenuEvent());
    }
  }
}
