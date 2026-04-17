import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../utils/colors.dart';
import '../services/wallet_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _walletService = WalletService();
  double _balance = 0.0;
  bool _isLoading = true;

  final List<Map<String, dynamic>> _transactions = [
    {'icon': Icons.arrow_downward, 'name': 'Dari Sari Rahayu',  'date': 'Hari ini, 09:15',  'amount': '+Rp 75.000',  'isIncome': true},
    {'icon': Icons.arrow_upward,   'name': 'Ke Budi Santoso',   'date': 'Hari ini, 10:30',  'amount': '-Rp 50.000',  'isIncome': false},
    {'icon': Icons.add_circle_outline, 'name': 'Top Up GoPay',  'date': 'Kemarin, 14:20',   'amount': '+Rp 200.000', 'isIncome': true},
    {'icon': Icons.arrow_upward,   'name': 'Ke Dewi Kusuma',    'date': 'Kemarin, 09:00',   'amount': '-Rp 25.000',  'isIncome': false},
    {'icon': Icons.arrow_downward, 'name': 'Dari Roni Prakoso', 'date': 'Senin, 16:45',     'amount': '+Rp 100.000', 'isIncome': true},
  ];

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    setState(() => _isLoading = true);
    final balance = await _walletService.getBalance();
    if (mounted) {
      setState(() {
        _balance = balance;
        _isLoading = false;
      });
    }
  }

  void _showTopUpSheet() {
    final amountCtrl = TextEditingController();
    bool isLoadingTopup = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24, right: 24, top: 24,
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: RupiaColors.textHint,
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                const Text('Top Up Saldo',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: RupiaColors.textPrimary)),
                const SizedBox(height: 20),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Jumlah Top Up (Min. Rp 10.000)',
                    prefixText: 'Rp ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: RupiaColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isLoadingTopup ? null : () async {
                      final amount = double.tryParse(amountCtrl.text.replaceAll('.', ''));
                      if (amount == null || amount < 10000) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Minimal Top Up adalah Rp 10.000')));
                        return;
                      }

                      setModalState(() => isLoadingTopup = true);
                      
                      final url = await _walletService.generateTopUpToken(amount);
                      
                      if (!context.mounted) return;
                      Navigator.pop(context); // Close sheet
                      
                      if (url != null) {
                        final uri = Uri.parse(url);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                          _loadBalance(); // Refresh balance optionally
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Tidak dapat membuka simulator')));
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Gagal membuat transaksi')));
                      }
                    },
                    child: isLoadingTopup
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Lanjutkan Pembayaran', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 16),
              ]),
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      backgroundColor: isDarkMode ? RupiaColors.bgDark : RupiaColors.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFF0D2B6B), RupiaColors.primary],
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text('Dompet Saya',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20)),
            actions: [
              IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _loadBalance),
              IconButton(icon: const Icon(Icons.notifications_outlined, color: Colors.white), onPressed: () {}),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadBalance,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // ── Kartu Saldo ──────────────────────────────────
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [RupiaColors.primary, Color(0xFF2557B3)],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF1A3C8F), Color(0xFF0D2060)]),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Saldo RupiaChat',
                              style: TextStyle(color: Colors.white70, fontSize: 13)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20)),
                            child: const Text('**** 8821',
                                style: TextStyle(color: Colors.white, fontSize: 11)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _isLoading 
                        ? const SizedBox(height: 38, width: 38, child: CircularProgressIndicator(color: Colors.white))
                        : Text(currencyFormatter.format(_balance),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -1)),
                      const SizedBox(height: 4),
                      Text('≈ \$${(_balance / 15000).toStringAsFixed(2)} USD',
                          style: const TextStyle(color: RupiaColors.gold, fontSize: 12)),
                    ],
                  ),
                ),
              ),

              // ── Tombol Aksi ──────────────────────────────────
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Color(0xFF2557B3), Color(0xFF2557B3)],
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                      color: isDarkMode ? RupiaColors.bgDark : RupiaColors.bg,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                  child: GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _ActionButton(icon: Icons.arrow_upward,   label: 'Kirim',   color: RupiaColors.primary, onTap: () {}),
                      _ActionButton(icon: Icons.arrow_downward, label: 'Terima',  color: RupiaColors.success, onTap: () {}),
                      _ActionButton(icon: Icons.add,            label: 'Top Up',  color: RupiaColors.gold, onTap: _showTopUpSheet),
                      _ActionButton(icon: Icons.history,        label: 'Riwayat', color: const Color(0xFF6B7280), onTap: () {}),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // ── Kartu Statistik ──────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  Expanded(child: _StatCard(label: 'Pemasukan',   amount: 'Rp 375.000', color: RupiaColors.success)),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(label: 'Pengeluaran', amount: 'Rp 75.000',  color: RupiaColors.danger)),
                ]),
              ),

              const SizedBox(height: 20),

              // ── Daftar Transaksi ─────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Transaksi Terbaru',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, 
                              fontSize: 16, 
                              color: isDarkMode ? Colors.white : RupiaColors.textPrimary)),
                      TextButton(
                        onPressed: () {},
                        child: const Text('Lihat Semua',
                            style: TextStyle(color: RupiaColors.primary, fontSize: 13)),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                          color: isDarkMode ? RupiaColors.cardDark : Colors.white, 
                          borderRadius: BorderRadius.circular(16)),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _transactions.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, indent: 60, color: isDarkMode ? Colors.white10 : null),
                        itemBuilder: (context, index) =>
                            _TransactionTile(tx: _transactions[index]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      )
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector( // Modified to respond to taps
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: isDarkMode ? Colors.white54 : RupiaColors.textSecondary,
                fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, amount;
  final Color color;
  const _StatCard({required this.label, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: isDarkMode ? RupiaColors.cardDark : Colors.white, 
          borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white54 : RupiaColors.textSecondary)),
        const SizedBox(height: 4),
        Text(amount, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final Map<String, dynamic> tx;
  const _TransactionTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final isIncome = tx['isIncome'] as bool;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: (isIncome ? RupiaColors.success : RupiaColors.danger).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(tx['icon'],
            color: isIncome ? RupiaColors.success : RupiaColors.danger, size: 20),
      ),
      title: Text(tx['name'],
          style: TextStyle(
              fontSize: 14, 
              fontWeight: FontWeight.w500, 
              color: isDarkMode ? Colors.white : RupiaColors.textPrimary)),
      subtitle: Text(tx['date'],
          style: TextStyle(fontSize: 11, color: isDarkMode ? Colors.white38 : RupiaColors.textSecondary)),
      trailing: Text(tx['amount'],
          style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: isIncome ? RupiaColors.success : RupiaColors.danger)),
    );
  }
}
