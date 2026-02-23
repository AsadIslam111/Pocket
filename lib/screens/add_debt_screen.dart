import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pocket_app/providers/debt_provider.dart';
import 'package:pocket_app/providers/auth_provider.dart';
import 'package:pocket_app/models/debt.dart';

class AddDebtScreen extends StatefulWidget {
  const AddDebtScreen({super.key});

  @override
  State<AddDebtScreen> createState() => _AddDebtScreenState();
}

class _AddDebtScreenState extends State<AddDebtScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Add Debt/Loan'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'By Email (P2P)'),
              Tab(text: 'Manual Note'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _EmailDebtForm(),
            _ManualDebtForm(),
          ],
        ),
      ),
    );
  }
}

class _EmailDebtForm extends StatefulWidget {
  const _EmailDebtForm();

  @override
  State<_EmailDebtForm> createState() => _EmailDebtFormState();
}

class _EmailDebtFormState extends State<_EmailDebtForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _amountController = TextEditingController();
  DebtType _selectedType = DebtType.lent;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Send a request to another Pocket user. If they don\'t have the app, we will email them an invite.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            
            // Type Selector
            SegmentedButton<DebtType>(
              segments: const [
                ButtonSegment(
                  value: DebtType.lent,
                  label: Text('I Lent Money'),
                  icon: Icon(Icons.arrow_upward),
                ),
                ButtonSegment(
                  value: DebtType.borrowed,
                  label: Text('I Borrowed Money'),
                  icon: Icon(Icons.arrow_downward),
                ),
              ],
              selected: {_selectedType},
              onSelectionChanged: (Set<DebtType> newSelection) {
                setState(() {
                  _selectedType = newSelection.first;
                });
              },
            ),
            const SizedBox(height: 24),

            // Email Input
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Friend\'s Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Please enter an email';
                if (!value.contains('@')) return 'Please enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Amount Input
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '৳ ',
                prefixIcon: Icon(Icons.attach_money),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Please enter an amount';
                if (double.tryParse(value) == null) return 'Please enter a valid number';
                if (double.parse(value) <= 0) return 'Amount must be greater than 0';
                return null;
              },
            ),
            const SizedBox(height: 32),

            // Submit Button
            FilledButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Send Request'),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final debtProvider = Provider.of<DebtProvider>(context, listen: false);

        if (authProvider.userId == null) throw Exception("Not logged in");
        if (_emailController.text.trim().toLowerCase() == authProvider.userEmail?.toLowerCase()) {
           throw Exception("You cannot lend money to yourself.");
        }

        await debtProvider.createP2PDebtRequest(
          creatorId: authProvider.userId!,
          peerEmail: _emailController.text.trim().toLowerCase(),
          amount: double.parse(_amountController.text),
          type: _selectedType,
        );

        if (mounted) {
           Navigator.pop(context);
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Request sent successfully!')),
           );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Error: ${e.toString().replaceAll('Exception:', '').trim()}'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }
}

class _ManualDebtForm extends StatefulWidget {
  const _ManualDebtForm();

  @override
  State<_ManualDebtForm> createState() => _ManualDebtFormState();
}

class _ManualDebtFormState extends State<_ManualDebtForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  DebtType _selectedType = DebtType.lent;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Create a private note to track a debt. The other person will not be notified.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            
            // Type Selector
            SegmentedButton<DebtType>(
              segments: const [
                ButtonSegment(
                  value: DebtType.lent,
                  label: Text('I Lent Money'),
                  icon: Icon(Icons.arrow_upward),
                ),
                ButtonSegment(
                  value: DebtType.borrowed,
                  label: Text('I Borrowed Money'),
                  icon: Icon(Icons.arrow_downward),
                ),
              ],
              selected: {_selectedType},
              onSelectionChanged: (Set<DebtType> newSelection) {
                setState(() {
                  _selectedType = newSelection.first;
                });
              },
            ),
            const SizedBox(height: 24),

            // Name Input
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Person\'s Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Please enter a name';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Amount Input
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '৳ ',
                prefixIcon: Icon(Icons.attach_money),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Please enter an amount';
                if (double.tryParse(value) == null) return 'Please enter a valid number';
                if (double.parse(value) <= 0) return 'Amount must be greater than 0';
                return null;
              },
            ),
            const SizedBox(height: 32),

            // Submit Button
            FilledButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Note'),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final debtProvider = Provider.of<DebtProvider>(context, listen: false);

        if (authProvider.userId == null) throw Exception("Not logged in");

        await debtProvider.createManualDebt(
          creatorId: authProvider.userId!,
          peerName: _nameController.text.trim(),
          amount: double.parse(_amountController.text),
          type: _selectedType,
        );

        if (mounted) {
           Navigator.pop(context);
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Debt note saved successfully!')),
           );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('An error occurred. Please try again.'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }
}
