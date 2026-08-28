import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class ShopService {
  static final ShopService _instance = ShopService._internal();
  factory ShopService() => _instance;
  ShopService._internal();

  static const _shopIdKey = 'shop_id';
  String? _shopId;

  Future<String> get shopId async {
    if (_shopId != null) return _shopId!;
    final prefs = await SharedPreferences.getInstance();
    _shopId = prefs.getString(_shopIdKey);
    if (_shopId == null) {
      _shopId = const Uuid().v4();
      await prefs.setString(_shopIdKey, _shopId!);
    }
    return _shopId!;
  }

  // Registers the shop profile in Firestore. Safe to call multiple times (merge: true).
  Future<void> init() async {
    try {
      final id = await shopId;
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(id)
          .collection('meta')
          .doc('profile')
          .set(
            {'shopId': id, 'registeredAt': FieldValue.serverTimestamp()},
            SetOptions(merge: true),
          );
    } catch (_) {}
  }

  // Call when the shopkeeper provides their WhatsApp number.
  Future<void> registerPhone(String phone) async {
    final id = await shopId;
    final normalized = phone.replaceAll(RegExp(r'[^\d+]'), '');
    await FirebaseFirestore.instance
        .collection('phone_registry')
        .doc(normalized)
        .set({'shopId': id, 'registeredAt': FieldValue.serverTimestamp()});
  }
}
