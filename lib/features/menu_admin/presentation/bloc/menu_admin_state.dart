import 'package:equatable/equatable.dart';
import '../../domain/entities/menu_entity.dart';

abstract class MenuAdminState extends Equatable {
  const MenuAdminState();

  @override
  List<Object?> get props => [];
}

class MenuInitial extends MenuAdminState {}

class MenuLoading extends MenuAdminState {}

class MenuLoaded extends MenuAdminState {
  final List<CategoryEntity> categories;
  const MenuLoaded(this.categories);

  @override
  List<Object?> get props => [categories];
}

class MenuError extends MenuAdminState {
  final String message;
  const MenuError(this.message);

  @override
  List<Object?> get props => [message];
}
