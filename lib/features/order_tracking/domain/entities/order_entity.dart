import 'package:equatable/equatable.dart';

import 'package:flutter/material.dart';
import 'package:gourmet_go/consts/appColors.dart';

enum OrderStatus {
  pending,
  confirmed,
  preparing,
  driverAssigned,
  driverAccepted,
  driverPickedUp,
  outForDelivery,
  delivered,
  cancelled,
}

extension OrderStatusExtension on OrderStatus {
  String get uiString {
    switch (this) {
      case OrderStatus.pending:
      case OrderStatus.confirmed:
      case OrderStatus.preparing:
      case OrderStatus.driverAssigned:
      case OrderStatus.driverAccepted:
      case OrderStatus.driverPickedUp:
      case OrderStatus.outForDelivery:
        return 'IN PROGRESS';
      case OrderStatus.delivered:
        return 'DELIVERED';
      case OrderStatus.cancelled:
        return 'CANCELLED';
    }
  }

  Color get uiColor {
    switch (this) {
      case OrderStatus.pending:
      case OrderStatus.confirmed:
      case OrderStatus.preparing:
      case OrderStatus.driverAssigned:
      case OrderStatus.driverAccepted:
      case OrderStatus.driverPickedUp:
      case OrderStatus.outForDelivery:
        return AppColors.primary; // Typically orange/primary for In Progress
      case OrderStatus.delivered:
        return Colors.grey.shade600; // Grey for Delivered
      case OrderStatus.cancelled:
        return Colors.red.shade400; // Red for Cancelled
    }
  }

  String get stepString {
    switch (this) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.driverAssigned:
        return 'Driver Assigned';
      case OrderStatus.driverAccepted:
        return 'Driver Accepted';
      case OrderStatus.driverPickedUp:
        return 'Driver At Restaurant';
      case OrderStatus.outForDelivery:
        return 'Out For Delivery';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }
}

class OrderItemEntity extends Equatable {
  final String name;
  final int quantity;
  final String? imageUrl;

  const OrderItemEntity({
    required this.name,
    required this.quantity,
    this.imageUrl,
  });

  @override
  List<Object?> get props => [name, quantity, imageUrl];
}

class OrderEntity extends Equatable {
  final String id;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final double customerLat;
  final double customerLng;
  final String customerAddress;

  // Extra address details
  final String? buildingNumber;
  final String? floor;
  final String? apartment;
  final String? landmark;
  final String? deliveryNotes;

  final double restaurantLat;
  final double restaurantLng;
  final String restaurantName;
  final String? restaurantPhone;

  final String? driverId;
  final String? driverName;
  final String? driverPhotoUrl;
  final String? driverPhone;
  final DateTime? assignedAt;

  final OrderStatus status;
  final String orderNumber;
  final List<OrderItemEntity> items;

  // Financial breakdown
  final double subtotal;
  final double deliveryFee;
  final double serviceFee;
  final double discount;
  final double tax;
  final double totalAmount;

  final String paymentMethod;
  final String? orderNotes;
  final DateTime createdAt;
  final DateTime? estimatedArrival;

  const OrderEntity({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.customerLat,
    required this.customerLng,
    required this.customerAddress,
    this.buildingNumber,
    this.floor,
    this.apartment,
    this.landmark,
    this.deliveryNotes,
    required this.restaurantLat,
    required this.restaurantLng,
    this.restaurantName = 'Restaurant',
    this.restaurantPhone,
    this.driverId,
    this.driverName,
    this.driverPhotoUrl,
    this.driverPhone,
    this.assignedAt,
    required this.status,
    this.orderNumber = '',
    this.items = const [],
    this.subtotal = 0.0,
    this.deliveryFee = 0.0,
    this.serviceFee = 0.0,
    this.discount = 0.0,
    this.tax = 0.0,
    required this.totalAmount,
    required this.paymentMethod,
    this.orderNotes,
    required this.createdAt,
    this.estimatedArrival,
  });

  /// Human-readable items summary, e.g. "1x Burger, 2x Fries"
  String get itemsSummary {
    if (items.isEmpty) return 'No items';
    return items.map((i) => '${i.quantity}x ${i.name}').join(', ');
  }

  /// First item image URL for the card thumbnail
  String? get thumbnailUrl {
    for (final item in items) {
      if (item.imageUrl != null && item.imageUrl!.isNotEmpty) {
        return item.imageUrl;
      }
    }
    return null;
  }

  @override
  List<Object?> get props => [
        id,
        customerId,
        customerName,
        customerPhone,
        customerLat,
        customerLng,
        customerAddress,
        buildingNumber,
        floor,
        apartment,
        landmark,
        deliveryNotes,
        restaurantLat,
        restaurantLng,
        restaurantName,
        restaurantPhone,
        driverId,
        driverName,
        driverPhotoUrl,
        driverPhone,
        assignedAt,
        status,
        orderNumber,
        items,
        subtotal,
        deliveryFee,
        serviceFee,
        discount,
        tax,
        totalAmount,
        paymentMethod,
        orderNotes,
        createdAt,
        estimatedArrival,
      ];
}
