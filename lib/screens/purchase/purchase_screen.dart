import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/colors.dart';
import '../../services/purchase_service.dart';
import '../../services/xendit_service.dart';

class FeatureItem {
  final String slug;
  final String title;
  final String desc;
  final double price;
  final IconData icon;
  final Color color;

  const FeatureItem({
    required this.slug,
    required this.title,
    required this.desc,
    required this.price,
    required this.icon,
    required this.color,
  });
}

final List<FeatureItem> purchasableFeatures = [
  FeatureItem(
    slug: 'group_create',
    title: 'Buat Grup',
    desc: 'Buka akses membuat grup chat',
    price: 10000,
    icon: Icons.group_add_rounded,
    color: RupiaColors.primary,
  ),
  FeatureItem(
    slug: 'voice_call',
    title: 'Voice Call',
    desc: 'Buka fitur panggilan suara',
    price: 5000,
    icon: Icons.call_rounded,
    color: RupiaColors.success,
  ),
  FeatureItem(
    slug: 'video_call',
    title: 'Video Call',
    desc: 'Buka fitur panggilan video',
    price: 15000,
    icon: Icons.videocam_rounded,
    color: Colors.purple,
  ),
  FeatureItem(
    slug: 'attachment',
    title: 'Kirim Lampiran',
    desc: 'Buka akses fitur kirim lampiran (dokumen, foto, dll)',
    price: 15000,
    icon: Icons.attach_file_rounded,
    color: Colors.pink,
  ),
  FeatureItem(
    slug: 'theme_pro',
    title: 'Tema Pro',
    desc: 'Warna kustom & mode gelap',
    price: 5000,
    icon: Icons.color_lens_rounded,
    color: Colors.deepPurple,
  ),
  FeatureItem(
    slug: 'call_package',
    title: 'Paket Nelpon',
    desc: 'Nelpon sepuasnya (30 hr)',
    price: 25000,
    icon: Icons.phone_in_talk_rounded,
    color: Colors.teal,
  ),
];

class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({super.key});

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  final _purchaseService = PurchaseService();
  final _xenditService = XenditService();

  double _balance = 0.0;
  List<String> _activeFeatures = [];
  List<Map<String, dynamic>> _purchases = [];
  double _usdRate = 16000.0;
  String _rateUpdatedAt = '';

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final balance = await _purchaseService.getBalance();
      final active = await _purchaseService.getActiveFeatures();
      final rateData = await _purchaseService.getExchangeRate();
      final purchases = await _purchaseService.getPurchases();

      if (mounted) {
        setState(() {
          _balance = balance;
          _activeFeatures = active;
          _purchases = purchases;
          if (rateData != null) {
            _usdRate = rateData['usd_idr'];
            _rateUpdatedAt = rateData['updated_at'];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading purchase screen data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshAll() async {
    await _loadData();
  }

  void _showTopUpSheet() {
    final amountCtrl = TextEditingController();
    bool isLoadingTopup = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Top Up Saldo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withOpacity(0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ini adalah mode testing. Top up menggunakan saldo sandbox gratis (tanpa uang asli).',
                        style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
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
                  onPressed: isLoadingTopup
                      ? null
                      : () async {
                          final amount = double.tryParse(amountCtrl.text.replaceAll('.', ''));
                          if (amount == null || amount < 10000) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Minimal Top Up adalah Rp 10.000')),
                            );
                            return;
                          }
                          setModalState(() => isLoadingTopup = true);

                          final scaffoldMsg = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(context);

                          final invoiceUrl = await _purchaseService.generateTopUpInvoice(amount);
                          if (!mounted) return;
                          navigator.pop();
                          if (invoiceUrl != null) {
                            await _xenditService.openInvoiceUrl(invoiceUrl);
                            
                            // Tampilkan info untuk me-refresh
                            scaffoldMsg.showSnackBar(SnackBar(
                              content: const Text('Silakan lakukan pembayaran lalu kembali dan tarik layar untuk refresh (Pull to Refresh).'),
                              backgroundColor: RupiaColors.primary,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              duration: const Duration(seconds: 5),
                            ));
                          } else {
                            scaffoldMsg.showSnackBar(SnackBar(
                              content: const Text('Gagal membuat transaksi (Invoice).'),
                              backgroundColor: RupiaColors.danger,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ));
                          }
                        },
                  child: isLoadingTopup
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Lanjutkan Pembayaran',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _handlePurchase(String slug, String title, double price) {
    final fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Pembelian'),
        content: Text('Apakah Anda yakin ingin mengaktifkan $title seharga ${fmt.format(price)}? Saldo Anda akan langsung terpotong.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: RupiaColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: RupiaColors.primary),
            onPressed: () async {
              Navigator.pop(ctx);
              if (_balance < price) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Saldo tidak mencukupi! Silakan Top Up.'),
                    backgroundColor: RupiaColors.danger,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                _showTopUpSheet();
              } else {
                setState(() => _isLoading = true);
                final scaffoldMsg = ScaffoldMessenger.of(context);
                final res = await _purchaseService.buyFeature(
                  featureSlug: slug,
                  featureName: title,
                  price: price,
                );
                if (!mounted) return;
                if (res['success'] == true) {
                  scaffoldMsg.showSnackBar(
                    SnackBar(
                      content: Text('✅ ${res['message']}'),
                      backgroundColor: RupiaColors.success,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                  _loadData();
                } else {
                  scaffoldMsg.showSnackBar(
                    SnackBar(
                      content: Text('❌ ${res['error']}'),
                      backgroundColor: RupiaColors.danger,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                  setState(() => _isLoading = false);
                }
              }
            },
            child: const Text('Beli & Aktifkan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  bool _isFeatureUnlocked(String slug) {
    if (_activeFeatures.contains('vip_member')) return true;
    return _activeFeatures.contains(slug);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final idrFmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final rateFmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 2);
    final isVipActive = _activeFeatures.contains('vip_member');

    return Scaffold(
      backgroundColor: isDark ? RupiaColors.bgDark : RupiaColors.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0D2B6B), RupiaColors.primary],
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text(
              'Pembelian & Saldo',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // ⚠️ Banner Sandbox Notice (Sleek single-line)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.amber.withOpacity(0.15) : Colors.amber.withOpacity(0.08),
                  border: Border(bottom: BorderSide(color: Colors.amber.withOpacity(0.3), width: 0.5)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: isDark ? Colors.amber.shade400 : Colors.amber.shade800, size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Mode Testing — Top Up Gratis (Xendit Test Mode). Tanpa Uang Asli.',
                        style: TextStyle(
                          color: isDark ? Colors.amber.shade400 : Colors.amber.shade800,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // 💱 Exchange Rate Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                color: isDark ? const Color(0xFF14223A) : const Color(0xFFE8EFCF),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.currency_exchange, color: RupiaColors.primary, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Kurs: \$1 USD = ${rateFmt.format(_usdRate)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white.withOpacity(0.9) : RupiaColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        if (_rateUpdatedAt.isNotEmpty)
                          Text(
                            'Update: ${DateFormat('dd MMM HH:mm').format(DateTime.parse(_rateUpdatedAt).toLocal())}',
                            style: TextStyle(fontSize: 10, color: isDark ? Colors.white60 : RupiaColors.textSecondary),
                          ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: _refreshAll,
                          child: Icon(Icons.sync, size: 14, color: isDark ? Colors.white60 : RupiaColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Header: Balance Card
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [RupiaColors.primary, Color(0xFF2557B3)],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Saldo RupiaChat',
                        style: TextStyle(color: Colors.white70, fontSize: 13, letterSpacing: 0.3),
                      ),
                      const SizedBox(height: 10),
                      _isLoading
                          ? const SizedBox(
                              height: 38,
                              width: 38,
                              child: CircularProgressIndicator(color: Colors.white),
                            )
                          : Text(
                              idrFmt.format(_balance),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -1,
                              ),
                            ),
                      const SizedBox(height: 6),
                      Text(
                        '≈ \$${(_balance / _usdRate).toStringAsFixed(2)} USD',
                        style: const TextStyle(color: RupiaColors.gold, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),

              // Content Area
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
                  child: Column(
                    children: [
                      // Top Up Action Button (Proportional & Elegant)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                        child: SizedBox(
                          width: double.infinity,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [RupiaColors.primary, Color(0xFF2557B3)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: RupiaColors.primary.withOpacity(0.25),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              icon: const Icon(Icons.add_card_rounded, color: RupiaColors.gold, size: 22),
                              label: const Text(
                                'Top Up Saldo',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.3),
                              ),
                              onPressed: _showTopUpSheet,
                            ),
                          ),
                        ),
                      ),

                      // Status Akun
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Status Akun:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : RupiaColors.textSecondary,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isVipActive
                                    ? Colors.amber.withOpacity(0.15)
                                    : Colors.grey.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isVipActive
                                      ? Colors.amber.withOpacity(0.3)
                                      : Colors.grey.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                isVipActive ? 'VIP Member 👑' : 'Regular Member',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isVipActive ? Colors.orange : Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // VIP Card (Luxury Dark & Gold Edition)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.amber.withOpacity(0.25), width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withOpacity(0.15),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.amber.withOpacity(0.4)),
                                    ),
                                    child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFBBF24), size: 30),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'VIP Member',
                                          style: TextStyle(
                                            fontSize: 22, 
                                            fontWeight: FontWeight.w800, 
                                            foreground: Paint()..shader = const LinearGradient(
                                              colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
                                            ).createShader(const Rect.fromLTWH(0, 0, 200, 70)),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'Buka SEMUA Fitur Sekaligus',
                                          style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500, letterSpacing: 0.2),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                '✓ Akses Panggilan Suara & Video\n✓ Akses Buat Grup Chat\n✓ Fitur Kirim Lampiran\n✓ Tanpa Iklan & Prioritas Server',
                                style: TextStyle(fontSize: 13, color: Colors.white60, fontWeight: FontWeight.w400, height: 1.8),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(color: const Color(0xFFD97706).withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4)),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      shadowColor: Colors.transparent,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                    onPressed: isVipActive ? null : () => _handlePurchase('vip_member', 'VIP Member', 50000),
                                    child: Text(
                                      isVipActive ? 'VIP Member Aktif' : 'Beli VIP - Rp 50.000 / bln',
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.5),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Features grid
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Atau Beli Fitur Terpisah',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isDark ? Colors.white : RupiaColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: purchasableFeatures.length,
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.85,
                              ),
                              itemBuilder: (ctx, i) {
                                final f = purchasableFeatures[i];
                                final isUnlocked = _isFeatureUnlocked(f.slug);
                                return Container(
                                  decoration: BoxDecoration(
                                    color: isDark ? RupiaColors.cardDark : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isUnlocked
                                          ? RupiaColors.success.withOpacity(0.3)
                                          : f.color.withOpacity(0.3),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: f.color.withOpacity(0.05),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: f.color.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(f.icon, color: f.color, size: 24),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        f.title,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: isDark ? Colors.white : RupiaColors.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        f.desc,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isDark ? Colors.white60 : RupiaColors.textSecondary,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const Spacer(),
                                      SizedBox(
                                        width: double.infinity,
                                        child: isUnlocked
                                            ? Container(
                                                padding: const EdgeInsets.symmetric(vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: RupiaColors.success.withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Center(
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Icon(Icons.check_circle_outline, color: RupiaColors.success, size: 14),
                                                      SizedBox(width: 4),
                                                      Text(
                                                        'Aktif',
                                                        style: TextStyle(
                                                          color: RupiaColors.success,
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              )
                                            : ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: f.color,
                                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                ),
                                                onPressed: () => _handlePurchase(f.slug, f.title, f.price),
                                                child: Text(
                                                  idrFmt.format(f.price),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      // Purchase History
                      if (_purchases.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Divider(height: 32),
                              Text(
                                'Riwayat Pembelian',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isDark ? Colors.white : RupiaColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _purchases.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (ctx, i) {
                                  final p = _purchases[i];
                                  final title = p['feature_name'] ?? p['feature_slug'] ?? 'Fitur';
                                  final price = double.tryParse(p['price'].toString()) ?? 0.0;
                                  final dateStr = p['created_at'] ?? '';
                                  String formattedDate = '';
                                  if (dateStr.isNotEmpty) {
                                    final dt = DateTime.parse(dateStr).toLocal();
                                    formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(dt);
                                  }

                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isDark ? RupiaColors.cardDark : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey.withOpacity(0.15)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          title.toString().contains('VIP')
                                              ? Icons.workspace_premium_rounded
                                              : Icons.widgets_outlined,
                                          color: RupiaColors.primary,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                title,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                formattedDate,
                                                style: TextStyle(fontSize: 10, color: isDark ? Colors.white60 : RupiaColors.textSecondary),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              idrFmt.format(price),
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                            const SizedBox(height: 2),
                                            const Text(
                                              'Selesai ✅',
                                              style: TextStyle(color: RupiaColors.success, fontSize: 10, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 100), // space for bottom navbar
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
