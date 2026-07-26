import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../consts/appColors.dart';
import '../../../widgets/admin_widgets.dart';
import '../../../../features/menu_admin/data/repositories/menu_repository_impl.dart';
import '../../../../features/menu_admin/domain/entities/menu_entity.dart';
import '../../../../features/menu_admin/presentation/bloc/menu_admin_bloc.dart';
import '../../../../features/menu_admin/presentation/bloc/menu_admin_event.dart';
import '../../../../features/menu_admin/presentation/bloc/menu_admin_state.dart';
import '../category_items_screen.dart';

class MenuTab extends StatelessWidget {
  const MenuTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MenuAdminBloc(repository: MenuRepositoryImpl())..add(FetchMenuEvent()),
      child: const MenuTabView(),
    );
  }
}

class MenuTabView extends StatefulWidget {
  const MenuTabView({super.key});

  @override
  State<MenuTabView> createState() => _MenuTabViewState();
}

class _MenuTabViewState extends State<MenuTabView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditCategoryDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Category'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: BlocBuilder<MenuAdminBloc, MenuAdminState>(
        builder: (context, state) {
          if (state is MenuLoading || state is MenuInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is MenuError) {
            return Center(child: Text(state.message, style: const TextStyle(color: AppColors.error)));
          }
          if (state is MenuLoaded) {
            final categories = state.categories;
            if (categories.isEmpty) {
              return const Center(child: Text('No categories found. Click Add Category to start.'));
            }

            return GridView.builder(
              padding: const EdgeInsets.all(16).copyWith(bottom: 100),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final catData = categories[index];
                
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CategoryItemsScreen(
                          category: catData,
                          menuBloc: context.read<MenuAdminBloc>(),
                        ),
                      ),
                    );
                  },
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Category Image
                            Expanded(
                              flex: 3,
                              child: catData.imageUrl.isNotEmpty
                                  ? Image.network(catData.imageUrl, fit: BoxFit.cover)
                                  : Container(
                                      color: Colors.grey.shade200,
                                      child: const Icon(Icons.fastfood, size: 50, color: Colors.grey),
                                    ),
                            ),
                            // Category Info
                            Expanded(
                              flex: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      catData.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${catData.items.length} Items',
                                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Edit/Delete Actions
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(6),
                                  icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                                  onPressed: () => _showAddEditCategoryDialog(context, catData),
                                ),
                                IconButton(
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(6),
                                  icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18),
                                  onPressed: () => context.read<MenuAdminBloc>().add(DeleteCategoryEvent(catData.id)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Status Badge
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: catData.isActive ? AppColors.success.withOpacity(0.9) : Colors.redAccent.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              catData.isActive ? 'Active' : 'Hidden',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }
          return const SizedBox();
        },
      ),
    );
  }

  Future<void> _showAddEditCategoryDialog(BuildContext blocContext, [CategoryEntity? category]) async {
    final isEdit = category != null;
    final nameController = TextEditingController(text: isEdit ? category.name : '');
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AdminDialog(
          title: isEdit ? 'Edit Category' : 'Add New Category',
          isLoading: isLoading,
          saveText: isEdit ? 'Save Changes' : 'Add Category',
          onCancel: () => Navigator.pop(ctx),
          onSave: () async {
            if (nameController.text.trim().isEmpty) return;
            setState(() => isLoading = true);
            
            if (isEdit) {
              blocContext.read<MenuAdminBloc>().add(EditCategoryEvent(id: category.id, name: nameController.text.trim(), isActive: category.isActive));
            } else {
              blocContext.read<MenuAdminBloc>().add(AddCategoryEvent(nameController.text.trim()));
            }
            if (!mounted) return;
            Navigator.pop(ctx);
          },
          children: [
            AdminTextField(controller: nameController, label: 'Category Name', icon: Icons.category),
          ],
        ),
      ),
    );
  }


}
