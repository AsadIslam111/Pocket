import 'package:uuid/uuid.dart';

enum TransactionType { income, expense }

class Transaction {
  final String id;
  final double amount;
  final TransactionType type;
  final String title;
  final String category;
  final String account;
  final DateTime date;
  final String? notes;
  final String? receiptUrl;

  Transaction({
    String? id,
    required this.amount,
    required this.type,
    required this.title,
    required this.category,
    required this.account,
    required this.date,
    this.notes,
    this.receiptUrl,
  }) : id = id ?? const Uuid().v4();

  Transaction copyWith({
    String? id,
    double? amount,
    TransactionType? type,
    String? title,
    String? category,
    String? account,
    DateTime? date,
    String? notes,
    String? receiptUrl,
  }) {
    return Transaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      title: title ?? this.title,
      category: category ?? this.category,
      account: account ?? this.account,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      receiptUrl: receiptUrl ?? this.receiptUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'type': type.toString(),
      'title': title,
      'category': category,
      'account': account,
      'date': date.toIso8601String(),
      'notes': notes,
      'receiptUrl': receiptUrl,
    };
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    // Parse type with fallback — handles both "TransactionType.expense" and "expense"
    final typeStr = (json['type'] ?? '').toString().toLowerCase();
    TransactionType parsedType;
    if (typeStr.contains('income')) {
      parsedType = TransactionType.income;
    } else {
      parsedType = TransactionType.expense;
    }

    return Transaction(
      id: json['id'] ?? const Uuid().v4(),
      amount: (json['amount'] ?? 0).toDouble(),
      type: parsedType,
      title: json['title'] ?? 'Untitled',
      category: json['category'] ?? 'Other',
      account: json['account'] ?? 'Cash',
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      notes: json['notes'],
      receiptUrl: json['receiptUrl'],
    );
  }
}
