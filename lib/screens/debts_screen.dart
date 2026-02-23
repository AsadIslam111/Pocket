import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pocket_app/providers/debt_provider.dart';
import 'package:pocket_app/providers/auth_provider.dart';
import 'package:pocket_app/models/debt.dart';
import 'package:intl/intl.dart';

class DebtsScreen extends StatelessWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<DebtProvider, AuthProvider>(
      builder: (context, debtProvider, authProvider, child) {
        if (debtProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (debtProvider.errorMessage != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: SelectableText(
                'Could not load debts:\n\n${debtProvider.errorMessage}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        final debts = debtProvider.debts;

        if (debts.isEmpty) {
          return _buildEmptyState(context);
        }

        double totalLent = 0;
        double totalBorrowed = 0;

        for (var debt in debts) {
          if (debt.status == DebtStatus.active || debt.status == DebtStatus.manual) {
            bool isMeLending = debt.creatorId == authProvider.userId && debt.type == DebtType.lent ||
                               debt.peerId == authProvider.userId && debt.type == DebtType.borrowed;

            if (isMeLending) {
              totalLent += debt.amount;
            } else {
              totalBorrowed += debt.amount;
            }
          }
        }

        return Column(
          children: [
            // Summary Cards
            Container(
              padding: const EdgeInsets.all(16.0),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        context,
                        'I Lent',
                        totalLent,
                        Icons.arrow_upward,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        context,
                        'I Borrowed',
                        totalBorrowed,
                        Icons.arrow_downward,
                        Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Debts List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemCount: debts.length,
                itemBuilder: (context, index) {
                  final debt = debts[index];
                  return _buildDebtCard(context, debt, authProvider.userId ?? '', debtProvider);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String title,
    double amount,
    IconData icon,
    Color color,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.surfaceContainerHighest,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
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
              ),
            ),
          ],
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
            Icons.handshake_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No debts tracked',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Keep track of who owes you, and who you owe.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDebtCard(BuildContext context, Debt debt, String myUserId, DebtProvider provider) {
    bool amICreator = debt.creatorId == myUserId;
    
    // Determine the direction
    // If I created it, and type is lent = I lent them.
    // If I didn't create it, and type is borrowed = I lent them.
    bool amILender = (amICreator && debt.type == DebtType.lent) || 
                     (!amICreator && debt.type == DebtType.borrowed);

    String nameToShow = amICreator ? debt.peerName : 'Someone'; // If we have a robust user system, we'd fetch the creator's name here
    String description = amILender ? 'You lent $nameToShow' : 'You borrowed from $nameToShow';
    Color amountColor = amILender ? Colors.green : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: amountColor.withOpacity(0.1),
                  child: Icon(
                    amILender ? Icons.arrow_outward : Icons.call_received,
                    color: amountColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        description,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _getStatusText(debt),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _getStatusColor(debt),
                          fontWeight: FontWeight.w500
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  NumberFormat.currency(symbol: '৳').format(debt.amount),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: amountColor,
                  ),
                ),
              ],
            ),
            
            // Pending Actions
            if (debt.status == DebtStatus.pending_invite || debt.status == DebtStatus.pending_approval) ...[
               const SizedBox(height: 12),
               const Divider(),
               if (amICreator) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => provider.cancelDebtRequest(debt.id),
                        child: const Text('Cancel Request', style: TextStyle(color: Colors.red)),
                      ),
                      TextButton(
                        onPressed: () => provider.convertToManualDebt(debt.id),
                        child: const Text('Convert to Manual'),
                      )
                    ],
                  )
               ] else ...[
                 Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => provider.rejectDebtRequest(debt.id),
                        child: const Text('Decline', style: TextStyle(color: Colors.red)),
                      ),
                      FilledButton.tonal(
                        onPressed: () {
                           final authProvider = Provider.of<AuthProvider>(context, listen: false);
                           provider.acceptDebtRequest(debt, authProvider.userId!, authProvider.userName ?? authProvider.userEmail!);
                        },
                        child: const Text('Accept'),
                      )
                    ],
                  )
               ]
            ],

            // Settle action for active/manual
            if (debt.status == DebtStatus.active || debt.status == DebtStatus.manual) ...[
                const SizedBox(height: 12),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => provider.markAsSettled(debt.id),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Mark as Settled'),
                      style: TextButton.styleFrom(foregroundColor: Colors.green),
                    ),
                  ],
                )
            ]
          ],
        ),
      ),
    );
  }

  String _getStatusText(Debt debt) {
    if (debt.status == DebtStatus.manual) return 'Manual Tracker';
    if (debt.status == DebtStatus.active) return 'Active P2P';
    if (debt.status == DebtStatus.pending_invite) return 'Pending Invite (expires in 24h)';
    if (debt.status == DebtStatus.pending_approval) return 'Pending Approval';
    if (debt.status == DebtStatus.rejected) return 'Rejected by peer';
    if (debt.status == DebtStatus.settled) return 'Settled';
    return '';
  }

  Color _getStatusColor(Debt debt) {
    if (debt.status == DebtStatus.manual) return Colors.grey;
    if (debt.status == DebtStatus.active) return Colors.blue;
    if (debt.status.name.startsWith('pending')) return Colors.orange;
    if (debt.status == DebtStatus.rejected) return Colors.red;
    if (debt.status == DebtStatus.settled) return Colors.green;
    return Colors.black;
  }
}
