import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pocket_app/models/debt.dart';
import 'dart:async';

class DebtProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Debt> _debts = [];
  bool _isLoading = false;
  String? _errorMessage;
  
  StreamSubscription<QuerySnapshot>? _debtSubscription;
  String? _currentUserId;

  List<Debt> get debts => _debts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Fetch debts for the user (both created by them, or involving them)
  void resetForUser(String? userId, String? userEmail) {
    if (_currentUserId == userId) return; // Prevent redundant fetches

    _currentUserId = userId;
    _debtSubscription?.cancel();

    if (userId == null) {
      _debts = [];
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    Future.microtask(() => notifyListeners());

    try {
      // Create a stream that listens to both sides of the debt relationship
      _debtSubscription = _firestore
          .collection('debts')
          .where(
            Filter.or(
              Filter('creatorId', isEqualTo: userId),
              Filter('peerId', isEqualTo: userId),
              Filter('peerEmail', isEqualTo: userEmail ?? ''),
            ),
          )
          .snapshots()
          .listen((snapshot) {
        _debts = snapshot.docs.map((doc) => Debt.fromJson(doc.data())).toList();
        
        // Sort: pending first, then active/manual, then settled by date
        _debts.sort((a, b) {
          if (a.status.name.startsWith('pending') && !b.status.name.startsWith('pending')) return -1;
          if (!a.status.name.startsWith('pending') && b.status.name.startsWith('pending')) return 1;
          return b.createdAt.compareTo(a.createdAt);
        });

        _checkAndConvertExpiredDebts(); // Auto-convert tool
        _errorMessage = null;
        notifyListeners();
      }, onError: (error) {
        debugPrint('Firestore Stream Error: $error');
        _isLoading = false;
        _errorMessage = error.toString();
        notifyListeners();
      });
    } catch (e) {
      debugPrint('Error fetching debts: $e');
      _isLoading = false;
      _errorMessage = e.toString();
      Future.microtask(() => notifyListeners());
    }
  }

  /// Create a purely manual debt
  Future<void> createManualDebt({
    required String creatorId,
    required String peerName,
    required double amount,
    required DebtType type,
  }) async {
    try {
      final debt = Debt(
        creatorId: creatorId,
        peerName: peerName,
        amount: amount,
        type: type,
        status: DebtStatus.manual,
      );
      await _firestore.collection('debts').doc(debt.id).set(debt.toJson());
    } catch (e) {
      debugPrint('Error creating manual debt: \$e');
      rethrow;
    }
  }

  /// The main P2P workflow trigger
  Future<void> createP2PDebtRequest({
    required String creatorId,
    required String peerEmail,
    required double amount,
    required DebtType type,
  }) async {
    try {
      // 1. Search for user by email
      final userSnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: peerEmail)
          .limit(1)
          .get();

      String? foundPeerId;
      String foundPeerName = peerEmail; // Fallback to email as name
      DebtStatus initialStatus = DebtStatus.pending_invite;

      if (userSnapshot.docs.isNotEmpty) {
        // User exists!
        foundPeerId = userSnapshot.docs.first.id;
        foundPeerName = userSnapshot.docs.first.data()['displayName'] ?? peerEmail;
        initialStatus = DebtStatus.pending_approval;
      }

      // 2. Create the debt object
      final debt = Debt(
        creatorId: creatorId,
        peerEmail: peerEmail,
        peerId: foundPeerId,
        peerName: foundPeerName,
        amount: amount,
        type: type,
        status: initialStatus,
        fallbackAt: DateTime.now().add(const Duration(hours: 24)), // 24-hour timer
      );

      // 3. Save to DB
      await _firestore.collection('debts').doc(debt.id).set(debt.toJson());

    } catch (e) {
      debugPrint('Error creating P2P request: \$e');
      rethrow;
    }
  }

  /// For the Target user to accept the request
  Future<void> acceptDebtRequest(Debt debt, String myUserId, String myUserName) async {
    try {
      await _firestore.collection('debts').doc(debt.id).update({
        'status': DebtStatus.active.toString().split('.').last,
        'peerId': myUserId, // Just in case it was a pending_invite they just signed up for
        'peerName': myUserName,
      });
    } catch (e) {
      debugPrint('Error accepting debt: \$e');
      rethrow;
    }
  }

  /// For the Target user to decline the request
  Future<void> rejectDebtRequest(String debtId) async {
    try {
      await _firestore.collection('debts').doc(debtId).update({
        'status': DebtStatus.rejected.toString().split('.').last,
      });
    } catch (e) {
      debugPrint('Error rejecting debt: \$e');
      rethrow;
    }
  }

  /// For the Creator to cancel their own request before it's accepted
  Future<void> cancelDebtRequest(String debtId) async {
    try {
      await _firestore.collection('debts').doc(debtId).delete();
    } catch (e) {
      debugPrint('Error canceling debt: \$e');
      rethrow;
    }
  }

  /// For the Creator to bypass the 24h wait
  Future<void> convertToManualDebt(String debtId) async {
    try {
      await _firestore.collection('debts').doc(debtId).update({
        'status': DebtStatus.manual.toString().split('.').last,
        'fallbackAt': null, // Remove the timer
      });
    } catch (e) {
      debugPrint('Error converting debt to manual: \$e');
      rethrow;
    }
  }

  /// Mark any debt as fully paid
  Future<void> markAsSettled(String debtId) async {
     try {
      await _firestore.collection('debts').doc(debtId).update({
        'status': DebtStatus.settled.toString().split('.').last,
      });
    } catch (e) {
      debugPrint('Error settling debt: \$e');
      rethrow;
    }
  }

  /// Internal checker that runs every time fetch completes or app opens
  void _checkAndConvertExpiredDebts() {
    final now = DateTime.now();
    bool needsUpdate = false;

    for (var debt in _debts) {
      if ((debt.status == DebtStatus.pending_invite || debt.status == DebtStatus.pending_approval) &&
          debt.fallbackAt != null &&
          now.isAfter(debt.fallbackAt!)) {
        
        // It has expired! Update it on Firestore
        convertToManualDebt(debt.id);
        needsUpdate = true;
      }
    }

    if (!needsUpdate) {
       _isLoading = false;
    }
  }

  @override
  void dispose() {
    _debtSubscription?.cancel();
    super.dispose();
  }
}
