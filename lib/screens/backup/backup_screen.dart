import 'package:flutter/material.dart';
import '../../services/backup_service.dart';
import '../../services/app_settings.dart';
import '../../utils/formatter.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _loading = false;
  bool _isSignedIn = false;
  String? _userEmail;
  String? _lastBackup;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    await BackupService.instance.tryAutoSignIn();
    final lastBackup = await AppSettings.instance.getLastBackup();
    setState(() {
      _isSignedIn = BackupService.instance.isSignedIn;
      _userEmail = BackupService.instance.currentUser?.email;
      _lastBackup = lastBackup;
      _loading = false;
    });
  }

  Future<void> _signIn() async {
    setState(() => _loading = true);
    final success = await BackupService.instance.signIn();
    final lastBackup = await AppSettings.instance.getLastBackup();
    setState(() {
      _isSignedIn = success;
      _userEmail = BackupService.instance.currentUser?.email;
      _lastBackup = lastBackup;
      _loading = false;
    });
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login Google gagal'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _signOut() async {
    await BackupService.instance.signOut();
    setState(() {
      _isSignedIn = false;
      _userEmail = null;
    });
  }

  Future<void> _backup() async {
    setState(() => _loading = true);
    final result = await BackupService.instance.backup();
    final lastBackup = await AppSettings.instance.getLastBackup();
    setState(() {
      _lastBackup = lastBackup;
      _loading = false;
    });

    if (!mounted) return;
    final msg = switch (result) {
      BackupResult.success => 'Backup berhasil!',
      BackupResult.notSignedIn => 'Login Google terlebih dahulu',
      BackupResult.dbNotFound => 'Database tidak ditemukan',
      BackupResult.error => 'Backup gagal. Cek koneksi internet',
      _ => 'Terjadi kesalahan',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            result == BackupResult.success ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _restore() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restore Data'),
        content: const Text(
          'Data lokal akan ditimpa dengan data dari Google Drive.\n\n'
          'Pastikan kamu sudah backup data terbaru sebelum restore. Lanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Restore', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _loading = true);
    final result = await BackupService.instance.restore();
    setState(() => _loading = false);

    if (!mounted) return;
    final msg = switch (result) {
      BackupResult.success => 'Restore berhasil! Restart app untuk memuat data.',
      BackupResult.notSignedIn => 'Login Google terlebih dahulu',
      BackupResult.noBackupFound => 'Tidak ada backup di Google Drive',
      BackupResult.error => 'Restore gagal. Cek koneksi internet',
      _ => 'Terjadi kesalahan',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            result == BackupResult.success ? Colors.green : Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Backup & Restore',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.purple[700],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Google Account Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.account_circle,
                              size: 40,
                              color: _isSignedIn
                                  ? Colors.green[700]
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isSignedIn ? 'Terhubung' : 'Belum Login',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _isSignedIn
                                          ? Colors.green[700]
                                          : Colors.grey,
                                    ),
                                  ),
                                  if (_userEmail != null)
                                    Text(
                                      _userEmail!,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 13,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: _isSignedIn
                              ? OutlinedButton.icon(
                                  onPressed: _signOut,
                                  icon: const Icon(Icons.logout,
                                      color: Colors.red),
                                  label: const Text(
                                    'Keluar dari Google',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                )
                              : ElevatedButton.icon(
                                  onPressed: _signIn,
                                  icon: const Icon(Icons.login),
                                  label: const Text('Login dengan Google'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                if (_lastBackup != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Backup terakhir: ',
                            style: TextStyle(color: Colors.green[800]),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Backup Button
                _ActionCard(
                  icon: Icons.cloud_upload,
                  color: Colors.purple[700]!,
                  title: 'Backup ke Google Drive',
                  subtitle: 'Upload data ke Google Drive kamu',
                  onTap: _isSignedIn ? _backup : null,
                  disabledMessage: _isSignedIn ? null : 'Login Google dulu',
                ),
                const SizedBox(height: 12),

                // Restore Button
                _ActionCard(
                  icon: Icons.cloud_download,
                  color: Colors.orange[700]!,
                  title: 'Restore dari Google Drive',
                  subtitle: 'Pulihkan data dari backup terakhir',
                  onTap: _isSignedIn ? _restore : null,
                  disabledMessage: _isSignedIn ? null : 'Login Google dulu',
                ),
                const SizedBox(height: 24),

                // Info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue[700], size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Informasi',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• Backup menyimpan semua data produk dan transaksi ke Google Drive.\n'
                        '• Restore akan menimpa semua data lokal dengan data dari Drive.\n'
                        '• Pastikan koneksi internet stabil saat backup/restore.',
                        style: TextStyle(color: Colors.blue[800], fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final String? disabledMessage;

  const _ActionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.disabledMessage,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: enabled
          ? onTap
          : () {
              if (disabledMessage != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(disabledMessage!)),
                );
              }
            },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: enabled ? color : Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.white.withOpacity(0.7)),
          ],
        ),
      ),
    );
  }
}
