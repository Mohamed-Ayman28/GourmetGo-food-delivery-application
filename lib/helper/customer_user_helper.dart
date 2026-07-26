import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class CustomerUserHelper {
  static const String _guestKey = 'guest_customer_id';

  /// Returns the authenticated Firebase user ID if available, or a persistent device guest ID.
  static Future<String> getCustomerId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.uid.isNotEmpty) {
      return user.uid;
    }
    final prefs = await SharedPreferences.getInstance();
    String? guestId = prefs.getString(_guestKey);
    if (guestId == null || guestId.isEmpty) {
      guestId = 'guest_${const Uuid().v4().substring(0, 8)}';
      await prefs.setString(_guestKey, guestId);
    }
    return guestId;
  }
}
