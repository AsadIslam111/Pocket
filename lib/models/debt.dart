import 'package:uuid/uuid.dart';

enum DebtType { lent, borrowed }

enum DebtStatus {
  pending_invite,   // Email sent to non-user
  pending_approval, // Notification sent to existing user
  active,           // P2P confirmed
  rejected,         // Peer declined
  manual,           // Either created as manual, or converted from pending
  settled           // Paid off
}

class Debt {
  final String id;
  final String creatorId;
  final String? peerEmail;
  final String? peerId;
  final String peerName;
  final double amount;
  final DebtType type;
  final DebtStatus status;
  final DateTime createdAt;
  final DateTime? fallbackAt;

  Debt({
    String? id,
    required this.creatorId,
    this.peerEmail,
    this.peerId,
    required this.peerName,
    required this.amount,
    required this.type,
    required this.status,
    DateTime? createdAt,
    this.fallbackAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Debt copyWith({
    String? id,
    String? creatorId,
    String? peerEmail,
    String? peerId,
    String? peerName,
    double? amount,
    DebtType? type,
    DebtStatus? status,
    DateTime? createdAt,
    DateTime? fallbackAt,
  }) {
    return Debt(
      id: id ?? this.id,
      creatorId: creatorId ?? this.creatorId,
      peerEmail: peerEmail ?? this.peerEmail,
      peerId: peerId ?? this.peerId,
      peerName: peerName ?? this.peerName,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      fallbackAt: fallbackAt ?? this.fallbackAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'creatorId': creatorId,
      'peerEmail': peerEmail,
      'peerId': peerId,
      'peerName': peerName,
      'amount': amount,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'createdAt': createdAt.toIso8601String(),
      'fallbackAt': fallbackAt?.toIso8601String(),
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
      creatorId: json['creatorId'] ?? '',
      peerEmail: json['peerEmail'],
      peerId: json['peerId'],
      peerName: json['peerName'] ?? 'Unknown',
      amount: (json['amount'] ?? 0).toDouble(),
      type: parsedType,
      status: parsedStatus,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      fallbackAt: json['fallbackAt'] != null
          ? DateTime.parse(json['fallbackAt'])
          : null,
    );
  }
}
