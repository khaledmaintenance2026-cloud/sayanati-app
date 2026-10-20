import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/mamoul_monitor.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'mamoul_run_sheets.dart' show mamoulPlainNumber;
import 'mamoul_widgets.dart';

/// عدّاد الإنتاج بالدقيقة (تشغيلة المعمول).
///
/// الفني يشغّل مؤقّت دقيقة واحدة، ويعدّ القطع التي تخرج من المكينة خلال هذه
/// الدقيقة، وعند انتهاء المؤقّت يكتب العدد. يمكن أخذ أكثر من قراءة والاعتماد
/// على متوسطها. من القراءة ووزن القطعة يحسب التطبيق:
///  - ثواني القطعة الواحدة وثواني الكيلو الواحد،
///  - الإنتاج في الدقيقة والساعة (قطع وكيلو)،
///  - الإنتاج المتوقع (ساعة / وردية / ٢٤ ساعة) بنسبة تشغيل فعلي يحددها المستخدم،
///  - الوقت اللازم لإنتاج كمية مطلوبة بالكيلو.
/// الزر «تسجيل في عيّنة» يعيد متوسط القطع/دقيقة (عبر Navigator.pop) فتُفتح نافذة
/// العيّنة وفيها القيمة مكتوبة، فيدخل الرقم في تحليل السرعات.
class MamoulRateCounterSheet extends StatefulWidget {
  final MamoulRun run;

  const MamoulRateCounterSheet({super.key, required this.run});

  @override
  State<MamoulRateCounterSheet> createState() => _MamoulRateCounterSheetState();
}

enum _Phase { idle, running, finished }

/// الحسابات الأساسية من (قطع/دقيقة) و(وزن القطعة بالجرام).
class _RateCalc {
  final double ppm;
  final double weightG;

  const _RateCalc(this.ppm, this.weightG);

  double get secPerPiece => 60 / ppm;
  double get piecesPerKg => 1000 / weightG;
  double get secPerKg => piecesPerKg / ppm * 60;
  double get kgPerMin => ppm * weightG / 1000;
  double get kgPerHour => kgPerMin * 60;
  double get piecesPerHour => ppm * 60;
}

class _MamoulRateCounterSheetState extends State<MamoulRateCounterSheet> {
  static const int _windowSeconds = 60;
  static const int _maxReadings = 10;

  final TextEditingController _count = TextEditingController();
  final FocusNode _countFocus = FocusNode();
  final TextEditingController _weight = TextEditingController();
  final TextEditingController _eff = TextEditingController(text: '100');
  final TextEditingController _hours = TextEditingController(text: '8');
  final TextEditingController _qty = TextEditingController();
  final List<double> _readings = <double>[];

  Timer? _ticker;
  DateTime? _endAt;
  _Phase _phase = _Phase.idle;
  int _shownSeconds = _windowSeconds;
  int _remainingMs = _windowSeconds * 1000;
  String? _error;
  bool _weightFromSamples = false;

  @override
  void initState() {
    super.initState();
    final summary = widget.run.summary;
    final avg = summary.stats.avg;
    if (summary.samplesCount > 0 && avg != null && avg > 0) {
      _weight.text = mamoulPlainNumber(double.parse(avg.toStringAsFixed(2)));
      _weightFromSamples = true;
    } else {
      _weight.text = mamoulPlainNumber(widget.run.targetWeight);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _count.dispose();
    _countFocus.dispose();
    _weight.dispose();
    _eff.dispose();
    _hours.dispose();
    _qty.dispose();
    super.dispose();
  }

  // ------------------------------- المؤقّت -------------------------------

  void _start() {
    _ticker?.cancel();
    setState(() {
      _error = null;
      _phase = _Phase.running;
      _remainingMs = _windowSeconds * 1000;
      _shownSeconds = _windowSeconds;
      _endAt = DateTime.now().add(const Duration(seconds: _windowSeconds));
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) => _tick());
  }

  void _tick() {
    final end = _endAt;
    if (end == null || !mounted) return;
    final left = end.difference(DateTime.now()).inMilliseconds;
    if (left <= 0) {
      _ticker?.cancel();
      _ticker = null;
      setState(() {
        _remainingMs = 0;
        _shownSeconds = 0;
        _phase = _Phase.finished;
      });
      _alert();
      _countFocus.requestFocus();
      return;
    }
    final shown = (left + 999) ~/ 1000;
    _remainingMs = left;
    if (shown != _shownSeconds) {
      setState(() => _shownSeconds = shown);
    }
  }

  void _cancel() {
    _ticker?.cancel();
    _ticker = null;
    setState(() {
      _phase = _Phase.idle;
      _remainingMs = _windowSeconds * 1000;
      _shownSeconds = _windowSeconds;
      _endAt = null;
    });
  }

  /// اهتزاز (وصوت حيث يدعمه الجهاز) ثلاث مرات عند انتهاء الدقيقة.
  Future<void> _alert() async {
    for (var i = 0; i < 3; i++) {
      try {
        await HapticFeedback.vibrate();
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {
        // الأجهزة التي لا تدعم الاهتزاز/الصوت تكتفي بتغيّر الشاشة.
      }
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;
    }
  }

  // ------------------------------- القراءات -------------------------------

  void _addReading() {
    if (_phase == _Phase.running) {
      setState(() => _error = 'انتظر حتى تنتهي الدقيقة ثم اكتب العدد');
      return;
    }
    final v = mamoulParseNumber(_count.text);
    if (v == null || !v.isFinite || v <= 0 || v > 5000) {
      setState(() => _error = 'اكتب عدد القطع التي عددتها خلال الدقيقة (رقم أكبر من صفر)');
      return;
    }
    if (_readings.length >= _maxReadings) {
      setState(() => _error = 'الحد الأقصى ${mamoulCount(_maxReadings)} قراءات — احذف قراءة قديمة أولًا');
      return;
    }
    setState(() {
      _readings.add(v);
      _count.clear();
      _error = null;
      _phase = _Phase.idle;
      _remainingMs = _windowSeconds * 1000;
      _shownSeconds = _windowSeconds;
      _endAt = null;
    });
  }

  double? get _avgPpm {
    if (_readings.isEmpty) return null;
    var sum = 0.0;
    for (final r in _readings) {
      sum += r;
    }
    return sum / _readings.length;
  }

  double? get _weightG {
    final v = mamoulParseNumber(_weight.text);
    if (v == null || !v.isFinite || v < 0.1 || v > 500) return null;
    return v;
  }

  /// نسبة التشغيل الفعلي كنسبة (٠–١]، أو null لو القيمة غير صالحة.
  double? get _effFraction {
    final v = mamoulParseNumber(_eff.text);
    if (v == null || !v.isFinite || v <= 0 || v > 100) return null;
    return v / 100;
  }

  double? get _shiftHours {
    final v = mamoulParseNumber(_hours.text);
    if (v == null || !v.isFinite || v < 0.5 || v > 24) return null;
    return v;
  }

  double? get _targetKg {
    final v = mamoulParseNumber(_qty.text);
    if (v == null || !v.isFinite || v <= 0 || v > 1000000) return null;
    return v;
  }

  // ------------------------------- نصوص العرض -------------------------------

  String _clock(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return mamoulTimeLabel('${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}');
  }

  /// ثوانٍ → '٨٠٫٦ ثانية' أو '٣٥٤ ثانية (٥ د ٥٤ ث)' لو تجاوزت دقيقتين.
  String _secondsText(double s) {
    if (s < 120) return '${mamoulNum(s, decimals: 1)} ثانية';
    final whole = s.round();
    final m = whole ~/ 60;
    final r = whole % 60;
    return '${mamoulCount(whole)} ثانية (${mamoulCount(m)} د ${mamoulCount(r)} ث)';
  }

  String _durationText(int minutes) {
    if (minutes <= 0) return '—';
    if (minutes >= 1440) {
      final d = minutes ~/ 1440;
      final rest = minutes % 1440;
      return rest == 0 ? '${mamoulCount(d)} يوم' : '${mamoulCount(d)} يوم ${mamoulDuration(rest)}';
    }
    return mamoulDuration(minutes);
  }

  String _finishClock(int minutes) {
    final now = DateTime.now();
    final end = now.add(Duration(minutes: minutes));
    final t = mamoulTimeLabel(mamoulTimeOf(TimeOfDay.fromDateTime(end)));
    final days = DateTime(end.year, end.month, end.day).difference(DateTime(now.year, now.month, now.day)).inDays;
    if (days <= 0) return t;
    return days == 1 ? '$t (غدًا)' : '$t (بعد ${mamoulCount(days)} أيام)';
  }

  String _kgPieces(double kg, double pieces) =>
      '${mamoulNum(kg, decimals: 1)} كجم · ${mamoulCount(pieces.round())} قطعة';

  // ------------------------------- الواجهة -------------------------------

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)),
          ),
        ),
        const SizedBox(height: 14),
        const Text('عدّاد الإنتاج بالدقيقة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text(
          'اضغط «ابدأ» وعُدّ القطع التي تخرج من المكينة طوال دقيقة. عند انتهاء المؤقّت اكتب العدد، فيحسب التطبيق ثواني الكيلو والإنتاج في الساعة والإنتاج المتوقع.',
          style: TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.5),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _timerCard() {
    final running = _phase == _Phase.running;
    final finished = _phase == _Phase.finished;
    final secs = finished ? 0 : (running ? _shownSeconds : _windowSeconds);
    final Color color = finished ? AppColors.successText : (running ? kMamoulColor : AppColors.textSecondary);
    final double progress = finished ? 1.0 : (running ? 1 - (_remainingMs / (_windowSeconds * 1000)) : 0.0);
    final String hint = finished
        ? 'انتهت الدقيقة — اكتب عدد القطع التي عددتها في الخانة أدناه'
        : (running ? 'عُدّ القطع الآن...' : 'اضغط «ابدأ العدّ» ثم عُدّ القطع التي تخرج من المكينة');

    return MamoulCard(
      borderColor: finished ? AppColors.successText : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text(
              _clock(secs),
              textDirection: TextDirection.ltr,
              style: TextStyle(fontSize: 54, fontWeight: FontWeight.bold, color: color),
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0).toDouble(),
              minHeight: 8,
              color: color,
              backgroundColor: AppColors.divider,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: finished ? AppColors.successText : AppColors.textMuted, height: 1.5),
          ),
          const SizedBox(height: 12),
          if (_phase == _Phase.idle)
            PrimaryButton(label: 'ابدأ العدّ (دقيقة واحدة)', color: kMamoulColor, icon: Icons.play_arrow, onPressed: _start)
          else if (running)
            MamoulOutlineButton(label: 'إلغاء', icon: Icons.stop, color: kMamoulDanger, onPressed: _cancel)
          else
            MamoulOutlineButton(label: 'إعادة الدقيقة', icon: Icons.replay, onPressed: _start),
        ],
      ),
    );
  }

  Widget _readingInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MamoulFieldLabel('عدد القطع التي خرجت خلال الدقيقة'),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _count,
                focusNode: _countFocus,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.right,
                onSubmitted: (_) => _addReading(),
                decoration: fieldDecoration(hint: 'مثال: ١٢٠'),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _addReading,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kMamoulColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                ),
                child: const Text('اعتماد القراءة', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'يُفضَّل أخذ قراءتين أو ثلاث (دقيقة بعد دقيقة) والاعتماد على متوسطها، لأن الإنتاج يتذبذب قليلًا.',
          style: TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.5),
        ),
        if (_readings.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (var i = 0; i < _readings.length; i++)
                Chip(
                  label: Text('${mamoulCount(i + 1)}: ${mamoulNum(_readings[i], decimals: 1)}'),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () => setState(() => _readings.removeAt(i)),
                ),
            ],
          ),
          const Text('اضغط ✕ لحذف قراءة', style: TextStyle(fontSize: 11, color: AppColors.textFaint)),
        ],
      ],
    );
  }

  Widget _field(String label, TextEditingController c, String hint) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MamoulFieldLabel(label),
          MamoulNumberField(controller: c, hint: hint, onChanged: (_) => setState(() {})),
        ],
      ),
    );
  }

  Widget _inputs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MamoulSectionTitle('بيانات الحساب'),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field('وزن القطعة (جرام)', _weight, 'مثال: ٦٫٢'),
            const SizedBox(width: 10),
            _field('كمية مطلوبة (كجم) — اختياري', _qty, 'مثال: ٥٠٠'),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _weightFromSamples
              ? 'الوزن مأخوذ من متوسط عيّنات هذه التشغيلة، وتقدر تعدّله.'
              : 'الوزن مأخوذ من الوزن المستهدف للتشغيلة (لا عيّنات بعد)، وتقدر تعدّله.',
          style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.5),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field('ساعات الوردية', _hours, 'مثال: ٨'),
            const SizedBox(width: 10),
            _field('نسبة التشغيل الفعلي (٪)', _eff, 'مثال: ٨٥'),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'المكينة تتوقف أحيانًا (تغيير عجينة، تنظيف، عطل). اكتب النسبة التي تعمل فيها فعليًا ليكون التوقع أقرب للواقع؛ اتركها ١٠٠ لو تعمل بلا توقف.',
          style: TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.5),
        ),
      ],
    );
  }

  Widget _bigTile(String label, String value, String unit) {
    return Expanded(
      child: Column(
        children: [
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kMamoulColor)),
          Text(unit, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _results(_RateCalc c) {
    final n = _readings.length;
    double? lo;
    double? hi;
    for (final r in _readings) {
      lo = (lo == null || r < lo) ? r : lo;
      hi = (hi == null || r > hi) ? r : hi;
    }
    final spread = (n >= 2 && lo != null && hi != null) ? (hi - lo) / c.ppm : 0.0;

    return MamoulCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MamoulSectionTitle(n > 1 ? 'نتيجة العدّاد (متوسط ${mamoulCount(n)} قراءات)' : 'نتيجة العدّاد'),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _bigTile('القطع في الدقيقة', mamoulNum(c.ppm, decimals: 1), 'قطعة'),
              _bigTile('الكيلو الواحد يخرج كل', mamoulNum(c.secPerKg, decimals: 1), 'ثانية'),
              _bigTile('الإنتاج في الساعة', mamoulNum(c.kgPerHour, decimals: 1), 'كجم'),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 6),
          _line('ثواني الكيلو الواحد', _secondsText(c.secPerKg)),
          _line('ثواني القطعة الواحدة', '${mamoulNum(c.secPerPiece, decimals: 2)} ثانية'),
          _line('عدد القطع في الكيلو', '${mamoulNum(c.piecesPerKg, decimals: 1)} قطعة'),
          _line('الإنتاج في الدقيقة', '${mamoulNum(c.kgPerMin, decimals: 2)} كجم'),
          _line('الإنتاج في الساعة', _kgPieces(c.kgPerHour, c.piecesPerHour)),
          if (n >= 2 && lo != null && hi != null) ...[
            const SizedBox(height: 8),
            if (spread > 0.10)
              InfoNote(
                text:
                    'القراءات متباعدة (من ${mamoulNum(lo, decimals: 1)} إلى ${mamoulNum(hi, decimals: 1)}). أعد الدقيقة مرة أو مرتين لتكون النتيجة أدقّ.',
                color: AppColors.warningText,
                icon: Icons.warning_amber_rounded,
              )
            else
              Text(
                'القراءات متقاربة (من ${mamoulNum(lo, decimals: 1)} إلى ${mamoulNum(hi, decimals: 1)}).',
                style: const TextStyle(fontSize: 12, color: AppColors.successText),
              ),
          ],
        ],
      ),
    );
  }

  Widget _projection(_RateCalc c) {
    final eff = _effFraction;
    final hours = _shiftHours;
    if (eff == null || hours == null) {
      return const InfoNote(
        text: 'لإظهار الإنتاج المتوقع: اكتب نسبة تشغيل بين ١ و١٠٠، وساعات وردية بين ٠٫٥ و٢٤.',
        color: AppColors.warningText,
        icon: Icons.info_outline,
      );
    }
    final kgPerHourEff = c.kgPerHour * eff;
    final piecesPerHourEff = c.piecesPerHour * eff;
    final qty = _targetKg;
    final effPct = (eff * 100);

    return MamoulCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MamoulSectionTitle('الإنتاج المتوقع'),
          const SizedBox(height: 4),
          Text(
            'على افتراض أن المكينة تبقى على هذه السرعة وتعمل ${mamoulNum(effPct, decimals: 0)}٪ من الوقت.',
            style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.5),
          ),
          const SizedBox(height: 8),
          _line('خلال ساعة', _kgPieces(kgPerHourEff, piecesPerHourEff)),
          _line('خلال الوردية (${mamoulNum(hours, decimals: 1)} ساعة)', _kgPieces(kgPerHourEff * hours, piecesPerHourEff * hours)),
          _line('خلال ٢٤ ساعة', _kgPieces(kgPerHourEff * 24, piecesPerHourEff * 24)),
          if (qty != null) ...[
            const SizedBox(height: 6),
            Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 6),
            Builder(
              builder: (_) {
                final minutes = (qty / kgPerHourEff * 60).ceil();
                final shifts = qty / (kgPerHourEff * hours);
                return Column(
                  children: [
                    _line('لإنتاج ${mamoulNum(qty, decimals: 1)} كجم يلزم', _durationText(minutes)),
                    _line('أي نحو', '${mamoulNum(shifts, decimals: 1)} وردية'),
                    if (minutes < 60 * 24 * 30) _line('لو بدأت الآن ينتهي الساعة', _finishClock(minutes)),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ppm = _avgPpm;
    final w = _weightG;
    final calc = (ppm != null && w != null) ? _RateCalc(ppm, w) : null;
    final run = widget.run;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _header(),
        _timerCard(),
        const SizedBox(height: 14),
        _readingInput(),
        const SizedBox(height: 14),
        _inputs(),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(fontSize: 13, color: kMamoulDanger, height: 1.5)),
        ],
        const SizedBox(height: 14),
        if (calc == null)
          InfoNote(
            text: ppm == null
                ? 'بعد أول دقيقة اكتب العدد واضغط «اعتماد القراءة» لتظهر الحسابات هنا.'
                : 'اكتب وزن القطعة بالجرام (بين ٠٫١ و٥٠٠) لتظهر الحسابات.',
            color: AppColors.textMuted,
            icon: Icons.hourglass_empty,
          )
        else ...[
          _results(calc),
          const SizedBox(height: 12),
          _projection(calc),
        ],
        const SizedBox(height: 16),
        if (run.isOpen)
          PrimaryButton(
            label: 'تسجيل القراءة في عيّنة',
            color: kMamoulColor,
            icon: Icons.scale_outlined,
            onPressed: ppm == null ? null : () => Navigator.of(context).pop(ppm),
          )
        else
          const InfoNote(
            text: 'التشغيلة مغلقة، فالعدّاد هنا للحساب فقط. أعد فتحها إن أردت تسجيل القراءة في عيّنة.',
            color: AppColors.textMuted,
            icon: Icons.lock_outline,
          ),
        if (run.isOpen) ...[
          const SizedBox(height: 4),
          const Text(
            'يفتح نافذة العيّنة وفيها «القطع في الدقيقة» مكتوبة، فتضيف أوزان القطع وتحفظ، ويدخل الرقم في تحليل السرعات.',
            style: TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.5),
          ),
        ],
        const SizedBox(height: 8),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إغلاق')),
      ],
    );
  }
}
