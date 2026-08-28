import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
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
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Open Register',
                  style: bricolage(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Count the cash in the drawer before starting.',
                  style: instrument(fontSize: 14, color: AppColors.muted)),
              const SizedBox(height: 20),
              TextFormField(
                controller: controller,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: mono(fontSize: 15, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  labelText: 'Opening Cash *',
                  prefixIcon: Icon(Symbols.payments),
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
                  await _service.openSession(double.parse(controller.text.trim()));
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
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Close Register',
                    style:
                        bricolage(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: mono(fontSize: 15, fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    labelText: 'Actual Cash Count *',
                    prefixIcon: Icon(Symbols.payments),
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
                    color: AppColors.muted),
                const SizedBox(height: 8),
                Builder(builder: (_) {
                  final counted = double.tryParse(controller.text.trim()) ?? 0;
                  final diff = counted - _expectedCash;
                  final color = diff == 0 ? AppColors.green : AppColors.red;
                  return _CashPreviewRow(
                    label: 'Discrepancy',
                    value: diff,
                    color: color,
                    showSign: true,
                  );
                }),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    await _service
                        .closeSession(double.parse(controller.text.trim()));
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
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Symbols.arrow_back,
                        size: 24, color: AppColors.ink),
                  ),
                  const SizedBox(width: 8),
                  Text('Cash Register',
                      style: bricolage(
                          fontSize: 20, fontWeight: FontWeight.w700)),
                ],
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      color: AppColors.green,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: [
                          if (_activeSession == null)
                            _ClosedRegisterCard(
                                onOpen: _showOpenRegisterSheet)
                          else
                            _ActiveSessionCard(
                              session: _activeSession!,
                              salesCount: _salesCount,
                              expectedCash: _expectedCash,
                              onClose: _showCloseRegisterSheet,
                            ),
                          if (_history.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            Text(
                              'HISTORY',
                              style: instrument(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.muted,
                                letterSpacing: 0.12,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ..._history
                                .map((s) => _SessionHistoryTile(session: s)),
                          ],
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Closed register card ──────────────────────────────────────────────────────

class _ClosedRegisterCard extends StatelessWidget {
  final VoidCallback onOpen;
  const _ClosedRegisterCard({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.paperDark,
              shape: BoxShape.circle,
            ),
            child: const Icon(Symbols.lock,
                size: 36, color: AppColors.muted),
          ),
          const SizedBox(height: 20),
          Text('Register Closed',
              style: bricolage(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'Open the register to start tracking cash for this session.',
            textAlign: TextAlign.center,
            style: instrument(fontSize: 14, color: AppColors.muted),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onOpen,
              icon: const Icon(Symbols.lock_open),
              label: const Text('Open Register'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Active session card ───────────────────────────────────────────────────────

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
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // OPEN badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.greenBright.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.greenBright,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  'OPEN',
                  style: instrument(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.greenBright,
                    letterSpacing: 0.06,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Opened $timeStr',
            style: instrument(fontSize: 12.5, color: AppColors.inkMuted),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SessionStat(
                  label: 'Opening cash',
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
                  label: 'Expected',
                  value: formatPkr(expectedCash),
                  valueColor: AppColors.greenBright,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onClose,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Symbols.lock, size: 20, color: AppColors.onDark),
                  const SizedBox(width: 8),
                  Text('Close Register',
                      style: instrument(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onDark)),
                ],
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
  final Color valueColor;

  const _SessionStat({
    required this.label,
    required this.value,
    this.valueColor = AppColors.onDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: instrument(fontSize: 11, color: AppColors.inkMuted)),
        const SizedBox(height: 4),
        Text(value,
            style: mono(
                fontSize: 15, fontWeight: FontWeight.w700, color: valueColor)),
      ],
    );
  }
}

// ── Cash preview row (in close sheet) ────────────────────────────────────────

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
          Text(label,
              style: instrument(
                  fontSize: 14, fontWeight: FontWeight.w500, color: color)),
          Text('$sign${formatPkr(value)}',
              style:
                  mono(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

// ── Session history tile ──────────────────────────────────────────────────────

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
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateStr,
                    style: instrument(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(
                  'Open ${formatPkr(session.openingCash)} · Close ${formatPkr(session.closingCash ?? 0)}',
                  style: mono(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          if (isClean)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.greenLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Symbols.check_circle,
                      size: 15, color: AppColors.green),
                  const SizedBox(width: 5),
                  Text('Balanced',
                      style: instrument(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.greenDark)),
                ],
              ),
            )
          else
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.redLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${discrepancy > 0 ? '+' : ''}${formatPkr(discrepancy)}',
                style: mono(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.red),
              ),
            ),
        ],
      ),
    );
  }
}
