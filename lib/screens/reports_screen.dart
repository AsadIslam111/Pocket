import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pocket_app/providers/transaction_provider.dart';
import 'package:pocket_app/models/transaction.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  String _selectedTimeRange = 'Monthly';
  final List<String> _timeRanges = ['Weekly', 'Monthly', 'Yearly'];

  late AnimationController _animController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _selectedTimeRange = value;
              });
              // Replay animation when time range changes
              _animController.reset();
              _animController.forward();
            },
            itemBuilder: (context) => _timeRanges.map((range) {
              return PopupMenuItem(
                value: range,
                child: Text(range),
              );
            }).toList(),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_selectedTimeRange),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Consumer<TransactionProvider>(
        builder: (context, transactionProvider, child) {
          final transactions = transactionProvider.transactions;

          if (transactions.isEmpty) {
            return _buildEmptyState(context);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary first
                _buildSummarySection(context, transactionProvider),
                const SizedBox(height: 24),

                // Pie chart with animation
                _buildPieChartSection(context, transactions),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── Summary Section ───────────────────────────────────────────────

  Widget _buildSummarySection(
      BuildContext context, TransactionProvider transactionProvider) {
    final totalIncome = transactionProvider.getTotalIncome();
    final totalExpenses = transactionProvider.getTotalExpenses();
    final totalBalance = transactionProvider.getTotalBalance();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Summary',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildSummaryItem(
                      context,
                      'Income',
                      totalIncome,
                      Icons.trending_up,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryItem(
                      context,
                      'Expenses',
                      totalExpenses,
                      Icons.trending_down,
                      Colors.red,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: totalBalance >= 0
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: totalBalance >= 0
                      ? Colors.green.withOpacity(0.3)
                      : Colors.red.withOpacity(0.3),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Net Balance',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      NumberFormat.currency(symbol: '৳').format(totalBalance),
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: totalBalance >= 0
                                    ? Colors.green
                                    : Colors.red,
                              ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    BuildContext context,
    String title,
    double amount,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              NumberFormat.currency(symbol: '৳').format(amount),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Animated Pie Chart Section ────────────────────────────────────

  Widget _buildPieChartSection(BuildContext context, List transactions) {
    final expenseTransactions =
        transactions.where((t) => t.type == TransactionType.expense).toList();

    if (expenseTransactions.isEmpty) {
      return _buildNoDataCard(context, 'No expense data available');
    }

    // Group by category
    final Map<String, double> categoryTotals = {};
    for (var t in expenseTransactions) {
      categoryTotals[t.category] =
          (categoryTotals[t.category] ?? 0) + t.amount;
    }

    // Sort by value descending for a nicer chart
    final sortedEntries = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final pieChartData = sortedEntries.map((entry) {
          return PieChartSectionData(
            value: entry.value,
            title: _animation.value > 0.5
                ? '${(entry.value / sortedEntries.fold<double>(0, (s, e) => s + e.value) * 100).toStringAsFixed(0)}%'
                : '',
            color: _getCategoryColor(entry.key),
            radius: 60 * _animation.value, // grows from 0 → 60
            titleStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white.withOpacity(_animation.value),
            ),
            titlePositionPercentageOffset: 0.55,
          );
        }).toList();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Spending Breakdown',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 220,
                  child: PieChart(
                    PieChartData(
                      sections: pieChartData,
                      centerSpaceRadius: 40 * _animation.value,
                      sectionsSpace: 2,
                      startDegreeOffset: -90,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildLegend(sortedEntries),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLegend(List<MapEntry<String, double>> entries) {
    final total = entries.fold<double>(0, (s, e) => s + e.value);
    return Column(
      children: entries.map((entry) {
        final pct = total > 0 ? (entry.value / total * 100) : 0.0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: _getCategoryColor(entry.key),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.key,
                  style: Theme.of(context).textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${pct.toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                    ),
              ),
              const SizedBox(width: 8),
              Text(
                NumberFormat.currency(symbol: '৳').format(entry.value),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ─── Empty / No-Data States ────────────────────────────────────────

  Widget _buildNoDataCard(BuildContext context, String message) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.pie_chart_outline,
                size: 64,
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.5),
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.pie_chart_outline,
            size: 80,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No data available',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add some transactions to see your reports',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─── Category Colors ───────────────────────────────────────────────

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      // Expense categories
      case 'food':
        return Colors.orange;
      case 'transportation':
        return Colors.blue;
      case 'entertainment':
        return Colors.purple;
      case 'shopping':
        return Colors.pink;
      case 'utilities':
        return Colors.teal;
      case 'rent':
        return Colors.indigo;
      case 'healthcare':
        return Colors.red;
      case 'education':
        return Colors.cyan;
      case 'clothing':
        return Colors.deepPurple;
      case 'personal care':
        return Colors.amber;
      case 'phone & internet':
        return Colors.lightBlue;
      case 'subscriptions':
        return Colors.deepOrange;
      case 'travel':
        return Colors.lime;
      case 'gifts':
        return Colors.pinkAccent;
      // Income categories
      case 'salary':
        return Colors.green;
      case 'freelance':
        return Colors.tealAccent;
      case 'business':
        return Colors.blueGrey;
      case 'investment':
        return Colors.lightGreen;
      case 'rental income':
        return Colors.brown;
      case 'interest':
        return Colors.greenAccent;
      case 'dividends':
        return Colors.limeAccent;
      case 'commission':
        return Colors.orangeAccent;
      case 'bonus':
        return Colors.yellowAccent;
      case 'refund':
        return Colors.cyanAccent;
      case 'gift received':
        return Colors.purpleAccent;
      default:
        return Colors.grey;
    }
  }
}
