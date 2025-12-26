import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/now_payments_service.dart';
import '../services/supabase_service.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  bool _isLoading = false;

  Future<void> _handlePurchase() async {
    setState(() {
      _isLoading = true;
    });

    // Mock purchase delay
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Purchase Successful!'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 64),
              SizedBox(height: 16),
              Text(
                'Thank you for subscribing to Pushinn Premium! \n\n(This is a prototype mock purchase - no actual charge was made)',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Close screen
              },
              child: const Text('Awesome!'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _handleXMRPurchase() async {
    setState(() {
      _isLoading = true;
    });

    final user = SupabaseService.getCurrentUser();
    final userId = user?.id ?? 'anonymous';
    final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    final callbackUrl = supabaseUrl.isNotEmpty 
        ? '$supabaseUrl/functions/v1/nowpayments-ipn'
        : null;

    // Create a real payment request via NOWPayments
    final invoiceUrl = await NowPaymentsService.createPayment(
      amount: 4.99,
      currency: 'xmr',
      orderId: 'premium_${userId}_${DateTime.now().millisecondsSinceEpoch}',
      orderDescription: 'Pushinn Premium Subscription',
      callbackUrl: callbackUrl,
    );

    setState(() {
      _isLoading = false;
    });

    if (invoiceUrl == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create payment. Please try again later.')),
        );
      }
      return;
    }

    // Open the invoice URL in the browser
    final uri = Uri.parse(invoiceUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Row(
            children: [
              Image.network(
                'https://www.getmonero.org/press-kit/symbols/monero-symbol-480.png',
                height: 32,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.currency_bitcoin, color: Colors.orange),
              ),
              const SizedBox(width: 12),
              const Text('Payment Sent?', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'We have opened the NOWPayments invoice in your browser.',
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              CircularProgressIndicator(color: Colors.orange),
              SizedBox(height: 16),
              Text(
                'Waiting for blockchain confirmation...\n(This usually takes 2-10 minutes)',
                style: TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                // In a real app, this would call getPaymentStatus
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Checking status... (Simulation)')),
                );
                Navigator.pop(context);
                _handlePurchase(); // Simulate success for the prototype
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.black),
              child: const Text('Check Status'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.amber.shade900,
                  Colors.black,
                ],
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      const Text(
                        'PREMIUM',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 48), // Balance close button
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Colors.amber,
                          size: 80,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Unlock the Full Experience',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Join the elite skaters and support the community.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 48),

                        _buildBenefitRow(
                          icon: Icons.block,
                          title: 'No Ads',
                          description: 'Enjoy a seamless experience without interruptions.',
                        ),
                        const SizedBox(height: 24),
                        _buildBenefitRow(
                          icon: Icons.verified,
                          title: 'Verified Badge',
                          description: 'Stand out with a special badge on your profile and posts.',
                        ),
                        const SizedBox(height: 24),
                        _buildBenefitRow(
                          icon: Icons.favorite,
                          title: 'Support Development',
                          description: 'Help us keep the servers running and build new features.',
                        ),
                      ],
                    ),
                  ),
                ),

                // Purchase Button
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handlePurchase,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 8,
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.black)
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Subscribe Now',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '\$4.99 / month',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // XMR Payment Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : _handleXMRPurchase,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.orange, width: 2),
                            foregroundColor: Colors.orange,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.network(
                                'https://www.getmonero.org/press-kit/symbols/monero-symbol-480.png',
                                height: 24,
                                errorBuilder: (context, error, stackTrace) => const Icon(Icons.currency_bitcoin, size: 24),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Pay with XMR',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('No purchases to restore')),
                          );
                        },
                        child: Text(
                          'Restore Purchases',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitRow({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.amber, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
