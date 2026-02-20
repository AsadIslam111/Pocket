import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pocket_app/providers/transaction_provider.dart';
import 'package:pocket_app/providers/budget_provider.dart';
import 'package:pocket_app/models/transaction.dart';
import 'package:intl/intl.dart';

class AddTransactionScreen extends StatefulWidget {
  final Transaction? transaction;

  const AddTransactionScreen({super.key, this.transaction});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  TransactionType _selectedType = TransactionType.expense;
  String _selectedCategory = 'Food';
  DateTime _selectedDate = DateTime.now();

  // Expense categories
  final List<String> _expenseCategories = [
    'Food',
    'Transportation',
    'Entertainment',
    'Shopping',
    'Utilities',
    'Rent',
    'Healthcare',
    'Education',
    'Clothing',
    'Personal Care',
    'Phone & Internet',
    'Subscriptions',
    'Travel',
    'Gifts',
    'Other',
  ];

  // Income categories
  final List<String> _incomeCategories = [
    'Salary',
    'Freelance',
    'Business',
    'Investment',
    'Rental Income',
    'Interest',
    'Dividends',
    'Commission',
    'Bonus',
    'Refund',
    'Gift Received',
    'Other',
  ];

  List<String> get _currentCategories =>
      _selectedType == TransactionType.expense
          ? _expenseCategories
          : _incomeCategories;

  

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      _titleController.text = widget.transaction!.title;
      _amountController.text = widget.transaction!.amount.toString();
      _notesController.text = widget.transaction!.notes ?? '';
      _selectedType = widget.transaction!.type;
      _selectedCategory = widget.transaction!.category;
      _selectedDate = widget.transaction!.date;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onTypeChanged(TransactionType type) {
    setState(() {
      _selectedType = type;
      // Reset category to first item of the new type's list
      if (!_currentCategories.contains(_selectedCategory)) {
        _selectedCategory = _currentCategories.first;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.transaction != null ? 'Edit Transaction' : 'Add Transaction'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Transaction Type
              Text(
                'Transaction Type',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _buildTypeSelector(),
              const SizedBox(height: 24),

              // Amount — numbers only
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '৳ ',
                  prefixIcon: Icon(Icons.calculate),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  if (double.parse(value) <= 0) {
                    return 'Amount must be greater than 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Category — changes based on type
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category),
                ),
                items: _currentCategories.map((String category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedCategory = newValue;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              

              // Date
              InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    DateFormat('MMM dd, yyyy').format(_selectedDate),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Notes
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  prefixIcon: Icon(Icons.note),
                ),
              ),
              const SizedBox(height: 32),

              // Save Button — M3 FilledButton
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _saveTransaction,
                  child: Text(
                    widget.transaction != null ? 'Update Transaction' : 'Save Transaction',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return SegmentedButton<TransactionType>(
      segments: TransactionType.values.map((type) {
        return ButtonSegment<TransactionType>(
          value: type,
          icon: Icon(_getTypeIcon(type)),
          label: Text(type.name.toUpperCase()),
        );
      }).toList(),
      selected: {_selectedType},
      onSelectionChanged: (Set<TransactionType> selection) {
        _onTypeChanged(selection.first);
      },
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: _getTypeColor(_selectedType).withOpacity(0.15),
        selectedForegroundColor: _getTypeColor(_selectedType),
      ),
    );
  }

  Color _getTypeColor(TransactionType type) {
    switch (type) {
      case TransactionType.income:
        return Colors.green;
      case TransactionType.expense:
        return Colors.red;
    }
  }

  IconData _getTypeIcon(TransactionType type) {
    switch (type) {
      case TransactionType.income:
        return Icons.trending_up;
      case TransactionType.expense:
        return Icons.trending_down;
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveTransaction() async {
    if (_formKey.currentState!.validate()) {
      final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);
      final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
      
      final transaction = Transaction(
        id: widget.transaction?.id,
        amount: double.parse(_amountController.text),
        type: _selectedType,
        title: _titleController.text,
        category: _selectedCategory,
        account: widget.transaction?.account ?? 'Cash',
        date: _selectedDate,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      try {
        if (widget.transaction != null) {
          // Adjust previous budget spending if editing
          final previous = widget.transaction!;
          if (previous.type == TransactionType.expense) {
            await budgetProvider.updateBudgetSpending(previous.category, -previous.amount);
          }
          await transactionProvider.updateTransaction(transaction);
          if (transaction.type == TransactionType.expense) {
            await budgetProvider.updateBudgetSpending(transaction.category, transaction.amount);
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Transaction updated successfully')),
            );
          }
        } else {
          await transactionProvider.addTransaction(transaction);
          if (transaction.type == TransactionType.expense) {
            await budgetProvider.updateBudgetSpending(transaction.category, transaction.amount);
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Transaction added successfully')),
            );
          }
        }

        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}')),
          );
        }
      }
    }
  }
}
