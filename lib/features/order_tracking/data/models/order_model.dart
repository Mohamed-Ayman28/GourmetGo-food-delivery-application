import '../../domain/entities/order_entity.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrderItemModel extends OrderItemEntity {
  const OrderItemModel({
    required super.name,
    required super.quantity,
    super.imageUrl,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      name: json['name'] ?? '',
      quantity: (json['quantity'] ?? 1).toInt(),
      imageUrl: json['imageUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'imageUrl': imageUrl,
    };
  }
}

class OrderModel extends OrderEntity {
  const OrderModel({
    required super.id,
    required super.customerId,
    required super.customerName,
    required super.customerPhone,
    required super.customerLat,
    required super.customerLng,
    required super.customerAddress,
    super.buildingNumber,
    super.floor,
    super.apartment,
    super.landmark,
    super.deliveryNotes,
    required super.restaurantLat,
    required super.restaurantLng,
    super.restaurantName,
    super.restaurantPhone,
    super.driverId,
    super.driverName,
    super.driverPhotoUrl,
    super.driverPhone,
    super.assignedAt,
    required super.status,
    super.orderNumber,
    super.items,
    super.subtotal,
    super.deliveryFee,
    super.serviceFee,
    super.discount,
    super.tax,
    required super.totalAmount,
    required super.paymentMethod,
    super.orderNotes,
    required super.createdAt,
    super.estimatedArrival,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json, String id) {
    // Parse items list
    final itemsList = (json['items'] as List<dynamic>?)
            ?.map((item) =>
                OrderItemModel.fromJson(item as Map<String, dynamic>))
            .toList()
            .cast<OrderItemEntity>() ??
        <OrderItemEntity>[];

    return OrderModel(
      id: id,
      customerId: json['customerId'] ?? '',
      customerName: json['customerName'] ?? '',
      customerPhone: json['customerPhone'] ?? '',
      customerLat: (json['customerLat'] ?? 0).toDouble(),
      customerLng: (json['customerLng'] ?? 0).toDouble(),
      customerAddress: json['customerAddress'] ?? '',
      buildingNumber: json['buildingNumber'],
      floor: json['floor'],
      apartment: json['apartment'],
      landmark: json['landmark'],
      deliveryNotes: json['deliveryNotes'],
      restaurantLat: (json['restaurantLat'] ?? 0).toDouble(),
      restaurantLng: (json['restaurantLng'] ?? 0).toDouble(),
      restaurantName: json['restaurantName'] ?? 'Restaurant',
      restaurantPhone: json['restaurantPhone'],
      driverId: json['driverId'],
      driverName: json['driverName'],
      driverPhotoUrl: json['driverPhotoUrl'],
      driverPhone: json['driverPhone'],
      assignedAt: (json['assignedAt'] as Timestamp?)?.toDate(),
      status: OrderStatus.values.firstWhere(
        (e) => e.name == (json['status'] ?? 'pending'),
        orElse: () => OrderStatus.pending,
      ),
      orderNumber: json['orderNumber'] ?? '#${id.substring(0, 4).toUpperCase()}',
      items: itemsList,
      subtotal: (json['subtotal'] ?? json['totalAmount'] ?? 0).toDouble(),
      deliveryFee: (json['deliveryFee'] ?? 0).toDouble(),
      serviceFee: (json['serviceFee'] ?? 0).toDouble(),
      discount: (json['discount'] ?? 0).toDouble(),
      tax: (json['tax'] ?? 0).toDouble(),
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
      paymentMethod: json['paymentMethod'] ?? 'Card',
      orderNotes: json['orderNotes'],
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      estimatedArrival: (json['estimatedArrival'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerLat': customerLat,
      'customerLng': customerLng,
      'customerAddress': customerAddress,
      if (buildingNumber != null) 'buildingNumber': buildingNumber,
      if (floor != null) 'floor': floor,
      if (apartment != null) 'apartment': apartment,
      if (landmark != null) 'landmark': landmark,
      if (deliveryNotes != null) 'deliveryNotes': deliveryNotes,
      'restaurantLat': restaurantLat,
      'restaurantLng': restaurantLng,
      'restaurantName': restaurantName,
      'restaurantPhone': restaurantPhone,
      'driverId': driverId,
      'driverName': driverName,
      'driverPhotoUrl': driverPhotoUrl,
      'driverPhone': driverPhone,
      if (assignedAt != null) 'assignedAt': Timestamp.fromDate(assignedAt!),
      'status': status.name,
      'orderNumber': orderNumber,
      'items': items
          .map((i) => {
                'name': i.name,
                'quantity': i.quantity,
                'imageUrl': i.imageUrl,
              })
          .toList(),
      'subtotal': subtotal,
      'deliveryFee': deliveryFee,
      'serviceFee': serviceFee,
      'discount': discount,
      'tax': tax,
      'totalAmount': totalAmount,
      'paymentMethod': paymentMethod,
      if (orderNotes != null) 'orderNotes': orderNotes,
      'createdAt': Timestamp.fromDate(createdAt),
      if (estimatedArrival != null)
        'estimatedArrival': Timestamp.fromDate(estimatedArrival!),
    };
  }
}
