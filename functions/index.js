const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");
admin.initializeApp();

// Configure the SMTP transport using environment config
// e.g. firebase functions:config:set smtp.user="your-email@gmail.com" smtp.pass="your-password"
// If not configured, it will fail to send, so fallback or logging is needed.
const mailTransport = nodemailer.createTransport({
  service: 'gmail', // Standardizing on gmail for now, can be configured
  auth: {
    user: process.env.SMTP_USER || functions.config().smtp?.user || "demo@example.com",
    pass: process.env.SMTP_PASS || functions.config().smtp?.pass || "password",
  },
});
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

// --- FORGOT PASSWORD VIA OTP ---

exports.requestPasswordReset = functions.https.onCall(async (data, context) => {
  const email = data.email;
  if (!email) {
    throw new functions.https.HttpsError("invalid-argument", "Email is required.");
  }

  let userRecord;
  try {
    userRecord = await admin.auth().getUserByEmail(email);
  } catch (error) {
    // Return success to avoid email enumeration, but do nothing
    return { success: true, message: "If this email is registered, an OTP will be sent." };
  }

  // Verify Role in Firestore
  const userDoc = await admin.firestore().collection("users").doc(userRecord.uid).get();
  if (!userDoc.exists) {
    throw new functions.https.HttpsError("permission-denied", "User data not found.");
  }

  const role = userDoc.data().role?.trim().toLowerCase();
  if (role !== "customer" && role !== "admin") {
    throw new functions.https.HttpsError("permission-denied", "This feature is not available for this account type.");
  }

  // Rate Limiting
  const resetRef = admin.firestore().collection("password_resets").doc(userRecord.uid);
  const resetDoc = await resetRef.get();
  
  if (resetDoc.exists) {
    const lastRequested = resetDoc.data().createdAt.toDate();
    const now = new Date();
    // 60 seconds cooldown
    if ((now - lastRequested) < 60000) {
      throw new functions.https.HttpsError("resource-exhausted", "Please wait before requesting a new OTP.");
    }
  }

  // Generate 6-digit OTP
  const otp = Math.floor(100000 + Math.random() * 900000).toString();
  const expiresAt = new Date(Date.now() + 10 * 60000); // 10 minutes

  await resetRef.set({
    otp: otp,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
  });

  // Send Email
  const mailOptions = {
    from: '"GourmetGo Admin" <noreply@gourmetgo.com>',
    to: email,
    subject: "Your Password Reset OTP",
    text: `Your OTP for password reset is: ${otp}. It will expire in 10 minutes.`,
    html: `<p>Your OTP for password reset is: <strong>${otp}</strong>.</p><p>It will expire in 10 minutes.</p>`,
  };

  try {
    await mailTransport.sendMail(mailOptions);
  } catch (error) {
    console.error("Error sending email:", error);
    // Even if email fails (e.g. SMTP not configured), we shouldn't crash the frontend immediately,
    // but maybe throw an error for the developer.
    throw new functions.https.HttpsError("internal", "Failed to send email. Please check SMTP config.");
  }

  return { success: true, message: "OTP sent successfully." };
});

exports.verifyOTPAndResetPassword = functions.https.onCall(async (data, context) => {
  const { email, otp, newPassword } = data;
  if (!email || !otp || !newPassword) {
    throw new functions.https.HttpsError("invalid-argument", "Missing required fields.");
  }
  
  if (newPassword.length < 6) {
     throw new functions.https.HttpsError("invalid-argument", "Password must be at least 6 characters.");
  }

  let userRecord;
  try {
    userRecord = await admin.auth().getUserByEmail(email);
  } catch (error) {
    throw new functions.https.HttpsError("not-found", "User not found.");
  }

  const resetRef = admin.firestore().collection("password_resets").doc(userRecord.uid);
  const resetDoc = await resetRef.get();

  if (!resetDoc.exists) {
    throw new functions.https.HttpsError("failed-precondition", "No pending password reset found or it has expired.");
  }

  const resetData = resetDoc.data();
  if (resetData.otp !== otp) {
    throw new functions.https.HttpsError("invalid-argument", "Invalid OTP.");
  }

  const now = new Date();
  if (now > resetData.expiresAt.toDate()) {
    await resetRef.delete();
    throw new functions.https.HttpsError("failed-precondition", "OTP has expired. Please request a new one.");
  }

  // Update password
  await admin.auth().updateUser(userRecord.uid, {
    password: newPassword,
  });

  // Invalidate OTP
  await resetRef.delete();

  return { success: true, message: "Password updated successfully." };
});
