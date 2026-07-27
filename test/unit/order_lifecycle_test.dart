import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:gourmet_go/features/order_tracking/domain/entities/order_entity.dart';

void main() {
  group('OrderStatusExtension Unit Tests', () {
    test('uiString returns correct progress grouping', () {
      expect(OrderStatus.pending.uiString, equals('IN PROGRESS'));
      expect(OrderStatus.preparing.uiString, equals('IN PROGRESS'));
      expect(OrderStatus.driverAssigned.uiString, equals('IN PROGRESS'));
      expect(OrderStatus.outForDelivery.uiString, equals('IN PROGRESS'));
      expect(OrderStatus.delivered.uiString, equals('DELIVERED'));
      expect(OrderStatus.cancelled.uiString, equals('CANCELLED'));
    });

    test('stepString returns human-readable label for each status', () {
      expect(OrderStatus.pending.stepString, equals('Pending'));
      expect(OrderStatus.confirmed.stepString, equals('Confirmed'));
      expect(OrderStatus.preparing.stepString, equals('Preparing'));
      expect(OrderStatus.driverAssigned.stepString, equals('Driver Assigned'));
      expect(OrderStatus.driverAccepted.stepString, equals('Driver Accepted'));
      expect(OrderStatus.driverPickedUp.stepString, equals('Driver At Restaurant'));
      expect(OrderStatus.outForDelivery.stepString, equals('Out For Delivery'));
      expect(OrderStatus.delivered.stepString, equals('Delivered'));
      expect(OrderStatus.cancelled.stepString, equals('Cancelled'));
    });

    test('uiColor returns appropriate status colors', () {
      expect(OrderStatus.pending.uiColor, isA<Color>());
      expect(OrderStatus.delivered.uiColor, isA<Color>());
      expect(OrderStatus.cancelled.uiColor, isA<Color>());
    });
  });

  group('OrderEntity & OrderItemEntity Tests', () {
    test('OrderItemEntity calculates equality and props correctly', () {
      const item1 = OrderItemEntity(name: 'Burger', quantity: 2);
      const item2 = OrderItemEntity(name: 'Burger', quantity: 2);
      const item3 = OrderItemEntity(name: 'Fries', quantity: 1);

      expect(item1, equals(item2));
      expect(item1 == item3, isFalse);
    });

    test('OrderEntity itemsSummary formats correctly', () {
      final order = OrderEntity(
        id: 'ord_123',
        customerId: 'cust_1',
        customerName: 'John Doe',
        customerPhone: '+1234567890',
        customerLat: 30.0,
        customerLng: 31.0,
        customerAddress: '123 Main St',
        restaurantName: 'Gourmet Kitchen',
        restaurantPhone: '+0987654321',
        restaurantLat: 30.01,
        restaurantLng: 31.01,
        items: const [
          OrderItemEntity(name: 'Pizza', quantity: 2),
          OrderItemEntity(name: 'Coke', quantity: 1),
        ],
        subtotal: 25.0,
        deliveryFee: 3.0,
        totalAmount: 28.0,
        status: OrderStatus.preparing,
        orderNumber: '#ORD_1',
        paymentMethod: 'cash',
        createdAt: DateTime(2026, 1, 1),
      );

      expect(order.itemsSummary, contains('2x Pizza'));
      expect(order.itemsSummary, contains('1x Coke'));
      expect(order.orderNumber, equals('#ORD_1'));
    });
  });
}
