import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirestoreHelper {
  static Future<void> waitForPendingWrites() async {
    try {
      await FirebaseFirestore.instance.waitForPendingWrites();
    } catch (e) {
      debugPrint('Error waiting for pending writes: $e');
    }
  }

  static Future<void> signOutWithPendingWrites() async {
    await waitForPendingWrites();
    await FirebaseAuth.instance.signOut();
  }

  static Future<bool> retryTransaction(
    Future<void> Function(Transaction) transactionFn, {
    int maxRetries = 3,
    Duration initialDelay = const Duration(milliseconds: 500),
  }) async {
    int attempts = 0;
    Duration delay = initialDelay;

    while (attempts < maxRetries) {
      try {
        await FirebaseFirestore.instance.runTransaction(transactionFn);
        return true;
      } on FirebaseException catch (e) {
        attempts++;
        if (attempts >= maxRetries) {
          debugPrint('Transaction failed after $maxRetries attempts: $e');
          rethrow;
        }
        if (e.code == 'aborted' || e.code == 'failed-precondition') {
          debugPrint('Transaction aborted, retrying ($attempts/$maxRetries)...');
          await Future.delayed(delay);
          delay *= 2; // Exponential backoff
        } else {
          rethrow;
        }
      }
    }
    return false;
  }
}