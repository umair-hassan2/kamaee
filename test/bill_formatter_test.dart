import 'package:flutter_test/flutter_test.dart';
import 'package:kamaae/utils/bill_formatter.dart';

void main() {
  final items = [
    BillItem(name: 'Rice 2kg', qty: 3, unitPrice: 90),
    BillItem(name: 'Oil 1L', qty: 2, unitPrice: 180),
  ];

  test('BillItem.total multiplies qty by unitPrice', () {
    final item = BillItem(name: 'Sugar', qty: 4, unitPrice: 60);
    expect(item.total, 240);
  });

  test('format includes all item lines', () {
    final bill = BillFormatter.format(
      items: items,
      total: 630,
      paid: 630,
      balance: 0,
    );
    expect(bill, contains('Rice 2kg'));
    expect(bill, contains('x3'));
    expect(bill, contains('PKR 270'));
    expect(bill, contains('Oil 1L'));
    expect(bill, contains('x2'));
    expect(bill, contains('PKR 360'));
  });

  test('format includes total and paid lines', () {
    final bill = BillFormatter.format(
      items: items,
      total: 630,
      paid: 630,
      balance: 0,
    );
    expect(bill, contains('Total:'));
    expect(bill, contains('PKR 630'));
    expect(bill, contains('Paid:'));
  });

  test('format omits balance line when balance is zero', () {
    final bill = BillFormatter.format(
      items: items,
      total: 630,
      paid: 630,
      balance: 0,
    );
    expect(bill, isNot(contains('Balance on Khata')));
  });

  test('format includes balance line when balance is positive', () {
    final bill = BillFormatter.format(
      items: items,
      total: 630,
      paid: 130,
      balance: 500,
    );
    expect(bill, contains('Balance on Khata: PKR 500'));
  });

  test('format includes customer name when provided', () {
    final bill = BillFormatter.format(
      items: items,
      total: 630,
      paid: 630,
      balance: 0,
      customerName: 'Ahmed Bhai',
    );
    expect(bill, contains('Ahmed Bhai'));
  });

  test('format omits customer line when name is null', () {
    final bill = BillFormatter.format(
      items: items,
      total: 630,
      paid: 630,
      balance: 0,
    );
    expect(bill, isNot(contains('👤')));
  });

  test('format omits customer line when name is empty string', () {
    final bill = BillFormatter.format(
      items: items,
      total: 630,
      paid: 630,
      balance: 0,
      customerName: '',
    );
    expect(bill, isNot(contains('👤')));
  });

  test('format truncates long item names at 14 chars', () {
    final longName = BillItem(name: 'Very Long Product Name Here', qty: 1, unitPrice: 100);
    final bill = BillFormatter.format(
      items: [longName],
      total: 100,
      paid: 100,
      balance: 0,
    );
    expect(bill, contains('Very Long Pro…'));
  });

  test('format includes thank you line', () {
    final bill = BillFormatter.format(
      items: items,
      total: 630,
      paid: 630,
      balance: 0,
    );
    expect(bill, contains('Thank you'));
  });
}
