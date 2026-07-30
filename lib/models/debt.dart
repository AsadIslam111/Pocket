import 'package:uuid/uuid.dart';

enum DebtType { lent, borrowed }

enum DebtStatus {
  pending_invite,   // Email sent to non-user
  pending_approval, // Notification sent to existing user
  active,           // P2P confirmed
  rejected,         // Peer declined
  manual,           // Either created as manual, or converted from pending
  settlement_requested, // Borrower has requested a payment/settlement
  settled           // Paid off
}

class DebtPayment {
  final String id;
  final double amount;
  final DateTime date;
  final String? note;

  DebtPayment({
    String? id,
    required this.amount,
    DateTime? date,
    this.note,
  })  : id = id ?? const Uuid().v4(),
        date = date ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'date': date.toIso8601String(),
      'note': note,
    };
  }

  factory DebtPayment.fromJson(Map<String, dynamic> json) {
    return DebtPayment(
      id: json['id'] ?? const Uuid().v4(),
      amount: (json['amount'] ?? 0).toDouble(),
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      note: json['note'],
    );
  }
}

class Debt {
  final String id;
  final String? description;
  final DateTime? dueDate;
  final List<DebtPayment> paymentHistory;
  final String creatorId;
  final String? creatorName;
  final String? creatorEmail;
  final String? peerEmail;
  final String? peerId;
  final String peerName;
  final double amount;
  final double? amountPaid;
  final DebtType type;
  final DebtStatus status;
  final DateTime createdAt;
  final DateTime? fallbackAt;

  // Fields for pending settlement requests
  final double? pendingPaymentAmount;
  final DateTime? pendingPaymentDate;
  final String? pendingPaymentNote;

  Debt({
    String? id,
    this.description,
    this.dueDate,
    List<DebtPayment>? paymentHistory,
    required this.creatorId,
    this.creatorName,
    this.creatorEmail,
    this.peerEmail,
    this.peerId,
    required this.peerName,
    required this.amount,
    this.amountPaid = 0.0,
    required this.type,
    required this.status,
    DateTime? createdAt,
    this.fallbackAt,
    this.pendingPaymentAmount,
    this.pendingPaymentDate,
    this.pendingPaymentNote,
  })  : id = id ?? const Uuid().v4(),
        paymentHistory = paymentHistory ?? [],
        createdAt = createdAt ?? DateTime.now();

  @override
  String toString() => 'Debt(id: $id, amount: $amount, paid: $amountPaid)';

  double get remainingAmount => amount - (amountPaid ?? 0.0);

  Debt copyWith({
    String? id,
    String? description,
    DateTime? dueDate,
    List<DebtPayment>? paymentHistory,
    String? creatorId,
    String? creatorName,
    String? creatorEmail,
    String? peerEmail,
    String? peerId,
    String? peerName,
    double? amount,
    double? amountPaid,
    DebtType? type,
    DebtStatus? status,
    DateTime? createdAt,
    DateTime? fallbackAt,
    double? pendingPaymentAmount,
    DateTime? pendingPaymentDate,
    String? pendingPaymentNote,
  }) {
    return Debt(
      id: id ?? this.id,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      paymentHistory: paymentHistory ?? this.paymentHistory,
      creatorId: creatorId ?? this.creatorId,
      creatorName: creatorName ?? this.creatorName,
      creatorEmail: creatorEmail ?? this.creatorEmail,
      peerEmail: peerEmail ?? this.peerEmail,
      peerId: peerId ?? this.peerId,
      peerName: peerName ?? this.peerName,
      amount: amount ?? this.amount,
      amountPaid: amountPaid ?? this.amountPaid,
      type: type ?? this.type,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      fallbackAt: fallbackAt ?? this.fallbackAt,
      pendingPaymentAmount: pendingPaymentAmount ?? this.pendingPaymentAmount,
      pendingPaymentDate: pendingPaymentDate ?? this.pendingPaymentDate,
      pendingPaymentNote: pendingPaymentNote ?? this.pendingPaymentNote,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'dueDate': dueDate?.toIso8601String(),
      'paymentHistory': paymentHistory.map((p) => p.toJson()).toList(),
      'creatorId': creatorId,
      'creatorName': creatorName,
      'creatorEmail': creatorEmail,
      'peerEmail': peerEmail,
      'peerId': peerId,
      'peerName': peerName,
      'amount': amount,
      'amountPaid': amountPaid ?? 0.0,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'createdAt': createdAt.toIso8601String(),
      'fallbackAt': fallbackAt?.toIso8601String(),
      'pendingPaymentAmount': pendingPaymentAmount,
      'pendingPaymentDate': pendingPaymentDate?.toIso8601String(),
      'pendingPaymentNote': pendingPaymentNote,
    };
  }

  factory Debt.fromJson(Map<String, dynamic> json) {
    // Parse Type
    final typeStr = (json['type'] ?? '').toString().toLowerCase();
    DebtType parsedType = DebtType.lent;
    if (typeStr == 'borrowed') {
      parsedType = DebtType.borrowed;
    }

    // Parse Status
    final statusStr = (json['status'] ?? '').toString().toLowerCase();
    DebtStatus parsedStatus = DebtStatus.manual;
    for (var s in DebtStatus.values) {
      if (s.toString().split('.').last == statusStr) {
        parsedStatus = s;
        break;
      }
    }

    return Debt(
      id: json['id'] ?? const Uuid().v4(),
      description: json['description'],
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
      paymentHistory: (json['paymentHistory'] as List<dynamic>?)
              ?.map((p) => DebtPayment.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      creatorId: json['creatorId'] ?? '',
      creatorName: json['creatorName'],
      creatorEmail: json['creatorEmail'],
      peerEmail: json['peerEmail'],
      peerId: json['peerId'],
      peerName: json['peerName'] ?? 'Unknown',
      amount: (json['amount'] ?? 0).toDouble(),
      amountPaid: (json['amountPaid'] ?? 0.0).toDouble(),
      type: parsedType,
      status: parsedStatus,
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] is String ? DateTime.parse(json['createdAt']) : (json['createdAt'] as dynamic).toDate())
          : DateTime.now(),
      fallbackAt: json['fallbackAt'] != null
          ? (json['fallbackAt'] is String ? DateTime.parse(json['fallbackAt']) : (json['fallbackAt'] as dynamic).toDate())
          : null,
      pendingPaymentAmount: json['pendingPaymentAmount'] != null ? (json['pendingPaymentAmount']).toDouble() : null,
      pendingPaymentDate: json['pendingPaymentDate'] != null ? DateTime.parse(json['pendingPaymentDate']) : null,
      pendingPaymentNote: json['pendingPaymentNote'],
    );
  }
}
