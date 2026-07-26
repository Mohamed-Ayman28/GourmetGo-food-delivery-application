const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.onOrderStatusChanged = functions.firestore
  .document("orders/{orderId}")
  .onUpdate(async (change, context) => {
    const newData = change.after.data();
    const previousData = change.before.data();

    // If status didn't change, do nothing
    if (newData.status === previousData.status) {
      return null;
    }

    const customerId = newData.customerId;
    const driverId = newData.driverId; // Might be null
    const orderId = context.params.orderId;
    const status = newData.status;

    const messages = [];

    // Notification for Customer
    let customerTitle = "";
    let customerBody = "";

    switch (status) {
      case "confirmed":
        customerTitle = "Order Confirmed!";
        customerBody = `Your order #${orderId.substring(0, 5)} has been confirmed by the restaurant.`;
        break;
      case "preparing":
        customerTitle = "Order Preparing";
        customerBody = `The restaurant is now preparing your order.`;
        break;
      case "outForDelivery":
        customerTitle = "Out for Delivery!";
        customerBody = `Your order is on the way! Driver is heading to your location.`;
        break;
      case "delivered":
        customerTitle = "Order Delivered";
        customerBody = `Your order has been delivered. Enjoy your meal!`;
        break;
      case "cancelled":
        customerTitle = "Order Cancelled";
        customerBody = `Your order #${orderId.substring(0, 5)} has been cancelled.`;
        break;
    }

    if (customerTitle !== "" && customerId) {
      const customerDoc = await admin.firestore().collection("users").doc(customerId).get();
      if (customerDoc.exists) {
        const tokens = customerDoc.data().fcmTokens || [];
        if (tokens.length > 0) {
          messages.push({
            notification: { title: customerTitle, body: customerBody },
            tokens: tokens,
          });
        }
      }
    }

    // Notification for Driver (when assigned)
    if (status === "driverAssigned" && driverId) {
      const driverDoc = await admin.firestore().collection("users").doc(driverId).get();
      if (driverDoc.exists) {
        const tokens = driverDoc.data().fcmTokens || [];
        if (tokens.length > 0) {
          messages.push({
            notification: {
              title: "New Order Assigned",
              body: `You have been assigned order #${orderId.substring(0, 5)}. Please accept it.`,
            },
            tokens: tokens,
          });
        }
      }
    }

    // Send all messages
    const sendPromises = messages.map(msg => admin.messaging().sendMulticast(msg));
    await Promise.all(sendPromises);

    return null;
  });
