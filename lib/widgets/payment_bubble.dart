import 'package:flutter/material.dart';
import '../utils/colors.dart';

// PaymentBubble = gelembung pesan khusus untuk transaksi pembayaran
class PaymentBubble extends StatelessWidget {
  final String amount;      // nominal, contoh: "Rp 50.000"
  final String senderName;  // nama pengirim
  final bool isMe;          // true = saya yang kirim, false = teman yang kirim
  final String time;        // waktu pesan

  const PaymentBubble({
    super.key,
    required this.amount,
    required this.senderName,
    required this.isMe,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2C2515) : const Color(0xFFFFF8E7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: RupiaColors.gold.withOpacity(isDarkMode ? 0.5 : 1.0)),
          boxShadow: isDarkMode ? null : [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: ikon dompet + label pengirim
            Row(children: [
              const Icon(Icons.account_balance_wallet,
                  color: RupiaColors.gold, size: 16),
              const SizedBox(width: 6),
              Text(
                isMe ? 'Kamu mengirim' : '$senderName mengirim',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: isDarkMode ? RupiaColors.gold : const Color(0xFF7A5200)),
              ),
            ]),
            const SizedBox(height: 8),
            // Nominal pembayaran (besar)
            Text(amount,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: isDarkMode ? Colors.white : const Color(0xFF412402))),
            const SizedBox(height: 4),
            // Waktu pesan
            Text(time,
                style: const TextStyle(
                    fontSize: 10, color: RupiaColors.textHint)),
            // Tombol bayar (hanya muncul jika pesan dari teman)
            if (!isMe) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: 130,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RupiaColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    // TODO: hubungkan ke payment gateway (Midtrans)
                  },
                  child: const Text('Bayar Sekarang',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
