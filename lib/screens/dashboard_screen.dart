import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pocket_app/providers/transaction_provider.dart';
import 'package:pocket_app/models/transaction.dart';
import 'package:pocket_app/screens/add_transaction_screen.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pocket'),
      ),
      body: Consumer<TransactionProvider>(
        builder: (context, transactionProvider, child) {
          final totalBalance = transactionProvider.getTotalBalance();
          final totalIncome = transactionProvider.getTotalIncome();
          final totalExpenses = transactionProvider.getTotalExpenses();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Total Balance Card — light blue accent
                SizedBox(
                  width: double.infinity,
                  child: Card(
                    color: const Color(0xFFE3F2FD), // very light blue accent
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Balance',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: const Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              NumberFormat.currency(symbol: '৳').format(totalBalance),
                              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                color: const Color(0xFF1A1A1A),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Income and Expenses Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        context,
                        'Income',
                        totalIncome,
                        Icons.trending_up,
                        Colors.green,
                        const Color(0xFFDCFCE7), // very light green accent
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildSummaryCard(
                        context,
                        'Expenses',
                        totalExpenses,
                        Icons.trending_down,
                        Colors.red,
                        const Color(0xFFFEE2E2), // very light red accent
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Action Button — M3 FilledButton.tonal
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AddTransactionScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Transaction'),
                  ),
                ),

                const SizedBox(height: 32),

                // Recent Transactions
                Text(
                  'Recent Transactions',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildRecentTransactions(context, transactionProvider),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String title,
    double amount,
    IconData icon,
    Color color,
    Color backgroundColor,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: backgroundColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF1A1A1A),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                NumberFormat.currency(symbol: '৳').format(amount),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactions(
    BuildContext context,
    TransactionProvider transactionProvider,
  ) {
    final recentTransactions = transactionProvider.transactions
        .take(5)
        .toList();

    if (recentTransactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.receipt_long,
                size: 64,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'No transactions yet',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: recentTransactions.map((transaction) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getCategoryColor(transaction.category).withOpacity(0.1),
              child: Icon(
                _getCategoryIcon(transaction.category),
                color: _getCategoryColor(transaction.category),
              ),
            ),
            title: Text(
              transaction.title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${transaction.category} • ${DateFormat('MMM dd').format(transaction.date)}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            trailing: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                '${transaction.type == TransactionType.income ? '+' : '-'}${NumberFormat.currency(symbol: '৳').format(transaction.amount)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: transaction.type == TransactionType.income
                      ? Colors.green
                      : Colors.red,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                textAlign: TextAlign.end,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _getCategoryColor(String category) {
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

  IconData _getCategoryIcon(String category) {
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

  
}
