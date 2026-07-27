import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gourmet_go/features/order_tracking/domain/entities/order_entity.dart';

void main() {
  group('Order Flow UI E2E Widget Tests', () {
    testWidgets('Renders Order Status Badges correctly', (WidgetTester tester) async {
      final sampleOrder = OrderEntity(
        id: 'ord_999',
        customerId: 'c999',
        customerName: 'Customer Test',
        customerPhone: '+1000000',
        customerLat: 30.0,
        customerLng: 31.0,
        customerAddress: '123 Test Street',
        restaurantName: 'Gourmet Kitchen',
        restaurantPhone: '+2000000',
        restaurantLat: 30.01,
        restaurantLng: 31.01,
        items: const [OrderItemEntity(name: 'Pizza', quantity: 2)],
        subtotal: 20.0,
        deliveryFee: 3.0,
        totalAmount: 23.0,
        status: OrderStatus.outForDelivery,
        paymentMethod: 'cash',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Card(
              child: ListTile(
                title: Text(sampleOrder.customerName),
                subtitle: Text(sampleOrder.status.stepString),
                trailing: Text('\$${sampleOrder.totalAmount}'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Customer Test'), findsOneWidget);
      expect(find.text('Out For Delivery'), findsOneWidget);
      expect(find.text('\$23.0'), findsOneWidget);
    });

    testWidgets('Renders Delivered status correctly', (WidgetTester tester) async {
      const status = OrderStatus.delivered;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              color: status.uiColor,
              child: Text(status.stepString),
            ),
          ),
        ),
      );

      expect(find.text('Delivered'), findsOneWidget);
    });
  });
}
