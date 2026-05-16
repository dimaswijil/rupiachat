import 'package:flutter/material.dart';
import 'package:midtrans_sdk/midtrans_sdk.dart';
import 'package:intl/intl.dart';
import '../../utils/colors.dart';
import '../../services/wallet_service.dart';
import '../../services/midtrans_service.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _walletService = WalletService();
  final _midtransService = MidtransService();
  double _balance = 0.0;
  bool _isLoading = true;
  bool _midtransReady = false;

  @override
  void initState() {
    super.initState();
    _loadBalance();
    // JANGAN init Midtrans di sini!
    // MidtransSDK.init() memanggil native code yang bisa crash (ClassNotFoundException)
    // sebelum Dart try-catch sempat menangkap. Init hanya saat user butuh (lazy).
  }

  /// Lazy init Midtrans — hanya dipanggil saat user klik Top Up
  /// Menghindari crash native di initState
  Future<bool> _ensureMidtransReady() async {
    if (_midtransReady) return true;
    try {
      await _midtransService.initialize(
        onTransactionFinished: (TransactionResult result) {
          if (!mounted) return;
          String message;
          Color bgColor;
          if (result.isTransactionCanceled) {
            message = 'Transaksi dibatalkan';
            bgColor = RupiaColors.danger;
          } else {
            final status = result.transactionStatus;
            if (status == TransactionResultStatus.settlement ||
                status == TransactionResultStatus.capture) {
              message = '✅ Pembayaran berhasil! Saldo akan diperbarui.';
              bgColor = RupiaColors.success;
            } else if (status == TransactionResultStatus.pending) {
              message = '⏳ Pembayaran pending. Silakan selesaikan.';
              bgColor = RupiaColors.gold;
            } else {
              message = '❌ Pembayaran gagal';
              bgColor = RupiaColors.danger;
            }
          }
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(message, style: const TextStyle(color: Colors.white)),
            backgroundColor: bgColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
          _loadBalance();
        },
      );
      _midtransReady = true;
      return true;
    } catch (e) {
      debugPrint('[Wallet] Midtrans init gagal: $e');
      return false;
    }
  }

  Future<void> _loadBalance() async {
    setState(() => _isLoading = true);
    final balance = await _walletService.getBalance();
    if (mounted) setState(() { _balance = balance; _isLoading = false; });
  }



  Future<void> _refreshAll() async {
    await _loadBalance();
  }

  // ═══ TOP UP SHEET ═══
  void _showTopUpSheet() {
    final amountCtrl = TextEditingController();
    bool isLoadingTopup = false;
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (context, setModalState) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: RupiaColors.textHint, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Text('Top Up Saldo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(
            labelText: 'Jumlah Top Up (Min. Rp 10.000)', prefixText: 'Rp ',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          )),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: RupiaColors.primary, padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: isLoadingTopup ? null : () async {
              final amount = double.tryParse(amountCtrl.text.replaceAll('.', ''));
              if (amount == null || amount < 10000) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Minimal Top Up adalah Rp 10.000')));
                return;
              }
              setModalState(() => isLoadingTopup = true);

              // Lazy-init Midtrans SDK di sini (bukan di initState)
              final sdkReady = await _ensureMidtransReady();
              if (!context.mounted) return;
              if (!sdkReady) {
                setModalState(() => isLoadingTopup = false);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text('Midtrans SDK gagal dimuat. Coba lagi.'),
                  backgroundColor: RupiaColors.danger,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ));
                return;
              }

              final snapToken = await _walletService.generateTopUpToken(amount);
              if (!context.mounted) return;
              Navigator.pop(context);
              if (snapToken != null) {
                _midtransService.startPayment(snapToken);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Gagal membuat transaksi'), backgroundColor: RupiaColors.danger, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
              }
            },
            child: isLoadingTopup
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Lanjutkan Pembayaran', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
          )),
          const SizedBox(height: 16),
        ]),
      )),
    );
  }

  // ═══ TRANSFER SHEET ═══
  void _showTransferSheet() async {
    // Load daftar user untuk dipilih sebagai penerima
    final auth = AuthService();
    final currentUid = await auth.currentUid ?? '';
    final chatService = ChatService();
    final token = await auth.currentToken;
    if (token != null) chatService.setToken(token);
    final users = await chatService.getUsers(currentUid);

    if (!mounted) return;

    UserModel? selectedUser;
    final amountCtrl = TextEditingController();
    bool isLoadingTransfer = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (context, setModalState) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: RupiaColors.textHint, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          const Center(child: Text('Transfer Saldo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
          const SizedBox(height: 8),
          Center(child: Text('Saldo: Rp ${NumberFormat('#,###', 'id').format(_balance)}', style: const TextStyle(color: RupiaColors.textSecondary, fontSize: 13))),
          const SizedBox(height: 20),

          // Pilih penerima
          const Text('Kirim ke:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 8),
          SizedBox(
            height: 80,
            child: users.isEmpty
              ? const Center(child: Text('Tidak ada kontak', style: TextStyle(color: RupiaColors.textSecondary)))
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: users.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) {
                    final u = users[i];
                    final isSelected = selectedUser?.uid == u.uid;
                    return GestureDetector(
                      onTap: () => setModalState(() => selectedUser = u),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: isSelected ? RupiaColors.primary : Colors.transparent, width: 2.5),
                          ),
                          child: CircleAvatar(
                            radius: 24,
                            backgroundColor: RupiaColors.primary.withOpacity(0.1),
                            backgroundImage: (u.photoUrl != null && u.photoUrl!.isNotEmpty) ? NetworkImage(u.photoUrl!) : null,
                            child: (u.photoUrl == null || u.photoUrl!.isEmpty) ? Text(u.name[0].toUpperCase(), style: const TextStyle(color: RupiaColors.primary, fontWeight: FontWeight.bold)) : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(width: 56, child: Text(u.name.split(' ').first, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? RupiaColors.primary : RupiaColors.textSecondary))),
                      ]),
                    );
                  },
                ),
          ),
          const SizedBox(height: 16),

          // Jumlah transfer
          TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(
            labelText: 'Jumlah Transfer (Min. Rp 1.000)', prefixText: 'Rp ',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          )),
          const SizedBox(height: 20),

          // Tombol kirim
          SizedBox(width: double.infinity, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: RupiaColors.primary, padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: isLoadingTransfer ? null : () async {
              if (selectedUser == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih penerima terlebih dahulu')));
                return;
              }
              final amount = double.tryParse(amountCtrl.text.replaceAll('.', ''));
              if (amount == null || amount < 1000) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Minimal transfer Rp 1.000')));
                return;
              }
              if (amount > _balance) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Saldo tidak mencukupi'), backgroundColor: RupiaColors.danger));
                return;
              }

              setModalState(() => isLoadingTransfer = true);
              final result = await _walletService.transfer(receiverId: selectedUser!.uid, amount: amount);
              if (!context.mounted) return;
              Navigator.pop(context);

              if (result['success'] == true) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('✅ Transfer Rp ${NumberFormat('#,###', 'id').format(amount)} ke ${selectedUser!.name} berhasil!'),
                  backgroundColor: RupiaColors.success, behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ));
                _refreshAll();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(result['error'] ?? 'Transfer gagal'),
                  backgroundColor: RupiaColors.danger, behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ));
              }
            },
            child: isLoadingTransfer
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Kirim Sekarang', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
          )),
          const SizedBox(height: 16),
        ]),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      backgroundColor: isDark ? RupiaColors.bgDark : RupiaColors.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0D2B6B), RupiaColors.primary],
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text('Pembelian & Saldo',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20)),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(children: [
            // ══════════════════════════════════════════════════════
            // ── Header Biru: Kartu Saldo ──
            // ══════════════════════════════════════════════════════
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [RupiaColors.primary, Color(0xFF2557B3)],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1A3C8F), Color(0xFF0D2060)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Saldo RupiaChat',
                      style: TextStyle(color: Colors.white70, fontSize: 13, letterSpacing: 0.3)),
                  const SizedBox(height: 10),
                  _isLoading
                      ? const SizedBox(height: 38, width: 38, child: CircularProgressIndicator(color: Colors.white))
                      : Text(fmt.format(_balance),
                          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -1)),
                  const SizedBox(height: 6),
                  Text('≈ \$${(_balance / 15000).toStringAsFixed(2)} USD',
                      style: const TextStyle(color: RupiaColors.gold, fontSize: 12)),
                ]),
              ),
            ),

            // ══════════════════════════════════════════════════════
            // ── Area Putih: Action Buttons + Konten ──
            // ══════════════════════════════════════════════════════
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF2557B3), Color(0xFF2557B3)],
                ),
              ),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? RupiaColors.bgDark : RupiaColors.bg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(children: [
                  // ── Tombol Aksi (Row, bukan GridView) ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _ActionButton(icon: Icons.arrow_upward, label: 'Kirim', color: RupiaColors.primary, onTap: _showTransferSheet),
                        _ActionButton(icon: Icons.arrow_downward, label: 'Terima', color: RupiaColors.success, onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Bagikan nomor HP / email Anda agar orang lain bisa transfer ke Anda'),
                          ));
                        }),
                        _ActionButton(icon: Icons.add, label: 'Top Up', color: RupiaColors.gold, onTap: _showTopUpSheet),
                      ],
                    ),
                  ),

                  // ── Status & Paket VIP ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Status Akun:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : RupiaColors.textSecondary)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.grey.withOpacity(0.3)),
                              ),
                              child: const Text('Regular Member', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // VIP Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFFDE047), Color(0xFFCA8A04)]
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(color: RupiaColors.gold.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 6)),
                            ]
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                    child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFCA8A04), size: 32),
                                  ),
                                  const SizedBox(width: 14),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('VIP Member', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF422006))),
                                        SizedBox(height: 2),
                                        Text('Buka SEMUA Fitur Sekaligus', style: TextStyle(fontSize: 12, color: Color(0xFF713F12), fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Text('✓ Akses Panggilan Suara & Video\n✓ Akses Buat Grup Chat\n✓ Sticker Eksklusif & Tema Pro\n✓ Tanpa Iklan & Prioritas Server', 
                                style: TextStyle(fontSize: 13, color: Color(0xFF422006), fontWeight: FontWeight.w500, height: 1.6)),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF422006),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 0,
                                  ),
                                  onPressed: () => _confirmPurchase('VIP Member', 50000),
                                  child: const Text('Beli VIP - Rp 50.000 / bln', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                ),
                              )
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 28),
                        Text('Atau Beli Fitur Terpisah',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: isDark ? Colors.white : RupiaColors.textPrimary)),
                        const SizedBox(height: 12),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.85,
                          children: [
                            _buildPurchaseItem('Buat Grup', 'Buka akses membuat grup chat', 10000, Icons.group_add_rounded, RupiaColors.primary),
                            _buildPurchaseItem('Voice Call', 'Buka fitur panggilan suara', 5000, Icons.call_rounded, RupiaColors.success),
                            _buildPurchaseItem('Video Call', 'Buka fitur panggilan video', 15000, Icons.videocam_rounded, Colors.purple),
                            _buildPurchaseItem('Sticker Pack', '100+ sticker eksklusif', 15000, Icons.emoji_emotions_rounded, Colors.pink),
                            _buildPurchaseItem('Tema Pro', 'Warna kustom & mode gelap', 5000, Icons.color_lens_rounded, Colors.deepPurple),
                            _buildPurchaseItem('Paket Nelpon', 'Gratis nelpon sepuasnya (30 hr)', 25000, Icons.phone_in_talk_rounded, Colors.teal),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),


                  const SizedBox(height: 100), // space for floating navbar
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }



  Widget _buildPurchaseItem(String title, String desc, double price, IconData icon, Color color) {
    final fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? RupiaColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4)),
        ]
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 10),
          Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: isDark ? Colors.white : RupiaColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(desc, style: TextStyle(fontSize: 10, color: isDark ? Colors.white60 : RupiaColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _confirmPurchase(title, price),
              child: Text(fmt.format(price), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  void _confirmPurchase(String title, double price) {
    final fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Pembelian'),
        content: Text('Apakah Anda yakin ingin membeli $title seharga ${fmt.format(price)}?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: RupiaColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: RupiaColors.primary),
            onPressed: () {
              Navigator.pop(ctx);
              if (_balance < price) {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saldo tidak mencukupi! Silakan Top Up.')));
                 _showTopUpSheet();
              } else {
                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Berhasil membeli $title!'), backgroundColor: RupiaColors.success));
                 // Note: Tambahkan integrasi backend pemotongan saldo di sini
              }
            },
            child: const Text('Beli', style: TextStyle(color: Colors.white)),
          ),
        ],
      )
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(onTap: onTap, child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 52, height: 52, decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: color, size: 24)),
      const SizedBox(height: 6),
      Text(label, style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : RupiaColors.textSecondary, fontWeight: FontWeight.w500)),
    ]));
  }
}
