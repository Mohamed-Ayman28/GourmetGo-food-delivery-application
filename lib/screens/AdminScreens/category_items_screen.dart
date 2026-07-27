import 'package:gourmet_go/widgets/custom_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../../consts/appColors.dart';
import '../../../widgets/admin_widgets.dart';
import '../../../../features/menu_admin/domain/entities/menu_entity.dart';
import '../../../../features/menu_admin/presentation/bloc/menu_admin_bloc.dart';
import '../../../../features/menu_admin/presentation/bloc/menu_admin_event.dart';
import '../../../../features/menu_admin/presentation/bloc/menu_admin_state.dart';

class CategoryItemsScreen extends StatefulWidget {
  final CategoryEntity category;
  final MenuAdminBloc menuBloc;

  const CategoryItemsScreen({
    super.key,
    required this.category,
    required this.menuBloc,
  });

  @override
  State<CategoryItemsScreen> createState() => _CategoryItemsScreenState();
}

class _CategoryItemsScreenState extends State<CategoryItemsScreen> {
  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: widget.menuBloc,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.category.name),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: BlocBuilder<MenuAdminBloc, MenuAdminState>(
          builder: (context, state) {
            if (state is MenuLoaded) {
              final CategoryEntity cat = state.categories.cast<CategoryEntity>().firstWhere(
                (c) => c.id == widget.category.id,
                orElse: () => widget.category,
              );
              final items = cat.items;

              if (items.isEmpty) {
                return _buildEmptyState(cat);
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16).copyWith(bottom: 100),
                itemCount: items.length,
                separatorBuilder: (ctx, idx) => const Divider(height: 32),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _buildItemRow(context, item, cat);
                },
              );
            }
            return const Center(child: CircularProgressIndicator());
          },
        ),
        floatingActionButton: BlocBuilder<MenuAdminBloc, MenuAdminState>(
          builder: (context, state) {
            if (state is MenuLoaded) {
              final CategoryEntity cat = state.categories.cast<CategoryEntity>().firstWhere(
                (c) => c.id == widget.category.id,
                orElse: () => widget.category,
              );
              return FloatingActionButton.extended(
                onPressed: () => _showAddEditItemDialog(context, null, cat.id, cat.name),
                icon: const Icon(Icons.add),
                label: const Text('Add Item'),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(CategoryEntity cat) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.fastfood, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'No items in ${cat.name} yet.',
            style: const TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddEditItemDialog(context, null, cat.id, cat.name),
            icon: const Icon(Icons.add),
            label: const Text('Add First Item'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          )
        ],
      ),
    );
  }

  Widget _buildItemRow(BuildContext context, MenuItemEntity item, CategoryEntity cat) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: item.imageUrl.isNotEmpty
              ? Image.network(item.imageUrl, width: 80, height: 80, fit: BoxFit.cover)
              : Container(
                  width: 80,
                  height: 80,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.image, color: Colors.grey),
                ),
        ),
        const SizedBox(width: 16),
        // Details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                item.description,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '\$${item.price.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.star, color: Colors.amber, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    item.rating.toString(),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  if (item.calories > 0) ...[
                    const SizedBox(width: 16),
                    const Icon(Icons.local_fire_department, color: Colors.orange, size: 18),
                    const SizedBox(width: 4),
                    Text('${item.calories} kcal', style: const TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (item.isPopular)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: const Text('🔥 Popular', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  if (item.isPopular) const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: item.isAvailable ? AppColors.success.withOpacity(0.1) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      item.isAvailable ? 'Available' : 'Unavailable',
                      style: TextStyle(color: item.isAvailable ? AppColors.success : Colors.grey, fontSize: 12),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
        // Actions
        Column(
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: AppColors.primary),
              onPressed: () => _showAddEditItemDialog(context, item, cat.id, cat.name),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: AppColors.error),
              onPressed: () => _showDeleteConfirmation(context, item),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showDeleteConfirmation(BuildContext context, MenuItemEntity item) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete ${item.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              context.read<MenuAdminBloc>().add(DeleteMenuItemEvent(categoryId: item.categoryId, itemId: item.id));
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddEditItemDialog(BuildContext blocContext, MenuItemEntity? item, String categoryId, String categoryName) async {
    final isEdit = item != null;

    final nameController = TextEditingController(text: item?.name ?? '');
    final descController = TextEditingController(text: item?.description ?? '');
    final priceController = TextEditingController(text: (item?.price ?? '').toString());
    final caloriesController = TextEditingController(text: (item?.calories ?? '').toString());
    
    bool isAvailable = item?.isAvailable ?? true;
    bool isPopular = item?.isPopular ?? false;

    String? imageUrl = item?.imageUrl;
    XFile? pickedImage;

    bool isLoading = false;

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AdminDialog(
          title: isEdit ? 'Edit Menu Item' : 'Add Item to $categoryName',
          isLoading: isLoading,
          saveText: isEdit ? 'Save Changes' : 'Add Item',
          onCancel: () => Navigator.pop(ctx),
          onSave: () async {
            if (nameController.text.isEmpty) return;
            setState(() => isLoading = true);
            
            try {
              String finalImageUrl = imageUrl ?? '';
              if (pickedImage != null) {
                finalImageUrl = 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd'; // Mocked upload
              }

              final itemData = MenuItemEntity(
                id: item?.id ?? '', // Handled by impl for new items
                categoryId: categoryId,
                categoryName: categoryName,
                name: nameController.text.trim(),
                description: descController.text.trim(),
                price: double.tryParse(priceController.text.trim()) ?? 0.0,
                rating: item?.rating ?? 4.5,
                calories: int.tryParse(caloriesController.text.trim()) ?? 0,
                imageUrl: finalImageUrl,
                isAvailable: isAvailable,
                isPopular: isPopular,
              );

              if (isEdit) {
                blocContext.read<MenuAdminBloc>().add(EditMenuItemEvent(itemData));
              } else {
                blocContext.read<MenuAdminBloc>().add(AddMenuItemEvent(itemData));
              }
              if (!mounted) return;
              Navigator.pop(ctx);
            } catch (e) {
              CustomSnackBar.show(context, message: 'Error: $e', type: SnackBarType.error);
            } finally {
              setState(() => isLoading = false);
            }
          },
          children: [
            Center(
              child: GestureDetector(
                onTap: () async {
                  final picker = ImagePicker();
                  final image = await picker.pickImage(source: ImageSource.gallery);
                  if (image != null) setState(() => pickedImage = image);
                },
                child: Container(
                  height: 120,
                  width: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade300, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: pickedImage != null
                        ? const Icon(Icons.check_circle, color: Colors.green, size: 50)
                        : (imageUrl != null && imageUrl.isNotEmpty)
                            ? Image.network(imageUrl, fit: BoxFit.cover)
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo, size: 32, color: Colors.grey.shade400),
                                  const SizedBox(height: 8),
                                  Text('Add Photo', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                ],
                              ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            AdminTextField(controller: nameController, label: 'Item Name', icon: Icons.fastfood),
            AdminTextField(controller: descController, label: 'Description', icon: Icons.description),
            Row(
              children: [
                Expanded(child: AdminTextField(controller: priceController, label: 'Price (\$)', icon: Icons.attach_money, keyboardType: TextInputType.number)),
                const SizedBox(width: 16),
                Expanded(child: AdminTextField(controller: caloriesController, label: 'Calories', icon: Icons.local_fire_department, keyboardType: TextInputType.number)),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Available'),
              subtitle: const Text('Item is currently in stock'),
              value: isAvailable,
              onChanged: (val) => setState(() => isAvailable = val),
              activeColor: AppColors.primary,
            ),
            SwitchListTile(
              title: const Text('Popular'),
              subtitle: const Text('Highlight this item as popular'),
              value: isPopular,
              onChanged: (val) => setState(() => isPopular = val),
              activeColor: Colors.red,
            ),
          ],
        ),
      ),
    );
  }
}
