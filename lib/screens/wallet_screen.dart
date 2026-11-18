import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/razorpay_checkout.dart';
import '../../utils/app_colors.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  double _balance = 0;
  List<dynamic> _transactions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final dash = await ApiService.getDashboard();
    final txns = await ApiService.getWalletTransactions();
    setState(() {
      _loading = false;
      if (dash['success'] == true) {
        _balance = (dash['dashboard']?['wallet'] ?? 0).toDouble();
      }
      if (txns['success'] == true) {
        _transactions = txns['transactions'] ?? [];
      }
    });
  }

  Future<void> _addMoney() async {
    final controller = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Money'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Amount (₹1 - ₹10,000)',
            prefixText: '₹ ',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final v = double.tryParse(controller.text);
              Navigator.pop(ctx, v);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (amount == null) return;
    if (amount <= 0 || amount > 10000) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Amount must be between ₹1 and ₹10,000'),
          backgroundColor: AppColors.error,
        ));
      }
      return;
    }

    // Pay via Razorpay: create order -> checkout -> verify -> wallet credited
    final user = Provider.of<AuthProvider>(context, listen: false).user ?? {};
    final result = await RazorpayCheckout.rechargeWallet(
      amount: amount,
      customerName: user['name']?.toString() ?? 'Customer',
      customerEmail: user['email']?.toString() ?? 'customer@rydo.com',
      customerPhone: user['phone']?.toString() ?? '',
    );
    if (!mounted) return;
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Wallet recharged via Razorpay!'),
        backgroundColor: AppColors.success,
      ));
      _fetch();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['message'] ?? 'Payment failed'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('My Wallet')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetch,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Wallet Balance',
                            style: TextStyle(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 6),
                        Text('₹${_balance.toStringAsFixed(0)}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _addMoney,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.primary,
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Money'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Transactions',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  if (_transactions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('No transactions yet', style: TextStyle(color: Colors.grey))),
                    )
                  else
                    ..._transactions.map((t) {
                      final isCredit = t['type'] == 'credit';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: (isCredit ? AppColors.success : AppColors.error).withOpacity(0.1),
                            child: Icon(
                              isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                              color: isCredit ? AppColors.success : AppColors.error,
                            ),
                          ),
                          title: Text(t['description'] ?? 'Transaction'),
                          subtitle: Text(t['createdAt'] != null
                              ? DateTime.tryParse(t['createdAt'])?.toLocal().toString().split('.')[0] ?? ''
                              : ''),
                          trailing: Text(
                            '${isCredit ? '+' : '-'}₹${t['amount'] ?? 0}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isCredit ? AppColors.success : AppColors.error,
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
