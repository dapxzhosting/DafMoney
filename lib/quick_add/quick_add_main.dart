import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../core/models/entry_type.dart';
import '../core/services/quick_entry_parser.dart';
import '../core/services/quick_entry_saver.dart';
import '../core/services/sound_service.dart';
import '../core/theme/app_colors.dart';

const _channel = MethodChannel('dafmoney/quick_add');

Future<void> runQuickAdd() async {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorWidget.builder = (details) => Material(
    color: const Color(0xFF7F1D1D),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: SafeArea(
        child: Text(
          'Catat cepat error:\n${details.exceptionAsString()}',
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ),
    ),
  );
  runApp(const QuickAddApp());
}

class QuickAddApp extends StatelessWidget {
  const QuickAddApp({super.key});

  ThemeData _theme(Brightness b) => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      brightness: b,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: const QuickAddScreen(),
    );
  }
}

class QuickAddScreen extends StatefulWidget {
  const QuickAddScreen({super.key});

  @override
  State<QuickAddScreen> createState() => _QuickAddScreenState();
}

class _QuickAddScreenState extends State<QuickAddScreen> {
  final _ctrl = TextEditingController();
  final _speech = SpeechToText();

  EntryType _type = EntryType.expense;
  List<QuickNote> _templates = const [];
  bool _saving = false;
  bool _listening = false;
  bool _done = false;
  String? _message;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _speech.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final args = await _channel.invokeMapMethod<String, dynamic>('getArgs');
      final shared = (args?['text'] as String?)?.trim() ?? '';
      if (shared.isNotEmpty) {
        _type = guessSharedType(shared);
        _ctrl.text = summarizeSharedText(shared);
      } else {
        _type = EntryType.parse(args?['type'] as String?);
      }
      if (mounted) setState(() {});
    } catch (_) {}
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    try {
      final list = await QuickEntrySaver.topNotes(_type, limit: 6);
      if (mounted) setState(() => _templates = list);
    } catch (_) {}
  }

  Future<void> _close() async {
    try {
      await _channel.invokeMethod('close');
    } catch (_) {
      SystemNavigator.pop();
    }
  }

  Future<void> _save([String? override]) async {
    final text = (override ?? _ctrl.text).trim();
    if (_saving || text.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _saving = true;
      _message = null;
    });
    final r = await QuickEntrySaver.save(_type, text);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = !r.ok;
      _message = r.ok ? '${r.title}  ${r.body}' : '${r.title}: ${r.body}';
      _done = r.ok;
    });
    if (r.ok) {
      HapticFeedback.mediumImpact();
      SoundService.playDong();
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await _close();
    }
  }

  Future<void> _toggleMic() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    final ok = await _speech.initialize(
      onStatus: (s) {
        if ((s == 'done' || s == 'notListening') && mounted) {
          setState(() => _listening = false);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _listening = false);
      },
    );
    if (!ok) {
      if (mounted) {
        setState(() {
          _error = true;
          _message = 'Pengenalan suara tidak tersedia / izin mikrofon ditolak.';
        });
      }
      return;
    }
    setState(() {
      _listening = true;
      _message = null;
    });
    await _speech.listen(
      localeId: 'id_ID',
      listenFor: const Duration(seconds: 15),
      pauseFor: const Duration(seconds: 3),
      onResult: (r) {
        if (!mounted) return;
        setState(() {
          _ctrl.text = r.recognizedWords;
          _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isIncome = _type == EntryType.income;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F0D),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _close,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: Material(
                color: cs.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: cs.outlineVariant,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Catat cepat',
                          style: tt.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SegmentedButton<EntryType>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: EntryType.expense,
                              label: Text('Pengeluaran'),
                              icon: Icon(Icons.south_east_rounded),
                            ),
                            ButtonSegment(
                              value: EntryType.income,
                              label: Text('Pemasukan'),
                              icon: Icon(Icons.north_east_rounded),
                            ),
                          ],
                          selected: {_type},
                          onSelectionChanged: (s) {
                            setState(() => _type = s.first);
                            _loadTemplates();
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _ctrl,
                          autofocus: true,
                          textInputAction: TextInputAction.done,
                          textCapitalization: TextCapitalization.sentences,
                          onSubmitted: (_) => _save(),
                          decoration: InputDecoration(
                            hintText: isIncome
                                ? 'mis. gaji 5jt'
                                : 'mis. makan siang 25rb',
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            suffixIcon: IconButton(
                              tooltip: 'Bicara',
                              onPressed: _toggleMic,
                              icon: Icon(
                                _listening
                                    ? Icons.mic_rounded
                                    : Icons.mic_none_rounded,
                                color: _listening ? cs.error : cs.primary,
                              ),
                            ),
                          ),
                        ),
                        if (_templates.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              for (final t in _templates)
                                ActionChip(
                                  label: Text(t.label),
                                  onPressed: _saving
                                      ? null
                                      : () => _save(t.note),
                                ),
                            ],
                          ),
                        ],
                        if (_message != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _message!,
                            style: tt.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: _error ? cs.error : cs.primary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: (_saving || _done) ? null : () => _save(),
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  _done
                                      ? Icons.check_rounded
                                      : Icons.bolt_rounded,
                                ),
                          label: Text(_done ? 'Tersimpan' : 'Simpan'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
