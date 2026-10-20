import 'package:flutter/material.dart';

import '../../models/mamoul_monitor.dart';
import '../../theme/app_theme.dart';
import 'mamoul_widgets.dart';

/// حسابات إنتاج المكينة من (قطع/دقيقة) و(وزن القطعة بالجرام). دوال خالصة بلا واجهة،
/// يستعملها عدّاد الدقيقة وبطاقات «كم تنتج المكينة» بنفس الأرقام.
class MamoulRateCalc {
  final double ppm;
  final double weightG;

  const MamoulRateCalc(this.ppm, this.weightG);

  double get secPerPiece => 60 / ppm;
  double get piecesPerKg => 1000 / weightG;

  /// كم ثانية يخرج الكيلو الواحد.
  double get secPerKg => piecesPerKg / ppm * 60;
  double get kgPerMin => ppm * weightG / 1000;
  double get kgPerHour => kgPerMin * 60;
  double get piecesPerHour => ppm * 60;
}

/// ثوانٍ → '٨٠٫٦ ثانية'، أو '٣٥٤ ثانية (٥ د ٥٤ ث)' لو تجاوزت دقيقتين.
String mamoulSecondsText(double s) {
  if (s < 120) return '${mamoulNum(s, decimals: 1)} ثانية';
  final whole = s.round();
  return '${mamoulCount(whole)} ثانية (${mamoulCount(whole ~/ 60)} د ${mamoulCount(whole % 60)} ث)';
}

/// '2026-10-20T08:10:00Z' → 'قبل ٣ ساعات' (أو null لو النص غير صالح).
String? mamoulAgoText(String? iso) {
  if (iso == null) return null;
  final t = DateTime.tryParse(iso);
  if (t == null) return null;
  final diff = DateTime.now().difference(t.toLocal());
  if (diff.inMinutes < 1) return 'الآن';
  if (diff.inMinutes < 60) return 'قبل ${mamoulCount(diff.inMinutes)} دقيقة';
  if (diff.inHours < 24) return 'قبل ${mamoulCount(diff.inHours)} ساعة';
  return 'قبل ${mamoulCount(diff.inDays)} يومًا';
}

String _kgPieces(double kg, double pieces) =>
    '${mamoulNum(kg, decimals: 1)} كجم · ${mamoulCount(pieces.round())} قطعة';

/// «كم تنتج المكينة؟»: ثلاث خانات كبيرة (قطع/دقيقة، الكيلو يخرج كل كم ثانية، الإنتاج
/// في الساعة) ثم التفاصيل، ولو عُرفت [workHours] يظهر الإنتاج خلال ساعات العمل.
class MamoulOutputTiles extends StatelessWidget {
  final double piecesPerMin;
  final double weightG;
  final double? workHours;

  /// true = الخانات الثلاث وسطر ساعات العمل فقط (لبطاقات المكائن).
  final bool compact;

  const MamoulOutputTiles({
    super.key,
    required this.piecesPerMin,
    required this.weightG,
    this.workHours,
    this.compact = false,
  });

  Widget _tile(String label, String value, String unit) {
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

  Widget _line(String label, String value, {bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: strong ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: strong ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: strong ? kMamoulColor : AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = MamoulRateCalc(piecesPerMin, weightG);
    final hours = workHours;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tile('القطع في الدقيقة', mamoulNum(c.ppm, decimals: 1), 'قطعة'),
            _tile('الكيلو الواحد يخرج كل', mamoulNum(c.secPerKg, decimals: 1), 'ثانية'),
            _tile('الإنتاج في الساعة', mamoulNum(c.kgPerHour, decimals: 1), 'كجم'),
          ],
        ),
        const SizedBox(height: 10),
        Divider(height: 1, color: AppColors.divider),
        const SizedBox(height: 4),
        if (!compact) ...[
          if (c.secPerKg >= 120) _line('ثواني الكيلو الواحد', mamoulSecondsText(c.secPerKg)),
          _line('ثواني القطعة الواحدة', '${mamoulNum(c.secPerPiece, decimals: 2)} ثانية'),
          _line('عدد القطع في الكيلو', '${mamoulNum(c.piecesPerKg, decimals: 1)} قطعة'),
          _line('الإنتاج في الساعة', _kgPieces(c.kgPerHour, c.piecesPerHour)),
        ] else
          _line('وزن القطعة المحسوب', '${mamoulNum(c.weightG)} جم'),
        if (hours != null)
          _line(
            'في ${mamoulNum(hours, decimals: 1)} ساعة عمل',
            _kgPieces(c.kgPerHour * hours, c.piecesPerHour * hours),
            strong: true,
          ),
      ],
    );
  }
}
