import 'package:flutter/material.dart';
import 'package:pocket_app/models/transaction.dart';

Color getCategoryColor(String category) {
  switch (category.toLowerCase()) {
    case 'food':
      return Colors.orange;
    case 'transportation':
      return Colors.blue;
    case 'entertainment':
      return Colors.purple;
    case 'shopping':
      return Colors.pink;
    case 'utilities':
      return Colors.green;
    case 'salary':
      return Colors.green;
    case 'freelance':
      return Colors.teal;
    default:
      return Colors.grey;
  }
}

IconData getCategoryIcon(String category) {
  switch (category.toLowerCase()) {
    case 'food':
      return Icons.restaurant;
    case 'transportation':
      return Icons.directions_car;
    case 'entertainment':
      return Icons.movie;
    case 'shopping':
      return Icons.shopping_bag;
    case 'utilities':
      return Icons.lightbulb;
    case 'salary':
      return Icons.work;
    case 'freelance':
      return Icons.computer;
    default:
      return Icons.category;
  }
}

Color getTransactionTypeColor(TransactionType type) {
  switch (type) {
    case TransactionType.income:
      return Colors.green;
    case TransactionType.expense:
      return Colors.red;
  }
}
