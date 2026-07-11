import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/finance_models.dart';
import '../models/transaction.dart';
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
  FinancePeriod _period = FinancePeriod.today;

  PeriodSummary _summary = const PeriodSummary();
  List<ChartDataPoint> _chartData = [];
  List<ProductBreakdown> _topProducts = [];
  List<SaleTransaction> _transactions = [];
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
    final results = await Future.wait([
      _financeService.getSummaryForPeriod(_period),
      _financeService.getChartData(_period),
      _financeService.getTopProducts(_period),
      _financeService.getTransactions(_period),
      _financeService.getInventoryValue(),
    ]);
    if (!mounted) return;
    setState(() {
      _summary = results[0] as PeriodSummary;
      _chartData = results[1] as List<ChartDataPoint>;
      _topProducts = results[2] as List<ProductBreakdown>;
      _transactions = results[3] as List<SaleTransaction>;
      _inventoryValue = results[4] as double;
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

  Future<void> _exportData() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      await ExportService().exportTransactions(_transactions, _periodExportLabel);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              title: const Text('Cash Flow'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              actions: [
                if (_isExporting)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.share_outlined),
                    tooltip: 'Export CSV',
                    onPressed: _exportData,
                  ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: SegmentedButton<FinancePeriod>(
                  segments: const [
                    ButtonSegment(
                      value: FinancePeriod.today,
                      label: Text('Today'),
                    ),
                    ButtonSegment(
                      value: FinancePeriod.week,
                      label: Text('Week'),
                    ),
                    ButtonSegment(
                      value: FinancePeriod.month,
                      label: Text('Month'),
                    ),
                  ],
                  selected: {_period},
                  onSelectionChanged: (s) => _setPeriod(s.first),
                ),
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _SummaryGrid(summary: _summary),
                    const SizedBox(height: 20),
                    _InventoryValueCard(value: _inventoryValue),
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

  const _SummaryGrid({required this.summary});

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
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                label: 'Profit',
                value: formatPkr(summary.profit),
                icon: Icons.trending_up,
                color: AppColors.primary,
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
            border: Border.all(color: Colors.grey.shade200),
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

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha:0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
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

class _InventoryValueCard extends StatelessWidget {
  final double value;

  const _InventoryValueCard({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF134E4A), AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha:0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.warehouse_outlined, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inventory Value',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha:0.8),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatPkr(value),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Total cost of stock on hand',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha:0.65),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
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
        border: Border.all(color: Colors.grey.shade200),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart_outlined, size: 36, color: Colors.grey.shade400),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: const Text(
        'No transactions yet. Sales and restocks will appear here.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.muted),
      ),
    );
  }
}

String _compactAmount(double value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}k';
  return value.toStringAsFixed(0);
}
