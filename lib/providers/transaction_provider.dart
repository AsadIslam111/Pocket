import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:pocket_app/models/transaction.dart';

class TransactionProvider extends ChangeNotifier {
  List<Transaction> _transactions = [];
  String _selectedCategory = 'All';
  String _selectedAccount = 'All';
  String? _currentUserId;

  /// Real-time Firestore listener subscription.
  StreamSubscription<QuerySnapshot>? _firestoreSubscription;

  List<Transaction> get transactions => _transactions;
  String get selectedCategory => _selectedCategory;
  String get selectedAccount => _selectedAccount;

  TransactionProvider();

  /// The Firestore collection reference for the current user's transactions.
  CollectionReference? get _txCollection {
    if (_currentUserId == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUserId)
        .collection('transactions');
  }

  // ─── Auth-aware reset ──────────────────────────────────────────────

  void resetForUser(String? userId) {
    debugPrint('🔵 TransactionProvider.resetForUser: current=$_currentUserId, new=$userId');
    if (_currentUserId == userId) {
      debugPrint('🟡 TransactionProvider: Same user, skipping reset');
      return;
    }
    _currentUserId = userId;
    _transactions = [];
    _selectedCategory = 'All';
    _selectedAccount = 'All';

    // Cancel any previous listener.
    _firestoreSubscription?.cancel();
    _firestoreSubscription = null;

    notifyListeners();

    if (userId != null) {
      _listenToFirestore();
      // Also do a one-time fetch as fallback in case listener is slow
      _fetchOnce();
    }
  }

  /// Real-time listener for ongoing sync.
  void _listenToFirestore() {
    final col = _txCollection;
    if (col == null) return;

    debugPrint('🔵 TransactionProvider: Setting up Firestore listener');

    _firestoreSubscription = col.snapshots().listen(
      (snapshot) {
        debugPrint('🟢 TransactionProvider: Listener received ${snapshot.docs.length} docs');
        _updateFromDocs(snapshot.docs);
      },
      onError: (e) {
        debugPrint('� TransactionProvider: Listener error: $e');
      },
    );
  }

  /// One-time fetch as fallback — guarantees data loads even if listener is stuck.
  Future<void> _fetchOnce() async {
    final col = _txCollection;
    if (col == null) return;

    try {
      final snapshot = await col.get();
      debugPrint('🟢 TransactionProvider: One-time fetch got ${snapshot.docs.length} docs');
      _updateFromDocs(snapshot.docs);
    } catch (e) {
      debugPrint('🔴 TransactionProvider: One-time fetch error: $e');
    }
  }

  /// Shared helper: parse docs into Transaction list and notify.
  void _updateFromDocs(List<QueryDocumentSnapshot> docs) {
    final List<Transaction> parsed = [];
    for (final doc in docs) {
      try {
        final data = doc.data() as Map<String, dynamic>;
        parsed.add(Transaction.fromJson(data));
      } catch (e) {
        debugPrint('⚠️ Skipping bad transaction doc ${doc.id}: $e');
      }
    }
    _transactions = parsed;
    _transactions.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
  }

  @override
  void dispose() {
    _firestoreSubscription?.cancel();
    super.dispose();
  }

  // ─── CRUD ──────────────────────────────────────────────────────────

  Future<void> addTransaction(Transaction transaction) async {
    final col = _txCollection;
    if (col == null) {
      throw Exception('Not logged in. Cannot save transaction.');
    }

    try {
      await col.doc(transaction.id).set(transaction.toJson());
      debugPrint('🟢 TransactionProvider: Write succeeded for ${transaction.id}');

      // Immediately add to local list (don't wait for listener)
      if (!_transactions.any((t) => t.id == transaction.id)) {
        _transactions.add(transaction);
        _transactions.sort((a, b) => b.date.compareTo(a.date));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('🔴 TransactionProvider: Write error: $e');
      rethrow;
    }
  }

  Future<void> updateTransaction(Transaction transaction) async {
    final col = _txCollection;
    if (col == null) {
      throw Exception('Not logged in. Cannot update transaction.');
    }

    try {
      await col.doc(transaction.id).update(transaction.toJson());

      // Update local list immediately
      final index = _transactions.indexWhere((t) => t.id == transaction.id);
      if (index != -1) {
        _transactions[index] = transaction;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating transaction: $e');
      rethrow;
    }
  }

  Future<void> deleteTransaction(String id) async {
    final col = _txCollection;
    if (col == null) {
      throw Exception('Not logged in. Cannot delete transaction.');
    }

    try {
      await col.doc(id).delete();

      // Remove from local list immediately
      _transactions.removeWhere((t) => t.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting transaction: $e');
      rethrow;
    }
  }

  // ─── Filters ───────────────────────────────────────────────────────

  void setSelectedCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setSelectedAccount(String account) {
    _selectedAccount = account;
    notifyListeners();
  }

  List<Transaction> getFilteredTransactions() {
    return _transactions.where((transaction) {
      bool categoryMatch = _selectedCategory == 'All' ||
          transaction.category == _selectedCategory;
      bool accountMatch = _selectedAccount == 'All' ||
          transaction.account == _selectedAccount;
      return categoryMatch && accountMatch;
    }).toList();
  }

  // ─── Aggregations ──────────────────────────────────────────────────

  double getTotalIncome() {
    return _transactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double getTotalExpenses() {
    return _transactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double getTotalBalance() {
    return getTotalIncome() - getTotalExpenses();
  }

  List<String> getCategories() {
    return ['All', ..._transactions.map((t) => t.category).toSet()];
  }

  List<String> getAccounts() {
    return ['All', ..._transactions.map((t) => t.account).toSet()];
  }

  // ─── Receipt upload ────────────────────────────────────────────────

  Future<String?> uploadReceipt(String filePath, String transactionId) async {
    if (_currentUserId == null) return null;
    try {
      final file = File(filePath);
      final ref = FirebaseStorage.instance
          .ref()
          .child('users/$_currentUserId/receipts/$transactionId.jpg');

      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      debugPrint('Error uploading receipt: $e');
      return null;
    }
  }
}
