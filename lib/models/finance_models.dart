class PeriodSummary {
  final double revenue;
  final double profit;
  final double costOfGoodsSold;
  final double restockSpend;
  final int unitsSold;
  final int transactionCount;

  const PeriodSummary({
    this.revenue = 0,
    this.profit = 0,
    this.costOfGoodsSold = 0,
    this.restockSpend = 0,
    this.unitsSold = 0,
    this.transactionCount = 0,
  });

  double get marginPercent => revenue > 0 ? (profit / revenue) * 100 : 0;
}

class ChartDataPoint {
  final String label;
  final double revenue;
  final double profit;
  final double cost;

  const ChartDataPoint({
    required this.label,
    this.revenue = 0,
    this.profit = 0,
    this.cost = 0,
  });
}

class ProductBreakdown {
  final String itemName;
  final double revenue;
  final double profit;
  final int quantity;

  const ProductBreakdown({
    required this.itemName,
    required this.revenue,
    required this.profit,
    required this.quantity,
  });
}

enum FinancePeriod { today, week, month }
