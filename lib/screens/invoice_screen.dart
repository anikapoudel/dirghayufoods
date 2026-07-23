import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/order_models.dart';

const String _companyName = 'Dirghayu Bhaba Food';
const String _companyPan = 'PAN: 609932145';
const String _companyAddress = 'Tilottama-3, Rupandehi, 32903';
const String _companyPhone = 'Phone: +977 970-8128686';
const String _companyEmail = 'Email: dirghayu.bhawa@gmail.com';

final PdfColor _ink = PdfColor.fromInt(0xFF1A1A1A);
final PdfColor _grey = PdfColor.fromInt(0xFF6B7280);
final PdfColor _green = PdfColor.fromInt(0xFF1E5038);
final PdfColor _divider = PdfColor.fromInt(0xFFE5E7EB);
final PdfColor _boxBg = PdfColor.fromInt(0xFFF9FAFB);
final PdfColor _paidBg = PdfColor.fromInt(0xFFE9F7EF);
final PdfColor _pendingBg = PdfColor.fromInt(0xFFEDEBFB);
final PdfColor _pendingText = PdfColor.fromInt(0xFF5B4FCF);

String _orderStatusLabel(String status) {
  switch (status.toLowerCase()) {
    case 'pending':
      return 'Order Placed';
    case 'confirmed':
      return 'Payment Confirmed';
    case 'processing':
      return 'Processing';
    case 'shipping':
      return 'Out For Delivery';
    case 'delivered':
      return 'Delivered';
    case 'cancelled':
    case 'cancel':
      return 'Cancelled';
    default:
      return status;
  }
}

bool _isOrderCancelled(String status) {
  final s = status.toLowerCase();
  return s == 'cancelled' || s == 'cancel';
}

bool _isOrderDelivered(String status) => status.toLowerCase() == 'delivered';

class InvoiceScreen extends StatefulWidget {
  final RemoteOrder order;

  final String? Function(String productId)? weightLookup;

  // final pw.Font? devanagariFont;
  final Uint8List? devanagariImageBytes;

  final Uint8List? logoBytes;

  const InvoiceScreen({
    super.key,
    required this.order,
    this.weightLookup,
    // this.devanagariFont,
    this.devanagariImageBytes,
    this.logoBytes,
  });

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  bool _isDownloading = false;

  Future<void> _download() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      final bytes = await _buildPdfBytes(
        widget.order,
        weightLookup: widget.weightLookup,
        devanagariImageBytes: widget.devanagariImageBytes,
        logoBytes: widget.logoBytes,
      );
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'Invoice-${widget.order.orderReference}.pdf',
      );
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.green[900],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Invoice — ${widget.order.orderReference}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _isDownloading ? null : _download,
            icon: _isDownloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download_outlined, color: Colors.white),
            tooltip: 'Download invoice',
          ),
        ],
      ),

      body: LayoutBuilder(
        builder: (context, constraints) {
          return InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            boundaryMargin: const EdgeInsets.all(80),
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: PdfPreviewCustom(
                build: (format) => _buildPdfBytes(
                  widget.order,
                  weightLookup: widget.weightLookup,
                  devanagariImageBytes: widget.devanagariImageBytes,
                  logoBytes: widget.logoBytes,
                ),
                maxPageWidth: constraints.maxWidth,
                previewPageMargin: EdgeInsets.zero,
                padding: EdgeInsets.zero,
                scrollViewDecoration: const BoxDecoration(
                  color: Color(0xFFEDEDED),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

String _formatDate(DateTime dt) {
  final local = dt.toLocal();
  final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final period = local.hour >= 12 ? 'PM' : 'AM';
  final minute = local.minute.toString().padLeft(2, '0');
  final second = local.second.toString().padLeft(2, '0');
  return '${local.month}/${local.day}/${local.year}, $hour12:$minute:$second $period';
}

String _capitalize(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

Future<Uint8List> _buildPdfBytes(
  RemoteOrder order, {
  String? Function(String productId)? weightLookup,
  Uint8List? devanagariImageBytes,
  Uint8List? logoBytes,
}) async {
  final doc = pw.Document();
  final address = order.deliveryAddress;
  final customer = order.customer;
  final subtotal = order.itemsSubtotal;
  final deliveryCharge = order.deliveryCharge;
  final isDeliveryFree = deliveryCharge.abs() < 0.5;

  final logoImage = logoBytes != null ? pw.MemoryImage(logoBytes) : null;
  final devanagariImage = devanagariImageBytes != null
      ? pw.MemoryImage(devanagariImageBytes)
      : null;

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (context) => context.pageNumber == 1
          ? pw.Column(children: [_buildTopBar(), pw.SizedBox(height: 16)])
          : pw.SizedBox(),
      build: (context) => [
        _buildLetterheadRow(
          order,
          devanagariImage: devanagariImage,
          logoImage: logoImage,
        ),
        pw.SizedBox(height: 16),
        pw.Divider(color: _divider, thickness: 1),
        pw.SizedBox(height: 16),
        _buildBilledToAndAddress(customer: customer, address: address),
        pw.SizedBox(height: 20),
        _buildItemsTable(order, weightLookup: weightLookup),
        pw.SizedBox(height: 16),
        pw.Divider(color: _divider, thickness: 1),
        pw.SizedBox(height: 16),
        _buildPaymentAndTotals(
          order: order,
          subtotal: subtotal,
          deliveryCharge: deliveryCharge,
          isFree: isDeliveryFree,
        ),
        pw.SizedBox(height: 32),
        _buildSignatureBlock(),
      ],
    ),
  );

  return doc.save();
}

pw.Widget _buildTopBar() {
  return pw.Container(
    height: 4,
    decoration: pw.BoxDecoration(
      gradient: pw.LinearGradient(
        colors: [_green, PdfColor.fromInt(0xFFD4AF37)],
      ),
    ),
  );
}

pw.Widget _buildLetterheadRow(
  RemoteOrder order, {
  pw.ImageProvider? devanagariImage,
  pw.ImageProvider? logoImage,
}) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        flex: 3,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (logoImage != null)
                  pw.Container(
                    width: 90,
                    height: 46,
                    child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                  )
                else
                  pw.Text(
                    _companyName.split(' ').first,
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: _green,
                    ),
                  ),
                pw.SizedBox(width: 8),
                if (devanagariImage != null) ...[
                  pw.Container(
                    height: 14,
                    child: pw.Image(devanagariImage, fit: pw.BoxFit.contain),
                  ),
                  pw.SizedBox(width: 6),
                ],
                pw.Text(
                  '| $_companyName',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: _green,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              _companyPan,
              style: pw.TextStyle(fontSize: 8.5, color: _grey),
            ),
            pw.Text(
              _companyAddress,
              style: pw.TextStyle(fontSize: 8.5, color: _grey),
            ),
            pw.Text(
              _companyPhone,
              style: pw.TextStyle(fontSize: 8.5, color: _grey),
            ),
            pw.Text(
              _companyEmail,
              style: pw.TextStyle(fontSize: 8.5, color: _grey),
            ),
          ],
        ),
      ),
      pw.Expanded(
        flex: 2,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'TAX INVOICE',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: _ink,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Invoice: DF-INV-${order.orderReference}',
              style: pw.TextStyle(fontSize: 8.5, color: _grey),
            ),
            pw.Text(
              'ID: ${order.orderReference}',
              style: pw.TextStyle(fontSize: 8.5, color: _grey),
            ),
            pw.Text(
              'Date: ${_formatDate(order.createdAt)}',
              style: pw.TextStyle(fontSize: 8.5, color: _grey),
            ),
            pw.SizedBox(height: 6),
            _buildOrderStatusBadge(order.status),
          ],
        ),
      ),
    ],
  );
}

pw.Widget _buildOrderStatusBadge(String status) {
  final isCancelled = _isOrderCancelled(status);
  final isDelivered = _isOrderDelivered(status);
  final bg = isCancelled ? _pendingBg : (isDelivered ? _paidBg : _pendingBg);
  final fg = isCancelled
      ? PdfColor.fromInt(0xFFDC3545)
      : (isDelivered ? _green : _pendingText);

  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: pw.BoxDecoration(
      color: bg,
      border: pw.Border.all(color: fg, width: 0.75),
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Text(
      'ORDER STATUS: ${_orderStatusLabel(status).toUpperCase()}',
      style: pw.TextStyle(
        fontSize: 8,
        fontWeight: pw.FontWeight.bold,
        color: fg,
      ),
    ),
  );
}

pw.Widget _buildBilledToAndAddress({
  OrderCustomer? customer,
  RemoteDeliveryAddress? address,
}) {
  pw.Widget box({required String label, required List<pw.Widget> children}) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: _boxBg,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                color: _grey,
              ),
            ),
            pw.SizedBox(height: 6),
            ...children,
          ],
        ),
      ),
    );
  }

  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      box(
        label: 'BILLED TO:',
        children: [
          pw.Text(
            address?.fullName.isNotEmpty == true
                ? address!.fullName
                : (customer?.name ?? '-'),
            style: pw.TextStyle(
              fontSize: 10.5,
              fontWeight: pw.FontWeight.bold,
              color: _ink,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Phone: ${address?.phone.isNotEmpty == true ? address!.phone : (customer?.phone ?? '-')}',
            style: pw.TextStyle(fontSize: 9, color: _grey),
          ),
        ],
      ),
      pw.SizedBox(width: 14),
      box(
        label: 'DELIVERY ADDRESS:',
        children: [
          if (address != null && !address.isEmpty) ...[
            pw.Text(
              address.line1,
              style: pw.TextStyle(
                fontSize: 9.5,
                fontWeight: pw.FontWeight.bold,
                color: _ink,
              ),
            ),
            pw.Text(
              address.line2,
              style: pw.TextStyle(fontSize: 9.5, color: _ink),
            ),
            pw.Text(
              address.line3,
              style: pw.TextStyle(fontSize: 9.5, color: _ink),
            ),
          ] else
            pw.Text(
              customer?.location ?? '-',
              style: pw.TextStyle(fontSize: 9.5, color: _ink),
            ),
        ],
      ),
    ],
  );
}

pw.Widget _buildItemsTable(
  RemoteOrder order, {
  String? Function(String productId)? weightLookup,
}) {
  final headers = [
    '#',
    'PRODUCT NAME',
    'WEIGHT',
    'PRICE (RS.)',
    'QTY',
    'TOTAL (RS.)',
  ];
  final data = order.items.asMap().entries.map((entry) {
    final index = entry.key + 1;
    final item = entry.value;
    final weight = weightLookup?.call(item.product.id) ?? '-';
    return [
      '$index',
      item.product.name,
      weight,
      item.unitPrice.toStringAsFixed(2),
      '${item.quantity}',
      item.lineTotal.toStringAsFixed(2),
    ];
  }).toList();

  return pw.TableHelper.fromTextArray(
    headers: headers,
    data: data,
    headerStyle: pw.TextStyle(
      fontSize: 8.5,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
    ),
    headerDecoration: pw.BoxDecoration(color: _green),
    headerPadding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
    cellStyle: pw.TextStyle(fontSize: 9.5, color: _ink),
    border: null,
    cellAlignments: {
      0: pw.Alignment.centerLeft,
      1: pw.Alignment.centerLeft,
      2: pw.Alignment.center,
      3: pw.Alignment.centerRight,
      4: pw.Alignment.center,
      5: pw.Alignment.centerRight,
    },
    columnWidths: {
      0: const pw.FlexColumnWidth(0.5),
      1: const pw.FlexColumnWidth(3),
      2: const pw.FlexColumnWidth(1.5),
      3: const pw.FlexColumnWidth(1.5),
      4: const pw.FlexColumnWidth(1),
      5: const pw.FlexColumnWidth(1.5),
    },
    cellHeight: 24,
    cellPadding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
  );
}

pw.Widget _buildPaymentAndTotals({
  required RemoteOrder order,
  required double subtotal,
  required double deliveryCharge,
  required bool isFree,
}) {
  final methodLabel = order.payment.method == 'cash_on_delivery'
      ? 'Cash on Delivery'
      : order.payment.method;

  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        flex: 3,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'PAYMENT INFORMATION',
              style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                color: _grey,
              ),
            ),
            pw.SizedBox(height: 6),
            _metaLine('Method', methodLabel),
            _metaLine('Status', _capitalize(order.payment.status)),
            pw.SizedBox(height: 8),
            pw.Text(
              'Thank you for choosing healthy eating. Keep this invoice for records.',
              style: pw.TextStyle(
                fontSize: 8.5,
                color: _grey,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
      pw.SizedBox(width: 16),
      pw.Expanded(
        flex: 3,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _totalRow('Subtotal', 'Rs. ${subtotal.toStringAsFixed(2)}'),
            pw.SizedBox(height: 4),
            _totalRow(
              'Delivery Charge',
              isFree ? 'FREE' : 'Rs. ${deliveryCharge.toStringAsFixed(2)}',
            ),
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: pw.BoxDecoration(
                color: _paidBg,
                border: pw.Border.all(color: _green, width: 0.75),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: _totalRow(
                'GRAND TOTAL',
                'Rs. ${order.totalPrice.toStringAsFixed(2)}',
                bold: true,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

pw.Widget _metaLine(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 3),
    child: pw.RichText(
      text: pw.TextSpan(
        style: pw.TextStyle(fontSize: 9.5, color: _ink),
        children: [
          pw.TextSpan(
            text: '$label: ',
            style: pw.TextStyle(color: _grey),
          ),
          pw.TextSpan(
            text: value,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    ),
  );
}

pw.Widget _totalRow(String label, String value, {bool bold = false}) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(
        label,
        style: pw.TextStyle(
          fontSize: bold ? 10.5 : 9.5,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: _ink,
        ),
      ),
      pw.Text(
        value,
        style: pw.TextStyle(
          fontSize: bold ? 12 : 9.5,
          fontWeight: pw.FontWeight.bold,
          color: _ink,
        ),
      ),
    ],
  );
}

pw.Widget _buildSignatureBlock() {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          _companyName,
          style: pw.TextStyle(
            fontSize: 10,
            fontStyle: pw.FontStyle.italic,
            fontWeight: pw.FontWeight.bold,
            color: _green,
          ),
        ),
      ),
      pw.SizedBox(height: 7),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.SizedBox(
            width: 140,
            child: pw.Divider(color: _divider, thickness: 1),
          ),
          pw.SizedBox(
            width: 140,
            child: pw.Divider(color: _divider, thickness: 1),
          ),
        ],
      ),
      pw.SizedBox(height: 4),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.SizedBox(
            width: 140,
            child: pw.Text(
              'CUSTOMER SIGNATURE',
              style: pw.TextStyle(fontSize: 8, color: _grey),
            ),
          ),
          pw.SizedBox(
            width: 140,
            child: pw.Text(
              'AUTHORIZED SIGNATORY',
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(fontSize: 8, color: _grey),
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 16),
      pw.Center(
        child: pw.Text(
          'This is a computer-generated tax invoice and does not require a physical signature.',
          style: pw.TextStyle(fontSize: 8.5, color: _grey),
        ),
      ),
    ],
  );
}
