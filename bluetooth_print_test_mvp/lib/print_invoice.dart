import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

Future<List<int>> printInvoice() async {
  final profile = await CapabilityProfile.load();
  final generator = Generator(PaperSize.mm72, profile);
  List<int> bytes = [];

  bytes += generator.text(
    'My Store',
    styles: const PosStyles(
        align: PosAlign.center, bold: true, height: PosTextSize.size2),
  );
  bytes += generator.text('1234 Store Address\nCity, State\nPhone: +123456789',
      styles: const PosStyles(align: PosAlign.center));
  bytes += generator.text('Date: 2024-10-29 14:23',
      styles: const PosStyles(align: PosAlign.right));
  bytes += generator.hr();

  bytes += generator.row([
    PosColumn(
        text: 'Item', width: 6, styles: const PosStyles(align: PosAlign.left)),
    PosColumn(
        text: 'Qty', width: 2, styles: const PosStyles(align: PosAlign.center)),
    PosColumn(
        text: 'Price',
        width: 4,
        styles: const PosStyles(align: PosAlign.right)),
  ]);

  bytes += generator.row([
    PosColumn(
        text: 'Apple', width: 6, styles: const PosStyles(align: PosAlign.left)),
    PosColumn(
        text: '2', width: 2, styles: const PosStyles(align: PosAlign.center)),
    PosColumn(
        text: '\$3.00',
        width: 4,
        styles: const PosStyles(align: PosAlign.right)),
  ]);

  bytes += generator.row([
    PosColumn(
        text: 'Banana',
        width: 6,
        styles: const PosStyles(align: PosAlign.left)),
    PosColumn(
        text: '5', width: 2, styles: const PosStyles(align: PosAlign.center)),
    PosColumn(
        text: '\$1.00',
        width: 4,
        styles: const PosStyles(align: PosAlign.right)),
  ]);

  bytes += generator.hr();

  bytes += generator.row([
    PosColumn(
        text: 'Subtotal',
        width: 8,
        styles: const PosStyles(align: PosAlign.right)),
    PosColumn(
        text: '\$8.00',
        width: 4,
        styles: const PosStyles(align: PosAlign.right)),
  ]);
  bytes += generator.row([
    PosColumn(
        text: 'Tax (10%)',
        width: 8,
        styles: const PosStyles(align: PosAlign.right)),
    PosColumn(
        text: '\$0.80',
        width: 4,
        styles: const PosStyles(align: PosAlign.right)),
  ]);

  bytes += generator.text(
    'TOTAL: \$8.80',
    styles: const PosStyles(
      align: PosAlign.right,
      height: PosTextSize.size2,
      bold: true,
    ),
  );

  bytes += generator.feed(1);

  bytes += generator.text(
    'Thank you for shopping with us!',
    styles: const PosStyles(align: PosAlign.center, bold: true),
  );
  bytes += generator.feed(2);
  bytes += generator.cut();

  return bytes;
}
