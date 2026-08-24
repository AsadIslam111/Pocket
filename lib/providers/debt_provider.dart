import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pocket_app/models/debt.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
        _isLoading = false;
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
    required String creatorName,
    String? creatorEmail,
    required String peerName,
    required double amount,
    required DebtType type,
  }) async {
    try {
      final debt = Debt(
        creatorId: creatorId,
        creatorName: creatorName,
        creatorEmail: creatorEmail,
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

  /// Update a manual debt
  Future<void> updateManualDebt({
    required String debtId,
    required String peerName,
    required double amount,
    required DebtType type,
  }) async {
    try {
      await _firestore.collection('debts').doc(debtId).update({
        'peerName': peerName,
        'amount': amount,
        'type': type.toString().split('.').last,
      });
    } catch (e) {
      debugPrint('Error updating manual debt: \$e');
      rethrow;
    }
  }

  /// Delete a debt (used for manual debts or dismissing rejected/settled debts)
  Future<void> deleteDebt(String debtId) async {
    try {
      await _firestore.collection('debts').doc(debtId).delete();
    } catch (e) {
      debugPrint('Error deleting debt: \$e');
      rethrow;
    }
  }

  /// The main P2P workflow trigger
  Future<void> createP2PDebtRequest({
    required String creatorId,
    required String creatorName,
    String? creatorEmail,
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
        creatorName: creatorName,
        creatorEmail: creatorEmail,
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

      // 4. Handle Invite if user doesn't exist
      if (foundPeerId == null) {
        await _sendEmailInvite(peerEmail, amount, type);
      }

    } catch (e) {
      debugPrint('Error creating P2P request: $e');
      rethrow;
    }
  }

  /// Opens the native email app to send an invite
  Future<void> _sendEmailInvite(String email, double amount, DebtType type) async {
    final String action = type == DebtType.lent ? "lent you" : "borrowed";
    final String personAction = type == DebtType.lent ? "borrowed" : "lent";
    
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: email,
      query: encodeQueryParameters(<String, String>{
        'subject': 'Pocket App: Debt/Loan Request',
        'body': 'Hi!\n\nI just added a record in the Pocket App that I $action ৳ $amount. '
                'Please join the app so we can track this together: https://play.google.com/store/apps/details?id=com.asad.pocket_app\n\n'
                'Regards!'
      }),
    );

    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    } else {
      debugPrint('Could not launch email app');
    }
  }

  String? encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((MapEntry<String, String> e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
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

  /// Borrower requests a payment/settlement
  Future<void> requestPayment(String debtId, double paymentAmount, {String? note, DateTime? date}) async {
    try {
      await _firestore.collection('debts').doc(debtId).update({
        'status': DebtStatus.settlement_requested.toString().split('.').last,
        'pendingPaymentAmount': paymentAmount,
        'pendingPaymentNote': note,
        'pendingPaymentDate': date?.toIso8601String(),
      });

      // Fetch debt to identify the lender
      final debtDoc = await _firestore.collection('debts').doc(debtId).get();
      if (debtDoc.exists) {
        final currentDebt = Debt.fromJson(debtDoc.data()!);
        bool amICreator = currentDebt.creatorId == _currentUserId;
        String targetUserId = amICreator ? (currentDebt.peerId ?? '') : currentDebt.creatorId;
        
        if (targetUserId.isNotEmpty) {
          await _sendOneSignalNotification(
            targetUserId: targetUserId,
            heading: "Payment Requested",
            content: "A payment of ৳${paymentAmount.toStringAsFixed(0)} is waiting for your approval.",
          );
        }
      }
    } catch (e) {
      debugPrint('Error requesting payment: $e');
      rethrow;
    }
  }

  Future<void> _sendOneSignalNotification({required String targetUserId, required String heading, required String content}) async {
    try {
      final appId = dotenv.env['ONESIGNAL_APP_ID'];
      final restKey = dotenv.env['ONESIGNAL_REST_KEY'];
      
      if (appId == null || restKey == null) {
        debugPrint('OneSignal App ID or REST Key is missing in .env file');
        return;
      }

      final response = await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Basic $restKey',
        },
        body: jsonEncode({
          'app_id': appId,
          'include_aliases': {
            'external_id': [targetUserId]
          },
          'target_channel': 'push',
          'headings': {'en': heading},
          'contents': {'en': content},
        }),
      );
      if (response.statusCode != 200) {
        debugPrint('OneSignal API Error: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  /// Lender approves the payment request
  Future<void> approvePaymentRequest(String debtId) async {
    try {
      final debtDoc = await _firestore.collection('debts').doc(debtId).get();
      if (!debtDoc.exists) return;
      
      final currentDebt = Debt.fromJson(debtDoc.data()!);
      final paymentAmount = currentDebt.pendingPaymentAmount ?? 0.0;
      final note = currentDebt.pendingPaymentNote;
      final date = currentDebt.pendingPaymentDate ?? DateTime.now();

      final newPaidAmount = (currentDebt.amountPaid ?? 0.0) + paymentAmount;
      final bool fullyPaid = newPaidAmount >= currentDebt.amount;
      
      final payment = DebtPayment(amount: paymentAmount, note: note, date: date);

      await _firestore.collection('debts').doc(debtId).update({
        'amountPaid': newPaidAmount,
        'paymentHistory': FieldValue.arrayUnion([payment.toJson()]),
        'status': fullyPaid ? DebtStatus.settled.toString().split('.').last : DebtStatus.active.toString().split('.').last,
        'pendingPaymentAmount': null,
        'pendingPaymentNote': null,
        'pendingPaymentDate': null,
      });

      // Send approval notification to borrower
      bool amICreator = currentDebt.creatorId == _currentUserId;
      String targetUserId = amICreator ? (currentDebt.peerId ?? '') : currentDebt.creatorId;
      if (targetUserId.isNotEmpty) {
        await _sendOneSignalNotification(
          targetUserId: targetUserId,
          heading: "Payment Approved",
          content: "Your payment of ৳${paymentAmount.toStringAsFixed(0)} was approved!",
        );
      }
    } catch (e) {
      debugPrint('Error approving payment request: $e');
      rethrow;
    }
  }

  /// Lender declines the payment request
  Future<void> declinePaymentRequest(String debtId) async {
    try {
      final debtDoc = await _firestore.collection('debts').doc(debtId).get();
      if (!debtDoc.exists) return;
      final currentDebt = Debt.fromJson(debtDoc.data()!);
      final paymentAmount = currentDebt.pendingPaymentAmount ?? 0.0;

      await _firestore.collection('debts').doc(debtId).update({
        'status': DebtStatus.active.toString().split('.').last,
        'pendingPaymentAmount': null,
        'pendingPaymentNote': null,
        'pendingPaymentDate': null,
      });

      // Send decline notification to borrower
      bool amICreator = currentDebt.creatorId == _currentUserId;
      String targetUserId = amICreator ? (currentDebt.peerId ?? '') : currentDebt.creatorId;
      if (targetUserId.isNotEmpty) {
        await _sendOneSignalNotification(
          targetUserId: targetUserId,
          heading: "Payment Declined",
          content: "Your payment request of ৳${paymentAmount.toStringAsFixed(0)} was declined.",
        );
      }
    } catch (e) {
      debugPrint('Error declining payment request: $e');
      rethrow;
    }
  }

  /// Settle an amount for a debt (used for manual debts or direct lender additions)
  Future<void> addPayment(String debtId, double paymentAmount, {String? note, DateTime? date}) async {
    try {
      final debtDoc = await _firestore.collection('debts').doc(debtId).get();
      if (!debtDoc.exists) return;
      
      final currentDebt = Debt.fromJson(debtDoc.data()!);
      final newPaidAmount = (currentDebt.amountPaid ?? 0.0) + paymentAmount;
      
      // If fully paid, change status to settled
      final bool fullyPaid = newPaidAmount >= currentDebt.amount;
      
      final payment = DebtPayment(amount: paymentAmount, note: note, date: date);

      await _firestore.collection('debts').doc(debtId).update({
        'amountPaid': newPaidAmount,
        'paymentHistory': FieldValue.arrayUnion([payment.toJson()]),
        if (fullyPaid) 'status': DebtStatus.settled.toString().split('.').last,
      });
    } catch (e) {
      debugPrint('Error recording payment: \$e');
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

    for (var debt in _debts) {
      if ((debt.status == DebtStatus.pending_invite || debt.status == DebtStatus.pending_approval) &&
          debt.fallbackAt != null &&
          now.isAfter(debt.fallbackAt!)) {
        
        // It has expired! Update it on Firestore
        convertToManualDebt(debt.id);
      }
    }
  }

  @override
  void dispose() {
    _debtSubscription?.cancel();
    super.dispose();
  }
}
