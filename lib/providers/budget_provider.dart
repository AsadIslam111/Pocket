import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pocket_app/models/budget.dart';

class BudgetProvider extends ChangeNotifier {
  List<Budget> _budgets = [];
  String? _currentUserId;

  /// Real-time Firestore listener subscription.
  StreamSubscription<QuerySnapshot>? _firestoreSubscription;

  List<Budget> get budgets => _budgets;

  BudgetProvider();

  /// The Firestore collection reference for the current user's budgets.
  CollectionReference? get _budgetCollection {
    if (_currentUserId == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUserId)
        .collection('budgets');
  }

  // ─── Auth-aware reset ──────────────────────────────────────────────

  void resetForUser(String? userId) {
    if (_currentUserId == userId) return;
    _currentUserId = userId;
    _budgets = [];

    _firestoreSubscription?.cancel();
    _firestoreSubscription = null;

    notifyListeners();

    if (userId != null) {
      _listenToFirestore();
      _fetchOnce();
    }
  }

  void _listenToFirestore() {
    final col = _budgetCollection;
    if (col == null) return;

    _firestoreSubscription = col.snapshots().listen(
      (snapshot) {
        _updateFromDocs(snapshot.docs);
      },
      onError: (e) {
        debugPrint('🔴 BudgetProvider: Listener error: $e');
      },
    );
  }

  Future<void> _fetchOnce() async {
    final col = _budgetCollection;
    if (col == null) return;

    try {
      final snapshot = await col.get();
      _updateFromDocs(snapshot.docs);
    } catch (e) {
      debugPrint('🔴 BudgetProvider: Fetch error: $e');
    }
  }

  void _updateFromDocs(List<QueryDocumentSnapshot> docs) {
    final List<Budget> parsed = [];
    for (final doc in docs) {
      try {
        final data = doc.data() as Map<String, dynamic>;
        parsed.add(Budget.fromJson(data));
      } catch (e) {
        debugPrint('⚠️ Skipping bad budget doc ${doc.id}: $e');
      }
    }
    _budgets = parsed;
    notifyListeners();
  }

  @override
  void dispose() {
    _firestoreSubscription?.cancel();
    super.dispose();
  }

  // ─── CRUD ──────────────────────────────────────────────────────────

  Future<void> addBudget(Budget budget) async {
    final col = _budgetCollection;
    if (col == null) throw Exception('Not logged in.');

    try {
      await col.doc(budget.id).set(budget.toJson());
      if (!_budgets.any((b) => b.id == budget.id)) {
        _budgets.add(budget);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error adding budget: $e');
      rethrow;
    }
  }

  Future<void> updateBudget(Budget budget) async {
    final col = _budgetCollection;
    if (col == null) throw Exception('Not logged in.');

    try {
      await col.doc(budget.id).update(budget.toJson());
      final index = _budgets.indexWhere((b) => b.id == budget.id);
      if (index != -1) {
        _budgets[index] = budget;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating budget: $e');
      rethrow;
    }
  }

  Future<void> deleteBudget(String id) async {
    final col = _budgetCollection;
    if (col == null) throw Exception('Not logged in.');

    try {
      await col.doc(id).delete();
      _budgets.removeWhere((b) => b.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting budget: $e');
      rethrow;
    }
  }

  Future<void> updateBudgetSpending(String category, double amount) async {
    final col = _budgetCollection;
    if (col == null) return;

    final index = _budgets.indexWhere((b) => b.category == category);
    if (index != -1) {
      final budget = _budgets[index];
      final newBudget = budget.copyWith(spent: budget.spent + amount);

      try {
        await col.doc(newBudget.id).update(newBudget.toJson());
        _budgets[index] = newBudget;
        notifyListeners();
      } catch (e) {
        debugPrint('Error updating budget spending: $e');
      }
    }
  }

  // ─── Aggregations ──────────────────────────────────────────────────

  double getTotalBudgetLimit() {
    return _budgets.fold(0.0, (sum, budget) => sum + budget.limit);
  }

  double getTotalBudgetSpent() {
    return _budgets.fold(0.0, (sum, budget) => sum + budget.spent);
  }

  double getTotalBudgetRemaining() {
    return getTotalBudgetLimit() - getTotalBudgetSpent();
  }

  List<Budget> getOverBudgetCategories() {
    return _budgets.where((budget) => budget.isOverBudget).toList();
  }
}
