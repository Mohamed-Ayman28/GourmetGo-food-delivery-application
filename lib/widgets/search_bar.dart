import 'package:flutter/material.dart';

class SearchInput extends StatelessWidget {
  final TextEditingController textController;
  final String hintText;

  const SearchInput({
    super.key,
    required this.textController,
    required this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        controller: textController,
        style: TextStyle(
          fontSize: 16,
          color: colors.onSurface,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: colors.onSurface.withOpacity(.45),
            fontSize: 16,
          ),

          prefixIcon: Icon(
            Icons.search_rounded,
            color: colors.onSurface.withOpacity(.65),
          ),

          suffixIcon: IconButton(
            onPressed: () {
              textController.clear();
            },
            icon: Icon(
              Icons.tune_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),

          filled: true,
          fillColor: colors.surface,

          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 20,
          ),

          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),

          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: Colors.grey.shade200,
            ),
          ),

          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: colors.primary,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}