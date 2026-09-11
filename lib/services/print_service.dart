import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../models/transaction.dart';
import 'app_settings.dart';

class PrintService {
  static const int _lineWidth = 32; // 58mm ~32 chars

  static String _center(String text) {
    if (text.length >= _lineWidth) return text;
    final pad = (_lineWidth - text.length) ~/ 2;
    return ' ' * pad + text;
  }

  static String _leftRight(String left, String right) {
    final space = _lineWidth - left.length - right.length;
    if (space <= 0) return '$left $right';
    return left + ' ' * space + right;
  }

  static String _line([String char = '-']) => char * _lineWidth;

  static String _formatCurrency(double amount) {
    final parts = amount.toStringAsFixed(0).split('').reversed.toList();
    final result = <String>[];
    for (int i = 0; i < parts.length; i++) {
      if (i > 0 && i % 3 == 0) result.add('.');
      result.add(parts[i]);
    }
    return 'Rp' + result.reversed.join('');
  }

  static Future<bool> requestBluetoothPermissions() async {
    if (Platform.isAndroid) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      bool allGranted = statuses.values.every((status) => status.isGranted);
      return allGranted;
    }
    return true;
  }

  static Future<List<BluetoothInfo>> getPairedDevices() async {
    try {
      final hasPermission = await requestBluetoothPermissions();
      if (!hasPermission) return [];

      final paired = await PrintBluetoothThermal.pairedBluetooths;
      return paired;
    } catch (e) {
      debugPrint('Error getting paired devices: $e');
      return [];
    }
  }

  static Future<bool> connect(String macAddress) async {
    try {
      return await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
    } catch (e) {
      return false;
    }
  }

  static Future<void> disconnect() async {
    try {
      await PrintBluetoothThermal.disconnect;
    } catch (_) {}
  }

  static Future<bool> get isConnected async {
    try {
      return await PrintBluetoothThermal.connectionStatus;
    } catch (e) {
      return false;
    }
  }

  static Future<String> buildReceipt(Transaction tx) async {
    final info = await AppSettings.instance.getStoreInfo();
    final storeName = info['name'] ?? 'Warung Kasir';
    final storeAddress = info['address'] ?? '';
    final storePhone = info['phone'] ?? '';

    final buffer = StringBuffer();

    buffer.writeln(_center(storeName));
    if (storeAddress.isNotEmpty) {
      buffer.writeln(_center(storeAddress));
    }
    if (storePhone.isNotEmpty) {
      buffer.writeln(_center('Telp: ' + storePhone));
    }
    buffer.writeln(_line('='));

    final dt = DateTime.parse(tx.createdAt);
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year.toString();
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final dateStr = '$day/$month/$year';
    final timeStr = '$hour:$minute';
    
    buffer.writeln('No: ' + tx.invoice);
    buffer.writeln('Tgl: ' + dateStr + '  ' + timeStr);
    buffer.writeln(_line());

    for (final item in tx.items) {
      final name = item.productName.length > _lineWidth
          ? item.productName.substring(0, _lineWidth)
          : item.productName;
      buffer.writeln(name);
      final qtyPrice = '  ' + item.qty.toString() + ' x ' + _formatCurrency(item.price);
      final subtotal = _formatCurrency(item.subtotal);
      buffer.writeln(_leftRight(qtyPrice, subtotal));
    }

    buffer.writeln(_line());

    buffer.writeln(_leftRight('TOTAL', _formatCurrency(tx.total)));
    buffer.writeln(_leftRight('BAYAR', _formatCurrency(tx.paid)));
    buffer.writeln(_leftRight('KEMBALI', _formatCurrency(tx.change)));
    buffer.writeln(_line('='));

    buffer.writeln(_center('Terima kasih!'));
    buffer.writeln(_center('Selamat berbelanja kembali'));
    buffer.writeln('');
    buffer.writeln('');
    buffer.writeln('');

    return buffer.toString();
  }

  static Future<bool> printReceipt(Transaction tx) async {
    try {
      final isConn = await isConnected;
      if (!isConn) return false;

      final receiptText = await buildReceipt(tx);

      final List<int> bytes = [];
      bytes.addAll([0x1B, 0x40]);
      bytes.addAll([0x1B, 0x61, 0x01]);
      bytes.addAll([0x1B, 0x45, 0x01]);

      final textBytes = receiptText.codeUnits;
      bytes.addAll(textBytes);

      bytes.addAll([0x1D, 0x56, 0x42, 0x00]);

      return await PrintBluetoothThermal.writeBytes(bytes);
    } catch (e) {
      debugPrint('PrintService error: $e');
      return false;
    }
  }

  static Future<void> showPrintDialog(BuildContext context, Transaction tx) async {
    final hasPermission = await requestBluetoothPermissions();
    if (!context.mounted) return;
    
    if (!hasPermission) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Izin Bluetooth/Lokasi ditolak. Buka pengaturan aplikasi untuk mengizinkan.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Tampilkan loading ambil perangkat
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Mencari printer Bluetooth...'),
          ],
        ),
      ),
    );

    final devices = await getPairedDevices();
    
    if (!context.mounted) return;
    Navigator.pop(context); // Tutup loading

    if (devices.isEmpty) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Printer Tidak Ditemukan'),
          content: const Text(
            'Tidak ada printer Bluetooth yang ditemukan atau dipasangkan.\n\n'
            'Cara Memasangkan:\n'
            '1. Buka Pengaturan HP > Bluetooth.\n'
            '2. Hidupkan Bluetooth dan Printer kamu.\n'
            '3. Pasangkan (Pair) printer di pengaturan.\n'
            '4. Kembali ke aplikasi ini dan coba lagi.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    String? selectedMac;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pilih Printer'),
        content: StatefulBuilder(
          builder: (ctx2, setState) => SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: devices
                  .map(
                    (d) => RadioListTile<String>(
                      title: Text(d.name),
                      subtitle: Text(d.macAdress),
                      value: d.macAdress,
                      groupValue: selectedMac,
                      onChanged: (v) => setState(() => selectedMac = v),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton.icon(
            onPressed: selectedMac == null ? null : () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.print),
            label: const Text('Print'),
          ),
        ],
      ),
    );

    if (result != true || selectedMac == null || !context.mounted) return;

    final loadingCtx = context;
    showDialog(
      context: loadingCtx,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Menghubungkan printer...'),
          ],
        ),
      ),
    );

    final connected = await connect(selectedMac!);
    if (!loadingCtx.mounted) return;
    Navigator.pop(loadingCtx);

    if (!connected) {
      if (loadingCtx.mounted) {
        ScaffoldMessenger.of(loadingCtx).showSnackBar(
          const SnackBar(
            content: Text('Gagal terhubung ke printer. Pastikan printer hidup.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!loadingCtx.mounted) return;
    showDialog(
      context: loadingCtx,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Mencetak struk...'),
          ],
        ),
      ),
    );

    final success = await printReceipt(tx);
    await disconnect();

    if (!loadingCtx.mounted) return;
    Navigator.pop(loadingCtx);

    ScaffoldMessenger.of(loadingCtx).showSnackBar(
      SnackBar(
        content: Text(success ? 'Struk berhasil dicetak!' : 'Gagal mencetak struk'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }
}