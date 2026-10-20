import 'package:flutter/material.dart';

import '../../models/mamoul_monitor.dart';
import '../../theme/app_theme.dart';
import 'mamoul_output_widgets.dart';
import 'mamoul_rate_counter_sheet.dart';
import 'mamoul_widgets.dart';

/// وزن القطعة الافتراضي (الهدف الأكثر استعمالًا) لو لا قراءة ولا عيّنات للمكينة.
const double kMamoulDefaultPieceWeight = 6.2;

/// ما يُعرض لمكينة: قطع/دقيقة + وزن القطعة + ساعات العمل، ومن أين جاءت الأرقام.
class MamoulMachineOutput {
  final double piecesPerMin;
  final double weightG;
  final double? workHours;
  final String sourceText;

  /// true لو من قراءة العدّاد، false لو تقدير من عيّنات التشغيلات.
  final bool fromCounter;

  const MamoulMachineOutput({
    required this.piecesPerMin,
    required this.weightG,
    required this.workHours,
    required this.sourceText,
    required this.fromCounter,
  });

  /// تلقائي: آخر قراءة عدّاد لو وُجدت، وإلا تقدير من متوسط قطع/دقيقة العيّنات
  /// (ووزن القطعة من متوسط أوزانها). null لو لا شيء من الاثنين.
  static MamoulMachineOutput? of(MamoulMachineComparison c) {
    final r = c.rate;
    if (r != null) {
      final ago = mamoulAgoText(r.at);
      final by = r.by;
      final parts = <String>['آخر قراءة بالعدّاد'];
      if (ago != null) parts.add(ago);
      if (by != null && by.isNotEmpty) parts.add(by);
      return MamoulMachineOutput(
        piecesPerMin: r.piecesPerMin,
        weightG: r.weightG,
        workHours: r.workHours,
        sourceText: parts.join(' · '),
        fromCounter: true,
      );
    }
    final ppm = c.avgPpm;
    if (ppm != null && ppm > 0) {
      final avg = c.avg;
      final double w = (c.pieces > 0 && avg != null && avg > 0) ? avg : kMamoulDefaultPieceWeight;
      return MamoulMachineOutput(
        piecesPerMin: ppm,
        weightG: w,
        workHours: null,
        sourceText: 'تقدير من عيّنات التشغيلات — سجّل قراءة بالعدّاد لرقم أدق',
        fromCounter: false,
      );
    }
    return null;
  }
}

/// يفتح عدّاد الدقيقة لمكينة، ويعيد true لو حُفظت قراءة. وزن القطعة وساعات العمل
/// المقترحة تأتيان تلقائيًا من آخر قراءة أو عيّنات المكينة.
Future<bool> openMamoulRateCounter(
  BuildContext context,
  MamoulMachineComparison c, {
  String? runId,
  double? runHours,
}) async {
  final r = c.rate;
  final double weight;
  final String source;
  if (r != null) {
    weight = r.weightG;
    source = 'من آخر قراءة للمكينة';
  } else if (c.pieces > 0 && c.avg != null && c.avg! > 0) {
    weight = c.avg!;
    source = 'متوسط أوزان عيّنات المكينة';
  } else {
    weight = kMamoulDefaultPieceWeight;
    source = 'الوزن الافتراضي، لا توجد عيّنات للمكينة بعد';
  }
  final done = await showMamoulSheet<bool>(
    context,
    (ctx) => MamoulRateCounterSheet(
      machineId: c.machineId,
      machineLabel: c.machineName,
      defaultWeight: weight,
      weightSource: source,
      defaultHours: r?.workHours ?? runHours,
      runId: runId,
    ),
  );
  return done == true;
}

/// «كم تنتج هذه المكينة؟» — يظهر تلقائيًا من آخر قراءة أو من عيّنات المكينة،
/// وفيه زر لقراءة جديدة بالعدّاد. يُستعمل داخل بطاقة المكينة (مقارنة المكائن)،
/// وأعلى تبويب التحليل في غرفة المكينة.
class MamoulMachineOutputBlock extends StatelessWidget {
  final MamoulMachineComparison machine;

  /// true = عرض مختصر (داخل بطاقة مكينة).
  final bool compact;

  /// تشغيلة تُربط بها القراءة الجديدة (اختياري). التحليل يتحدّث تلقائيًا بعد الحفظ.
  final String? runId;

  const MamoulMachineOutputBlock({super.key, required this.machine, this.compact = false, this.runId});

  @override
  Widget build(BuildContext context) {
    final out = MamoulMachineOutput.of(machine);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kMamoulColor.withOpacity(0.06),
        border: Border.all(color: kMamoulColor.withOpacity(0.25)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.speed, size: 18, color: kMamoulColor),
              const SizedBox(width: 6),
              const Expanded(
                child: Text('كم تنتج المكينة؟', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (out == null)
            const Text(
              'لا توجد قراءة إنتاج لهذه المكينة بعد. اضغط «قراءة بالعدّاد» وعُدّ القطع لدقيقة واحدة، وسيظهر هنا كم تنتج.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.5),
            )
          else ...[
            MamoulOutputTiles(
              piecesPerMin: out.piecesPerMin,
              weightG: out.weightG,
              workHours: out.workHours,
              compact: compact,
            ),
            const SizedBox(height: 6),
            Text(
              out.sourceText,
              style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.5),
            ),
          ],
          const SizedBox(height: 10),
          MamoulOutlineButton(
            label: 'قراءة بالعدّاد (دقيقة)',
            icon: Icons.timer_outlined,
            onPressed: () => openMamoulRateCounter(context, machine, runId: runId),
          ),
        ],
      ),
    );
  }
}
