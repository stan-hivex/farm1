import 'dart:typed_data';

/// One-page invoice the business can share. No extra PDF package: this writes
/// a small valid PDF the share sheet can open or print.
Uint8List invoicePdfBytes(Map<String, dynamic> invoice) {
  final customer = invoice['customer'] is Map ? invoice['customer'] as Map : const {};
  final items = ((invoice['items'] as List?) ?? const []).whereType<Map>().toList();
  final lines = <String>[
    'FARM invoice ${invoice['invoice_number'] ?? ''}',
    'Status: ${invoice['status'] ?? ''}',
    'Customer: ${customer['name'] ?? ''}',
    if ((customer['email'] ?? '').toString().isNotEmpty) 'Email: ${customer['email']}',
    'Due: ${invoice['due_date'] ?? ''}',
    'Total: ${invoice['total'] ?? ''} FARM',
    if ((invoice['pay_url'] ?? '').toString().isNotEmpty) 'Pay: ${invoice['pay_url']}',
    '',
    'Items',
    for (final item in items)
      '${item['description'] ?? 'Item'} x${item['quantity'] ?? 1}  ${item['amount'] ?? ''}',
    if ((invoice['notes'] ?? '').toString().isNotEmpty) '',
    if ((invoice['notes'] ?? '').toString().isNotEmpty) 'Notes: ${invoice['notes']}',
  ];
  return _pdfPage(lines);
}

Uint8List _pdfPage(List<String> lines) {
  final commands = StringBuffer('BT\n/F1 12 Tf\n');
  var y = 740;
  for (final line in lines.take(40)) {
    final safe = line.replaceAll('\\', r'\\').replaceAll('(', r'\(').replaceAll(')', r'\)');
    final clipped = safe.length > 90 ? safe.substring(0, 90) : safe;
    commands.writeln('1 0 0 1 48 $y Tm ($clipped) Tj');
    y -= 16;
  }
  commands.write('ET');
  final stream = commands.toString();
  final objects = <String>[
    '1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj\n',
    '2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj\n',
    '3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >> endobj\n',
    '4 0 obj << /Length ${stream.length} >> stream\n$stream\nendstream\nendobj\n',
    '5 0 obj << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> endobj\n',
  ];
  final buffer = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[0];
  for (final object in objects) {
    offsets.add(buffer.length);
    buffer.write(object);
  }
  final xref = buffer.length;
  buffer.write('xref\n0 ${objects.length + 1}\n');
  buffer.write('0000000000 65535 f \n');
  for (var i = 1; i < offsets.length; i++) {
    buffer.write('${offsets[i].toString().padLeft(10, '0')} 00000 n \n');
  }
  buffer.write('trailer << /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF');
  return Uint8List.fromList(buffer.toString().codeUnits);
}
