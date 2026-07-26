import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

class MenuSeeder {
  static Future<void> seedMenuToFirestore() async {
    try {
      final String response = await rootBundle.loadString('gourmet_go_menu.json');
      final Map<String, dynamic> data = json.decode(response);
      
      if (!data.containsKey('categories')) return;

      final firestore = FirebaseFirestore.instance;
      final WriteBatch batch = firestore.batch();

      final categories = data['categories'] as List;

      for (var jsonCat in categories) {
        final catId = const Uuid().v4();
        final catName = jsonCat['category'] ?? 'Unknown';
        
        final items = (jsonCat['items'] as List?) ?? [];
        String catImageUrl = '';
        
        // Write Items
        for (var jsonItem in items) {
          final itemId = const Uuid().v4();
          String priceStr = jsonItem['price']?.toString() ?? '0';
          priceStr = priceStr.replaceAll(RegExp(r'[^0-9.]'), '');
          
          final imageUrl = jsonItem['image'] ?? '';
          if (catImageUrl.isEmpty && imageUrl.isNotEmpty) {
            catImageUrl = imageUrl;
          }

          final itemData = {
            'id': itemId,
            'categoryId': catId,
            'categoryName': catName,
            'name': jsonItem['name'] ?? '',
            'description': jsonItem['description'] ?? '',
            'price': double.tryParse(priceStr) ?? 0.0,
            'rating': (jsonItem['rating'] ?? 0.0).toDouble(),
            'calories': jsonItem['calories'] ?? 0,
            'imageUrl': imageUrl,
            'isAvailable': true,
            'isPopular': false,
            'ingredients': jsonItem['ingredients'] ?? [],
            'createdAt': FieldValue.serverTimestamp(),
          };

          final itemRef = firestore.collection('menu_items').doc(itemId);
          batch.set(itemRef, itemData);
        }

        // Write Category
        final catData = {
          'id': catId,
          'name': catName,
          'imageUrl': catImageUrl,
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
        };

        final catRef = firestore.collection('menu_categories').doc(catId);
        batch.set(catRef, catData);
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to seed menu: $e');
    }
  }

  static Future<void> clearAndReseedMenu() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      
      // Delete existing items
      final itemsSnapshot = await firestore.collection('menu_items').get();
      for (var doc in itemsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      // Delete existing categories
      final catSnapshot = await firestore.collection('menu_categories').get();
      for (var doc in catSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      
      // Seed again
      await seedMenuToFirestore();
    } catch (e) {
      throw Exception('Failed to clear and reseed menu: $e');
    }
  }
}
