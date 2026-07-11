import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/cash_session.dart';
import '../services/cash_register_service.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';

class CashRegisterScreen extends StatefulWidget {
  const CashRegisterScreen({super.key});

  @override
  State<CashRegisterScreen> createState() => _CashRegisterScreenState();
}

class _CashRegisterScreenState extends State<CashRegisterScreen> {
  final _service = CashRegisterService();
  CashSession? _activeSession;
  List<CashSession> _history = [];
  int _salesCount = 0;
  double _expectedCash = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _service.getActiveSession(),
      _service.getSessionHistory(),
    ]);
    if (!mounted) return;
    final active = results[0] as CashSession?;
    int salesCount = 0;
    double expectedCash = 0;
    if (active != null) {
      final sessionData = await Future.wait([
        _service.getSalesCountSince(active.openedAt),
        _service.getExpectedCashForSession(active),
      ]);
      salesCount = sessionData[0] as int;
      expectedCash = sessionData[1] as double;
    }
    setState(() {
      _activeSession = active;
      _history = results[1] as List<CashSession>;
      _salesCount = salesCount;
      _expectedCash = expectedCash;
      _isLoading = false;
    });
  }

  void _showOpenRegisterSheet() {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Open Register',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Count the cash in the drawer before starting.',
                style: TextStyle(color: AppColors.muted, fontSize: 14),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Opening Cash *',
                  prefixIcon: Icon(Icons.payments_outlined),
                  hintText: '0',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter opening cash';
                  if (double.tryParse(v.trim()) == null) return 'Invalid number';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  await _service.openSession(
                    double.parse(controller.text.trim()),
                  );
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    _loadData();
                  }
                },
                child: const Text('Open Register'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCloseRegisterSheet() {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Close Register',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Actual Cash Count *',
                    prefixIcon: Icon(Icons.payments_outlined),
                    hintText: '0',
                  ),
                  onChanged: (_) => setSheetState(() {}),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter cash count';
                    if (double.tryParse(v.trim()) == null) return 'Invalid number';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _CashPreviewRow(
                  label: 'Expected',
                  value: _expectedCash,
                  color: AppColors.muted,
                ),
                const SizedBox(height: 8),
                Builder(
                  builder: (_) {
                    final counted = double.tryParse(controller.text.trim()) ?? 0;
                    final diff = counted - _expectedCash;
                    final color = diff == 0 ? AppColors.sell : AppColors.danger;
                    return _CashPreviewRow(
                      label: 'Discrepancy',
                      value: diff,
                      color: color,
                      showSign: true,
                    );
                  },
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    await _service.closeSession(
                      double.parse(controller.text.trim()),
                    );
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      _loadData();
                    }
                  },
                  child: const Text('Close Register'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cash Register'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_activeSession == null) ...[
                    _ClosedRegisterCard(onOpen: _showOpenRegisterSheet),
                  ] else ...[
                    _ActiveSessionCard(
                      session: _activeSession!,
                      salesCount: _salesCount,
                      expectedCash: _expectedCash,
                      onClose: _showCloseRegisterSheet,
                    ),
                  ],
                  if (_history.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'History',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ..._history.map((s) => _SessionHistoryTile(session: s)),
                  ],
                ],
              ),
            ),
    );
  }
}

class _ClosedRegisterCard extends StatelessWidget {
  final VoidCallback onOpen;

  const _ClosedRegisterCard({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.muted.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_outline, size: 40, color: AppColors.muted),
          ),
          const SizedBox(height: 20),
          const Text(
            'Register Closed',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Open the register to start tracking cash for this session.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.lock_open_outlined),
              label: const Text('Open Register'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveSessionCard extends StatelessWidget {
  final CashSession session;
  final int salesCount;
  final double expectedCash;
  final VoidCallback onClose;

  const _ActiveSessionCard({
    required this.session,
    required this.salesCount,
    required this.expectedCash,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final openedAt = DateTime.fromMillisecondsSinceEpoch(session.openedAt);
    final timeStr = DateFormat('d MMM, h:mm a').format(openedAt);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF134E4A), AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4ADE80),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'OPEN',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Opened $timeStr',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _SessionStat(
                  label: 'Opening Cash',
                  value: formatPkr(session.openingCash),
                ),
              ),
              Expanded(
                child: _SessionStat(
                  label: 'Sales',
                  value: '$salesCount txns',
                ),
              ),
              Expanded(
                child: _SessionStat(
                  label: 'Expected Cash',
                  value: formatPkr(expectedCash),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onClose,
              icon: const Icon(Icons.lock_outline, color: Colors.white),
              label: const Text('Close Register', style: TextStyle(color: Colors.white)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white54),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionStat extends StatelessWidget {
  final String label;
  final String value;

  const _SessionStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _CashPreviewRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final bool showSign;

  const _CashPreviewRow({
    required this.label,
    required this.value,
    required this.color,
    this.showSign = false,
  });

  @override
  Widget build(BuildContext context) {
    final sign = showSign && value > 0 ? '+' : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
          Text(
            '$sign${formatPkr(value)}',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _SessionHistoryTile extends StatelessWidget {
  final CashSession session;

  const _SessionHistoryTile({required this.session});

  @override
  Widget build(BuildContext context) {
    final openedAt = DateTime.fromMillisecondsSinceEpoch(session.openedAt);
    final dateStr = DateFormat('d MMM yyyy').format(openedAt);
    final discrepancy = session.discrepancy ?? 0;
    final isClean = discrepancy == 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateStr,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Opening ${formatPkr(session.openingCash)} · Closing ${formatPkr(session.closingCash ?? 0)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          if (isClean)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.sell.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline, size: 14, color: AppColors.sell),
                  SizedBox(width: 4),
                  Text(
                    'Balanced',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.sell,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${discrepancy > 0 ? '+' : ''}${formatPkr(discrepancy)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.danger,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
