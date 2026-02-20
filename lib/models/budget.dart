import 'package:uuid/uuid.dart';

class Budget {
  final String id;
  final String category;
  final double limit;
  final double spent;
  final String icon;

  Budget({
    String? id,
    required this.category,
    required this.limit,
    this.spent = 0.0,
    required this.icon,
  }) : id = id ?? const Uuid().v4();

  double get remaining => limit - spent;
  double get progressPercentage => (spent / limit * 100).clamp(0.0, 100.0);
  bool get isOverBudget => spent > limit;

  Budget copyWith({
    String? id,
    String? category,
    double? limit,
    double? spent,
    String? icon,
  }) {
    return Budget(
      id: id ?? this.id,
      category: category ?? this.category,
      limit: limit ?? this.limit,
      spent: spent ?? this.spent,
      icon: icon ?? this.icon,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'limit': limit,
      'spent': spent,
      'icon': icon,
    };
  }

  factory Budget.fromJson(Map<String, dynamic> json) {
    return Budget(
      id: json['id'] ?? const Uuid().v4(),
      category: json['category'] ?? 'Other',
      limit: (json['limit'] ?? 0).toDouble(),
      spent: (json['spent'] ?? 0).toDouble(),
      icon: json['icon'] ?? '💰',
    );
  }
}
