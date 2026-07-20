import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../models/expense.dart';
import '../models/finance_models.dart';
import '../models/transaction.dart';
import '../services/expense_service.dart';
import '../services/export_service.dart';
import '../services/finance_service.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  final _financeService = FinanceService();
  final _expenseService = ExpenseService();
  FinancePeriod _period = FinancePeriod.today;

  PeriodSummary _summary = const PeriodSummary();
  PeriodSummary? _previousSummary;
  List<ChartDataPoint> _chartData = [];
  List<ProductBreakdown> _topProducts = [];
  List<SaleTransaction> _transactions = [];
  List<Expense> _expenses = [];
  double _totalExpenses = 0;
  double _inventoryValue = 0;
  bool _isLoading = true;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final (from, to) = _financeService.rangeForPeriod(_period);
    final results = await Future.wait([
      _financeService.getSummaryForPeriod(_period),
      _financeService.getChartData(_period),
      _financeService.getTopProducts(_period),
      _financeService.getTransactions(_period),
      _financeService.getInventoryValue(),
      _expenseService.getExpenses(from: from, to: to),
      _expenseService.getTotalExpenses(from: from, to: to),
      _financeService.getPreviousPeriodSummary(_period),
    ]);
    if (!mounted) return;
    setState(() {
      _summary = results[0] as PeriodSummary;
      _chartData = results[1] as List<ChartDataPoint>;
      _topProducts = results[2] as List<ProductBreakdown>;
      _transactions = results[3] as List<SaleTransaction>;
      _inventoryValue = results[4] as double;
      _expenses = results[5] as List<Expense>;
      _totalExpenses = results[6] as double;
      _previousSummary = results[7] as PeriodSummary;
      _isLoading = false;
    });
  }

  void _setPeriod(FinancePeriod period) {
    if (_period == period) return;
    setState(() => _period = period);
    _loadData();
  }

  String get _periodExportLabel {
    switch (_period) {
      case FinancePeriod.today:
        return 'Today';
      case FinancePeriod.week:
        return 'This Week';
      case FinancePeriod.month:
        return 'This Month';
    }
  }

  String get _comparisonLabel {
    switch (_period) {
      case FinancePeriod.today:
        return 'vs yesterday';
      case FinancePeriod.week:
        return 'vs last week';
      case FinancePeriod.month:
        return 'vs last month';
    }
  }

  Future<void> _exportData() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      await ExportService().exportTransactions(_transactions, _periodExportLabel);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showAddExpenseSheet() {
    String selectedCategory = expenseCategories.first;
    final amountController = TextEditingController();
    final noteController = TextEditingController();
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
                Text(
                  'Add Expense',
                  style: bricolage(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: expenseCategories.map((cat) {
                    final selected = cat == selectedCategory;
                    return FilterChip(
                      label: Text(cat),
                      selected: selected,
                      onSelected: (_) => setSheetState(() => selectedCategory = cat),
                      selectedColor: AppColors.primary.withValues(alpha: 0.15),
                      checkmarkColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: selected ? AppColors.primary : AppColors.muted,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount *',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter amount';
                    if (double.tryParse(v.trim()) == null) return 'Invalid number';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: noteController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final expense = Expense(
                      category: selectedCategory,
                      amount: double.parse(amountController.text.trim()),
                      note: noteController.text.trim().isEmpty
                          ? null
                          : noteController.text.trim(),
                      timestamp: DateTime.now().millisecondsSinceEpoch,
                    );
                    await _expenseService.addExpense(expense);
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      _loadData();
                    }
                  },
                  child: const Text('Save Expense'),
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
    final topPadding = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: AppColors.paper,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddExpenseSheet,
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Symbols.add),
        label: Text('Add Expense',
            style: instrument(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white)),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.green,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, topPadding + 14, 20, 0),
                child: Column(
                  children: [
                    // Header
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Symbols.arrow_back,
                              size: 24, color: AppColors.ink),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Cash Flow',
                              style: bricolage(
                                  fontSize: 20, fontWeight: FontWeight.w700)),
                        ),
                        if (_isExporting)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          GestureDetector(
                            onTap: _exportData,
                            child: const Icon(Symbols.ios_share,
                                size: 23, color: AppColors.muted),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Period tabs
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.paperDark,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: AppColors.borderDark),
                      ),
                      child: Row(
                        children: [
                          _PeriodTab(
                              label: 'Today',
                              selected: _period == FinancePeriod.today,
                              onTap: () => _setPeriod(FinancePeriod.today)),
                          _PeriodTab(
                              label: 'Week',
                              selected: _period == FinancePeriod.week,
                              onTap: () => _setPeriod(FinancePeriod.week)),
                          _PeriodTab(
                              label: 'Month',
                              selected: _period == FinancePeriod.month,
                              onTap: () => _setPeriod(FinancePeriod.month)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _SummaryGrid(
                      summary: _summary,
                      previous: _previousSummary,
                      comparisonLabel: _comparisonLabel,
                    ),
                    const SizedBox(height: 10),
                    _NetProfitCard(
                      grossProfit: _summary.profit,
                      totalExpenses: _totalExpenses,
                    ),
                    const SizedBox(height: 20),
                    _InventoryValueCard(value: _inventoryValue),
                    const SizedBox(height: 20),
                    _SectionTitle(
                      title: 'Expenses',
                      subtitle: 'Total: ${formatPkr(_totalExpenses)}',
                    ),
                    const SizedBox(height: 12),
                    _ExpensesList(
                      expenses: _expenses,
                      onDelete: (id) async {
                        await _expenseService.deleteExpense(id);
                        _loadData();
                      },
                    ),
                    const SizedBox(height: 20),
                    _SectionTitle(
                      title: 'Revenue & Profit',
                      subtitle: _periodLabel(),
                    ),
                    const SizedBox(height: 12),
                    _RevenueProfitChart(data: _chartData),
                    const SizedBox(height: 20),
                    const _SectionTitle(
                      title: 'Revenue vs Costs',
                      subtitle: 'Sales revenue compared to costs',
                    ),
                    const SizedBox(height: 12),
                    _RevenueCostChart(data: _chartData),
                    const SizedBox(height: 20),
                    const _SectionTitle(
                      title: 'Top Products',
                      subtitle: 'By revenue this period',
                    ),
                    const SizedBox(height: 12),
                    _TopProductsChart(products: _topProducts),
                    const SizedBox(height: 20),
                    _SectionTitle(
                      title: 'Transactions',
                      subtitle: '${_transactions.length} recorded',
                    ),
                    const SizedBox(height: 12),
                    if (_transactions.isEmpty)
                      _EmptyTransactions()
                    else
                      ..._transactions.map((tx) => _TransactionTile(tx: tx)),
                    const SizedBox(height: 24),
                  ]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _periodLabel() {
    switch (_period) {
      case FinancePeriod.today:
        return 'Hourly breakdown';
      case FinancePeriod.week:
        return 'Daily breakdown this week';
      case FinancePeriod.month:
        return 'Daily breakdown this month';
    }
  }
}

class _SummaryGrid extends StatelessWidget {
  final PeriodSummary summary;
  final PeriodSummary? previous;
  final String comparisonLabel;

  const _SummaryGrid({
    required this.summary,
    this.previous,
    this.comparisonLabel = '',
  });

  double? _delta(double current, double prev) {
    if (prev == 0) return null;
    return (current - prev) / prev * 100;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Revenue',
                value: formatPkr(summary.revenue),
                icon: Icons.payments_outlined,
                color: AppColors.sell,
                deltaPercent: _delta(summary.revenue, previous?.revenue ?? 0),
                comparisonLabel: comparisonLabel,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                label: 'Gross Profit',
                value: formatPkr(summary.profit),
                icon: Icons.trending_up,
                color: AppColors.primary,
                deltaPercent: _delta(summary.profit, previous?.profit ?? 0),
                comparisonLabel: comparisonLabel,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Cost of Goods',
                value: formatPkr(summary.costOfGoodsSold),
                icon: Icons.shopping_bag_outlined,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                label: 'Restock Spend',
                value: formatPkr(summary.restockSpend),
                icon: Icons.add_box_outlined,
                color: AppColors.restock,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              _MiniStat(
                label: 'Units sold',
                value: '${summary.unitsSold}',
              ),
              Container(
                width: 1,
                height: 32,
                color: Colors.grey.shade200,
                margin: const EdgeInsets.symmetric(horizontal: 16),
              ),
              _MiniStat(
                label: 'Margin',
                value: '${summary.marginPercent.toStringAsFixed(1)}%',
              ),
              Container(
                width: 1,
                height: 32,
                color: Colors.grey.shade200,
                margin: const EdgeInsets.symmetric(horizontal: 16),
              ),
              _MiniStat(
                label: 'Transactions',
                value: '${summary.transactionCount}',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final double? deltaPercent;
  final String comparisonLabel;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.deltaPercent,
    this.comparisonLabel = '',
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = (deltaPercent ?? 0) >= 0;
    final deltaColor = isPositive ? AppColors.greenDark : AppColors.red;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(label,
              style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (deltaPercent != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 11,
                  color: deltaColor,
                ),
                const SizedBox(width: 2),
                Text(
                  '${isPositive ? '+' : ''}${deltaPercent!.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: deltaColor,
                  ),
                ),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    comparisonLabel,
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.mutedLight),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
      ],
    );
  }
}

class _RevenueProfitChart extends StatelessWidget {
  final List<ChartDataPoint> data;

  const _RevenueProfitChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final hasData = data.any((d) => d.revenue > 0 || d.profit > 0);
    if (!hasData) return const _ChartPlaceholder();

    final maxY = data
        .map((d) => [d.revenue, d.profit].reduce((a, b) => a > b ? a : b))
        .reduce((a, b) => a > b ? a : b);

    return _ChartCard(
      height: 220,
      legend: const [
        _LegendDot(color: AppColors.sell, label: 'Revenue'),
        SizedBox(width: 16),
        _LegendDot(color: AppColors.primary, label: 'Profit'),
      ],
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY * 1.2,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY > 0 ? maxY / 4 : 1,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.grey.shade200,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (value, _) => Text(
                  _compactAmount(value),
                  style: const TextStyle(fontSize: 10, color: AppColors.muted),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: data.length > 10 ? (data.length / 6).ceilToDouble() : 1,
                getTitlesWidget: (value, _) {
                  final index = value.toInt();
                  if (index < 0 || index >= data.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      data[index].label,
                      style: const TextStyle(fontSize: 10, color: AppColors.muted),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            _line(data.map((d) => d.revenue).toList(), AppColors.sell),
            _line(data.map((d) => d.profit).toList(), AppColors.primary),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots.map((spot) {
                final label = spot.barIndex == 0 ? 'Revenue' : 'Profit';
                return LineTooltipItem(
                  '$label\n${formatPkr(spot.y)}',
                  const TextStyle(color: Colors.white, fontSize: 12),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  LineChartBarData _line(List<double> values, Color color) {
    return LineChartBarData(
      spots: [
        for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
      ],
      isCurved: true,
      color: color,
      barWidth: 3,
      dotData: FlDotData(
        show: values.length <= 12,
        getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
          radius: 3,
          color: color,
          strokeWidth: 1,
          strokeColor: Colors.white,
        ),
      ),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha:0.08),
      ),
    );
  }
}

class _RevenueCostChart extends StatelessWidget {
  final List<ChartDataPoint> data;

  const _RevenueCostChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final hasData = data.any((d) => d.revenue > 0 || d.cost > 0);
    if (!hasData) return const _ChartPlaceholder();

    final maxY = data
        .map((d) => [d.revenue, d.cost].reduce((a, b) => a > b ? a : b))
        .reduce((a, b) => a > b ? a : b);

    return _ChartCard(
      height: 220,
      legend: const [
        _LegendDot(color: AppColors.sell, label: 'Revenue'),
        SizedBox(width: 16),
        _LegendDot(color: AppColors.warning, label: 'Costs'),
      ],
      child: BarChart(
        BarChartData(
          minY: 0,
          maxY: maxY * 1.2,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.grey.shade200,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (value, _) => Text(
                  _compactAmount(value),
                  style: const TextStyle(fontSize: 10, color: AppColors.muted),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: data.length > 10 ? (data.length / 6).ceilToDouble() : 1,
                getTitlesWidget: (value, _) {
                  final index = value.toInt();
                  if (index < 0 || index >= data.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      data[index].label,
                      style: const TextStyle(fontSize: 10, color: AppColors.muted),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: [
            for (var i = 0; i < data.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: data[i].revenue,
                    color: AppColors.sell,
                    width: 8,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                  BarChartRodData(
                    toY: data[i].cost,
                    color: AppColors.warning,
                    width: 8,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ],
                barsSpace: 4,
              ),
          ],
        ),
      ),
    );
  }
}

class _TopProductsChart extends StatelessWidget {
  final List<ProductBreakdown> products;

  const _TopProductsChart({required this.products});

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const _ChartPlaceholder(message: 'No sales yet this period');
    }

    final maxRevenue = products.map((p) => p.revenue).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (final product in products) ...[
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    product.itemName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: maxRevenue > 0 ? product.revenue / maxRevenue : 0,
                      minHeight: 8,
                      backgroundColor: AppColors.sell.withValues(alpha:0.12),
                      color: AppColors.sell,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 72,
                  child: Text(
                    formatPkr(product.revenue),
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final SaleTransaction tx;

  const _TransactionTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final isSell = tx.type == TransactionType.sell;
    final color = isSell ? AppColors.sell : AppColors.restock;
    final time = DateFormat('h:mm a').format(tx.timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha:0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isSell ? Icons.point_of_sale : Icons.add_box_outlined,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.itemName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${isSell ? 'Sold' : 'Restocked'} ${tx.quantity} · $time',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isSell ? formatPkr(tx.revenue) : formatPkr(-tx.cost),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isSell ? AppColors.sell : AppColors.restock,
                ),
              ),
              if (isSell)
                Text(
                  '+${formatPkr(tx.profit)} profit',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final Widget child;
  final double height;
  final List<Widget> legend;

  const _ChartCard({
    required this.height,
    required this.legend,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          SizedBox(height: height, child: child),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: legend),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
      ],
    );
  }
}

class _ChartPlaceholder extends StatelessWidget {
  final String message;

  const _ChartPlaceholder({this.message = 'No data for this period yet'});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart_outlined, size: 36, color: AppColors.mutedLight),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _EmptyTransactions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Text(
        'No transactions yet. Sales and restocks will appear here.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.muted),
      ),
    );
  }
}

class _NetProfitCard extends StatelessWidget {
  final double grossProfit;
  final double totalExpenses;

  const _NetProfitCard({required this.grossProfit, required this.totalExpenses});

  @override
  Widget build(BuildContext context) {
    final netProfit = grossProfit - totalExpenses;
    final color = netProfit >= 0 ? AppColors.sell : AppColors.danger;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.account_balance_outlined, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Net Profit',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                const SizedBox(height: 2),
                Text(
                  'Gross Profit − Expenses',
                  style: TextStyle(fontSize: 11, color: AppColors.mutedLight),
                ),
              ],
            ),
          ),
          Text(
            formatPkr(netProfit),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpensesList extends StatelessWidget {
  final List<Expense> expenses;
  final void Function(int id) onDelete;

  const _ExpensesList({required this.expenses, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text(
          'No expenses recorded for this period.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted),
        ),
      );
    }

    return Column(
      children: expenses.map((e) => _ExpenseTile(expense: e, onDelete: onDelete)).toList(),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  final Expense expense;
  final void Function(int id) onDelete;

  const _ExpenseTile({required this.expense, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('d MMM, h:mm a').format(
      DateTime.fromMillisecondsSinceEpoch(expense.timestamp),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.receipt_long_outlined, color: AppColors.danger, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        expense.category,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (expense.note != null && expense.note!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    expense.note!,
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
                const SizedBox(height: 2),
                Text(time, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatPkr(expense.amount),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.danger,
                ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => onDelete(expense.id!),
                child: Icon(Icons.delete_outline, size: 18, color: AppColors.mutedLight),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _compactAmount(double value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}k';
  return value.toStringAsFixed(0);
}

// ── Period tab ─────────────────────────────────────────────────────────────────

class _PeriodTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.ink : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Center(
            child: Text(
              label,
              style: instrument(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? Colors.white : AppColors.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Inventory value card ──────────────────────────────────────────────────────

class _InventoryValueCard extends StatelessWidget {
  final double value;

  const _InventoryValueCard({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Symbols.warehouse,
                size: 22, color: AppColors.greenBright),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Inventory value',
                    style: instrument(
                        fontSize: 12, color: AppColors.inkMuted)),
                const SizedBox(height: 2),
                Text(
                  formatPkr(value),
                  style: mono(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
