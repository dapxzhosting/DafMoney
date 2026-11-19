abstract class Validators {
  static final _emailRe = RegExp(r'^[\w.+\-]+@[\w\-]+(\.[\w\-]+)+$');

  static String? name(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Nama wajib diisi';
    if (s.length < 2) return 'Nama terlalu pendek';
    if (s.length > 60) return 'Nama maksimal 60 karakter';
    return null;
  }

  static String? email(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Email wajib diisi';
    if (!_emailRe.hasMatch(s)) return 'Format email tidak valid';
    return null;
  }

  static String? passwordRequired(String? v) {
    if (v == null || v.isEmpty) return 'Kata sandi wajib diisi';
    return null;
  }

  static String? newPassword(String? v) {
    if (v == null || v.isEmpty) return 'Kata sandi wajib diisi';
    if (v.length < 8) return 'Minimal 8 karakter';
    if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) {
      return 'Harus mengandung huruf dan angka';
    }
    return null;
  }

  static String? Function(String?) confirm(String Function() original) {
    return (v) {
      if (v == null || v.isEmpty) return 'Konfirmasi kata sandi wajib diisi';
      if (v != original()) return 'Kata sandi tidak sama';
      return null;
    };
  }
}
