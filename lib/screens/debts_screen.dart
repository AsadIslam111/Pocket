import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pocket_app/providers/debt_provider.dart';
import 'package:pocket_app/providers/auth_provider.dart';
import 'package:pocket_app/models/debt.dart';
import 'package:intl/intl.dart';
import 'package:pocket_app/screens/add_debt_screen.dart';

class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debts & Loans'),
      ),
      body: Consumer2<DebtProvider, AuthProvider>(
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
          
          final allDebts = debtProvider.debts;
          
          if (allDebts.isEmpty) {
            return const Center(
              child: Text(
                'No debts found',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }
          
          double totalLent = 0.0;
          double totalBorrowed = 0.0;
          
          for (var debt in allDebts) {
            if (debt.status == DebtStatus.active || debt.status == DebtStatus.manual) {
              bool isMeLending = (debt.creatorId == authProvider.userId && debt.type == DebtType.lent) ||
                                 (debt.peerId == authProvider.userId && debt.type == DebtType.borrowed);
              if (isMeLending) {
                totalLent += debt.remainingAmount;
              } else {
                totalBorrowed += debt.remainingAmount;
              }
            }
          }
          
          final netBalance = totalLent - totalBorrowed;

          // Filter debts
          List<Debt> displayDebts = allDebts.where((debt) {
            if (_filter == 'All') return true;
            if (_filter == 'Active') return debt.status == DebtStatus.active || debt.status == DebtStatus.manual || debt.status == DebtStatus.settlement_requested;
            if (_filter == 'Pending') return debt.status.name.startsWith('pending');
            if (_filter == 'Settled') return debt.status == DebtStatus.settled;
            return true;
          }).toList();

          return Column(
            children: [
              // Summary Cards
              Container(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Net Balance Card
                    Card(
                      color: netBalance >= 0 ? Colors.green.shade50 : Colors.red.shade50,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Net Balance', style: Theme.of(context).textTheme.titleMedium),
                            Text(
                              NumberFormat.currency(symbol: '৳').format(netBalance.abs()),
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: netBalance >= 0 ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    IntrinsicHeight(
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
                  ],
                ),
              ),
              
              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: ['All', 'Active', 'Pending', 'Settled'].map((filter) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(filter),
                        selected: _filter == filter,
                        onSelected: (selected) {
                          if (selected) setState(() => _filter = filter);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),

              // Debts List
              Expanded(
                child: displayDebts.isEmpty
                    ? Center(child: Text('No ${(_filter == 'All' ? '' : _filter.toLowerCase() + ' ')}debts found', style: const TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        itemCount: displayDebts.length,
                        itemBuilder: (context, index) {
                          final debt = displayDebts[index];
                          Widget card = _buildDebtCard(context, debt, authProvider.userId ?? '', debtProvider);
                          
                          bool showHeader = false;
                          String headerTitle = '';
                          if (index == 0) {
                            showHeader = true;
                            headerTitle = _getGroupTitle(debt.status);
                          } else {
                            final prevDebt = displayDebts[index - 1];
                            if (_getGroupTitle(debt.status) != _getGroupTitle(prevDebt.status)) {
                              showHeader = true;
                              headerTitle = _getGroupTitle(debt.status);
                            }
                          }

                          if (showHeader) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                                  child: Text(
                                    headerTitle,
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                card,
                              ],
                            );
                          }
                          return card;
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'debts_fab',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddDebtScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  String _getGroupTitle(DebtStatus status) {
    if (status.name.startsWith('pending')) return 'Pending Requests';
    if (status == DebtStatus.active || status == DebtStatus.manual || status == DebtStatus.settlement_requested) return 'Active Debts';
    if (status == DebtStatus.settled) return 'Settled';
    if (status == DebtStatus.rejected) return 'Rejected';
    return 'Other';
  }

  Widget _buildSummaryCard(BuildContext context, String title, double amount, IconData icon, Color color) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.surfaceContainerHighest,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
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
          Icon(Icons.handshake_outlined, size: 80, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
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
    bool amILender = (amICreator && debt.type == DebtType.lent) || 
                     (!amICreator && debt.type == DebtType.borrowed);

    String nameToShow;
    if (amICreator) {
      nameToShow = debt.peerName;
    } else {
      if (debt.creatorName != null && debt.creatorName!.isNotEmpty) {
        nameToShow = debt.creatorName!;
      } else if (debt.creatorEmail != null && debt.creatorEmail!.isNotEmpty) {
        nameToShow = debt.creatorEmail!.split('@').first;
      } else {
        nameToShow = 'Someone';
      }
    }

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
                  child: Icon(amILender ? Icons.arrow_outward : Icons.call_received, color: amountColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(description, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      if (debt.description != null && debt.description!.isNotEmpty)
                        Text(debt.description!, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                      const SizedBox(height: 4),
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      NumberFormat.currency(symbol: '৳').format(debt.amount),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: amountColor,
                        decoration: debt.status == DebtStatus.settled ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (debt.amountPaid != null && debt.amountPaid! > 0 && debt.status != DebtStatus.settled)
                      Text(
                        'Rem: ৳${debt.remainingAmount.toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
                if (debt.status == DebtStatus.manual || debt.status == DebtStatus.rejected)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (val) {
                      if (val == 'delete') {
                         _confirmAction(context, 'Delete', 'Are you sure you want to delete this record?', () => provider.deleteDebt(debt.id));
                      } else if (val == 'edit') {
                         _showEditDialog(context, debt, provider);
                      }
                    },
                    itemBuilder: (context) => [
                      if (debt.status == DebtStatus.manual)
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                    ],
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
                        onPressed: () => _confirmAction(context, 'Cancel Request', 'Are you sure you want to cancel this request?', () => provider.cancelDebtRequest(debt.id)),
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
                        onPressed: () => _confirmAction(context, 'Decline Request', 'Are you sure you want to decline this request?', () => provider.rejectDebtRequest(debt.id)),
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

            // Pending Actions (borrower requested)
            if (debt.status == DebtStatus.settlement_requested) ...[
                const SizedBox(height: 12),
                const Divider(),
                if (amILender) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Payment of ৳${debt.pendingPaymentAmount?.toStringAsFixed(0)} requested.\n'
                      'Date: ${debt.pendingPaymentDate != null ? DateFormat('MMM dd, yyyy - hh:mm a').format(debt.pendingPaymentDate!) : "Unknown"}\n'
                      'Note: ${debt.pendingPaymentNote != null && debt.pendingPaymentNote!.isNotEmpty ? debt.pendingPaymentNote : "None"}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => _confirmAction(context, 'Decline Payment', 'Are you sure you want to decline this payment request?', () => provider.declinePaymentRequest(debt.id)),
                        child: const Text('Decline', style: TextStyle(color: Colors.red)),
                      ),
                      FilledButton.tonal(
                        onPressed: () => provider.approvePaymentRequest(debt.id),
                        child: const Text('Approve'),
                      )
                    ],
                  )
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Waiting for lender to approve your payment of ৳${debt.pendingPaymentAmount?.toStringAsFixed(0)}.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                    ),
                  ),
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
                      onPressed: () => _showSettleDialog(context, debt, provider, amILender: amILender),
                      icon: const Icon(Icons.payments_outlined),
                      label: Text(amILender || debt.status == DebtStatus.manual ? 'Record Payment' : 'Request Payment'),
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
    if (debt.status == DebtStatus.settlement_requested) return 'Payment Requested';
    if (debt.status == DebtStatus.pending_invite || debt.status == DebtStatus.pending_approval) {
      if (debt.fallbackAt != null) {
        final diff = debt.fallbackAt!.difference(DateTime.now());
        if (diff.isNegative) return 'Expired';
        final hours = diff.inHours;
        final mins = diff.inMinutes.remainder(60);
        return 'Pending (expires in ${hours}h ${mins}m)';
      }
      return 'Pending';
    }
    if (debt.status == DebtStatus.rejected) return 'Rejected by peer';
    if (debt.status == DebtStatus.settled) return 'Settled';
    return '';
  }

  Color _getStatusColor(Debt debt) {
    if (debt.status == DebtStatus.manual) return Colors.grey;
    if (debt.status == DebtStatus.active) return Colors.blue;
    if (debt.status == DebtStatus.settlement_requested) return Colors.orange;
    if (debt.status.name.startsWith('pending')) return Colors.orange;
    if (debt.status == DebtStatus.rejected) return Colors.red;
    if (debt.status == DebtStatus.settled) return Colors.green;
    return Colors.black;
  }

  void _confirmAction(BuildContext context, String title, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('No')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  void _showSettleDialog(BuildContext context, Debt debt, DebtProvider provider, {required bool amILender}) {
    final TextEditingController amountController = TextEditingController(text: debt.remainingAmount.toStringAsFixed(0));
    final TextEditingController noteController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(amILender || debt.status == DebtStatus.manual ? 'Record Payment' : 'Request Payment'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Debt: ৳${debt.amount.toStringAsFixed(0)}'),
                  Text('Remaining: ৳${debt.remainingAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Payment Amount',
                      prefixText: '৳ ',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                             amountController.text = debt.remainingAmount.toStringAsFixed(0);
                          });
                        },
                        child: const Text('Full Amount'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: 'Note (Optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Date'),
                    subtitle: Text(DateFormat('MMM dd, yyyy').format(selectedDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() => selectedDate = picked);
                      }
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Time'),
                    subtitle: Text(selectedTime.format(context)),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (picked != null) {
                        setState(() => selectedTime = picked);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final val = double.tryParse(amountController.text);
                  if (val != null && val > 0 && val <= debt.remainingAmount) {
                    final combinedDate = DateTime(
                      selectedDate.year, selectedDate.month, selectedDate.day,
                      selectedTime.hour, selectedTime.minute,
                    );
                    if (amILender || debt.status == DebtStatus.manual) {
                      provider.addPayment(debt.id, val, note: noteController.text, date: combinedDate);
                    } else {
                      provider.requestPayment(debt.id, val, note: noteController.text, date: combinedDate);
                    }
                    Navigator.pop(context);
                  } else if (val != null && val > debt.remainingAmount) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot pay more than remaining amount')));
                  }
                },
                child: Text(amILender || debt.status == DebtStatus.manual ? 'Record' : 'Send Request'),
              ),
            ],
          );
        }
      ),
    );
  }

  void _showEditDialog(BuildContext context, Debt debt, DebtProvider provider) {
    final nameController = TextEditingController(text: debt.peerName);
    final amountController = TextEditingController(text: debt.amount.toString());
    DebtType selectedType = debt.type;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Edit Debt'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SegmentedButton<DebtType>(
                    segments: const [
                      ButtonSegment(value: DebtType.lent, label: Text('Lent')),
                      ButtonSegment(value: DebtType.borrowed, label: Text('Borrowed')),
                    ],
                    selected: {selectedType},
                    onSelectionChanged: (newSelection) {
                      setState(() => selectedType = newSelection.first);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Peer Name', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Amount', prefixText: '৳ ', border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  final val = double.tryParse(amountController.text);
                  if (val != null && val > 0 && nameController.text.isNotEmpty) {
                    provider.updateManualDebt(
                      debtId: debt.id,
                      peerName: nameController.text.trim(),
                      amount: val,
                      type: selectedType,
                    );
                    Navigator.pop(context);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        }
      ),
    );
  }
}
