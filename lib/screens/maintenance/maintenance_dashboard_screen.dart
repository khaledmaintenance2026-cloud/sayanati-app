import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/maintenance_analysis.dart';
import '../../services/app_state.dart';
import '../../services/arabic_format.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// صفحة "تحليل الصيانة" — طلب صريح من مسؤول الصيانة (2026-10-03): "كـ إدارة
/// الصيانة أريد صفحة للتحليل — المهام وعمل الفنيين". تعرض إحصائيات عامة عن
/// أوامر العمل (الحالات، التوزيع حسب النوع، الاتجاه الزمني) وأداء كل فني
/// (عدد المهام المُنجزة، متوسط وقت الإنجاز، المهام المفتوحة) خلال فترة
/// زمنية يختارها المستخدم — إما آخر ٣٠ يومًا (افتراضي) أو فترة مخصصة بتاريخ
/// بداية ونهاية. كل الأرقام تُعرض برسوم بيانية (أعمدة) بناءً على تفضيلكم.
///
/// مصدر البيانات: GET /api/maintenance-analysis (راجع
/// routes/maintenanceAnalysis.js على السيرفر) — مقصور على مسؤول الصيانة
/// (ومدير النظام تلقائيًا) فقط؛ الدخول لهذه الشاشة نفسها مقصور بنفس الشرط من
/// maintenance_dashboard_screen.dart (أيقونة "تحليل الصيانة" لا تظهر لغيرهما).
enum _RangeMode { last30, custom }

class MaintenanceAnalysisScreen extends StatefulWidget {
  const MaintenanceAnalysisScreen({super.key});

  @override
  State<MaintenanceAnalysisScreen> createState() => _MaintenanceAnalysisScreenState();
}

class _MaintenanceAnalysisScreenState extends State<MaintenanceAnalysisScreen> {
  _RangeMode _mode = _RangeMode.last30;
  DateTime? _customFrom;
  DateTime? _customTo;
  bool _loading = true;
  String? _error;
  MaintenanceAnalysis? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context.read<AppState>().fetchMaintenanceAnalysis(
            from: _mode == _RangeMode.custom ? _customFrom : null,
            to: _mode == _RangeMode.custom ? _customTo : null,
          );
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذّر تحميل التحليل: $e';
        _loading = false;
      });
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final initial = (isFrom ? _customFrom : _customTo) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _customFrom = picked;
      } else {
        _customTo = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ScreenTopBar(title: 'تحليل الصيانة'),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildRangeSelector(),
            const SizedBox(height: 16),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildRangeSelector() {
    final canApply = _customFrom != null && _customTo != null && !_customFrom!.isAfter(_customTo!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Expanded(
                child: _Segment(
                  label: 'آخر ٣٠ يوم',
                  selected: _mode == _RangeMode.last30,
                  onTap: () {
                    if (_mode == _RangeMode.last30) return;
                    setState(() => _mode = _RangeMode.last30);
                    _load();
                  },
                ),
              ),
              Expanded(
                child: _Segment(
                  label: 'فترة مخصصة',
                  selected: _mode == _RangeMode.custom,
                  onTap: () => setState(() => _mode = _RangeMode.custom),
                ),
              ),
            ],
          ),
        ),
        if (_mode == _RangeMode.custom) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _DateField(label: 'من تاريخ', value: _customFrom, onTap: () => _pickDate(isFrom: true))),
              const SizedBox(width: 10),
              Expanded(child: _DateField(label: 'إلى تاريخ', value: _customTo, onTap: () => _pickDate(isFrom: false))),
            ],
          ),
          const SizedBox(height: 10),
          if (!canApply) ...[
            const Text('اختر تاريخ البداية والنهاية ثم اضغط "تطبيق"', style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
            const SizedBox(height: 8),
          ],
          PrimaryButton(label: 'تطبيق', color: AppColors.maintenance, icon: Icons.check, onPressed: canApply ? _load : null),
        ],
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.maintenance));
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
              const SizedBox(height: 14),
              TextButton(onPressed: _load, child: const Text('إعادة المحاولة')),
            ],
          ),
        ),
      );
    }
    final data = _data;
    if (data == null) return const SizedBox.shrink();
    final s = data.summary;
    final avgLabel = s.avgResolutionMinutes != null ? ArabicFormat.duration(Duration(minutes: s.avgResolutionMinutes!)) : '—';

    return ListView(
      children: [
        InfoNote(
          text: 'الفترة المعروضة: من ${ArabicFormat.date(data.from)} إلى ${ArabicFormat.date(data.to)}',
          color: AppColors.maintenance,
          icon: Icons.date_range_outlined,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            KpiCard(value: ArabicFormat.number(s.total), label: 'إجمالي الأوامر', valueColor: AppColors.maintenance),
            const SizedBox(width: 10),
            KpiCard(value: ArabicFormat.number(s.completed), label: 'مُنجزة', valueColor: AppColors.successText),
            const SizedBox(width: 10),
            KpiCard(value: avgLabel, label: 'متوسط وقت الإصلاح', valueColor: AppColors.maintenance),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            KpiCard(value: ArabicFormat.number(s.open), label: 'مفتوحة حاليًا', valueColor: AppColors.warningText),
            const SizedBox(width: 10),
            KpiCard(value: ArabicFormat.number(s.cancelled), label: 'ملغاة', valueColor: AppColors.textMuted),
            const SizedBox(width: 10),
            KpiCard(value: ArabicFormat.number(data.technicians.length), label: 'عدد الفنيين', valueColor: AppColors.maintenance),
          ],
        ),
        const SizedBox(height: 22),
        const _SectionTitle('الاتجاه الزمني (أوامر مُنشأة مقابل مُنجزة)'),
        const SizedBox(height: 10),
        _TrendChart(points: data.trend, bucket: data.bucket),
        const SizedBox(height: 22),
        const _SectionTitle('توزيع المهام حسب النوع'),
        const SizedBox(height: 10),
        _KindBarChart(summary: s),
        const SizedBox(height: 22),
        const _SectionTitle('أداء الفنيين'),
        const SizedBox(height: 10),
        if (data.technicians.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(14)),
            child: const Text('لا يوجد فنيون مسجّلون بعد', style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
          )
        else
          _TechnicianBarChart(technicians: data.technicians),
        const SizedBox(height: 10),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary));
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Segment({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)] : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: selected ? AppColors.maintenance : AppColors.textMuted),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  const _DateField({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 15, color: AppColors.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value != null ? ArabicFormat.date(value!) : label,
                style: TextStyle(fontSize: 12.5, color: value != null ? AppColors.textPrimary : AppColors.textFaint, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// مخطط أعمدة بسيط (بلا أي حزمة رسم بياني خارجية — بنفس أسلوب التطبيق في
/// inventory_screen.dart: Container عادي لا تبعيات جديدة) لعدد أوامر العمل
/// المُنشأة مقابل المُنجزة لكل نقطة زمنية (يوم أو أسبوع حسب [bucket]، يحدده
/// السيرفر تلقائيًا: أسبوعيًا لو الفترة أطول من ٦٠ يومًا، وإلا يوميًا).
class _TrendChart extends StatelessWidget {
  final List<MaintenanceTrendPoint> points;
  final String bucket;
  const _TrendChart({required this.points, required this.bucket});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(14)),
        child: const Text('لا توجد بيانات كافية خلال هذه الفترة', style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
      );
    }
    final maxVal = points.fold<int>(1, (m, p) => [m, p.created, p.completed].reduce((a, b) => a > b ? a : b));
    // أكثر من ١٤ نقطة يصعب قراءتها كأعمدة منفصلة على شاشة جوال — نعرض آخر ١٤ فقط (الأحدث).
    final shown = points.length > 14 ? points.sublist(points.length - 14) : points;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            bucket == 'week' ? 'البيانات مجمّعة أسبوعيًا (الفترة أطول من ٦٠ يومًا)' : 'البيانات مجمّعة يوميًا',
            style: const TextStyle(fontSize: 10.5, color: AppColors.textFaint),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final p in shown)
                  Expanded(
                    child: Tooltip(
                      message: '${ArabicFormat.date(p.date)}\nأُنشئت: ${ArabicFormat.number(p.created)} — أُنجزت: ${ArabicFormat.number(p.completed)}',
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _bar(p.created, maxVal, AppColors.maintenance.withOpacity(0.28)),
                          const SizedBox(width: 2),
                          _bar(p.completed, maxVal, AppColors.maintenance),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final p in shown)
                Expanded(
                  child: Text(
                    '${ArabicFormat.toEasternDigits(p.date.day)}/${ArabicFormat.toEasternDigits(p.date.month)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 9, color: AppColors.textFaint),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot(AppColors.maintenance.withOpacity(0.28), 'أُنشئت'),
              const SizedBox(width: 16),
              _legendDot(AppColors.maintenance, 'أُنجزت'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bar(int value, int maxVal, Color color) {
    final height = maxVal == 0 ? 0.0 : (value / maxVal) * 95;
    final clamped = value > 0 ? (height < 3 ? 3.0 : height) : 0.0;
    return Container(
      width: 7,
      height: clamped,
      decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
      ],
    );
  }
}

/// توزيع المهام الثلاثي (أعطال طارئة / أعمال وقائية / مهام عامة) كأعمدة
/// أفقية نسبية — نفس أسلوب _CategoryDistributionChart في inventory_screen.dart.
class _KindBarChart extends StatelessWidget {
  final MaintenanceAnalysisSummary summary;
  const _KindBarChart({required this.summary});

  @override
  Widget build(BuildContext context) {
    final entries = [
      MapEntry('أعطال طارئة', summary.emergencyCount),
      MapEntry('أعمال وقائية', summary.preventiveCount),
      MapEntry('مهام عامة', summary.taskCount),
    ];
    final total = summary.emergencyCount + summary.preventiveCount + summary.taskCount;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < entries.length; i++) ...[
            Row(
              children: [
                Expanded(child: Text(entries[i].key, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                const SizedBox(width: 8),
                Text(
                  '${ArabicFormat.number(entries[i].value)} (${total == 0 ? 0 : (entries[i].value * 100 / total).round()}٪)',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LayoutBuilder(
                builder: (context, constraints) => Stack(
                  children: [
                    Container(height: 8, width: constraints.maxWidth, color: AppColors.divider),
                    Container(height: 8, width: constraints.maxWidth * (total == 0 ? 0.0 : entries[i].value / total), color: AppColors.maintenance),
                  ],
                ),
              ),
            ),
            if (i != entries.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

/// أداء الفنيين — شريط أفقي لكل فني بطول يعكس عدد المهام المُنجزة خلال
/// الفترة (نسبةً لأعلى فني أداءً)، مع نص إضافي تحته يوضح متوسط وقت الإنجاز
/// وعدد المهام المفتوحة حاليًا المُسندة له.
class _TechnicianBarChart extends StatelessWidget {
  final List<TechnicianPerformance> technicians;
  const _TechnicianBarChart({required this.technicians});

  @override
  Widget build(BuildContext context) {
    final sorted = [...technicians]..sort((a, b) => b.completedCount.compareTo(a.completedCount));
    final maxVal = sorted.fold<int>(1, (m, t) => t.completedCount > m ? t.completedCount : m);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < sorted.length; i++) ...[
            Row(
              children: [
                Expanded(child: Text(sorted[i].name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                Text('${ArabicFormat.number(sorted[i].completedCount)} مُنجزة', style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LayoutBuilder(
                builder: (context, constraints) => Stack(
                  children: [
                    Container(height: 8, width: constraints.maxWidth, color: AppColors.divider),
                    Container(height: 8, width: constraints.maxWidth * (sorted[i].completedCount / maxVal), color: AppColors.maintenance),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              [
                sorted[i].openCount > 0 ? 'لديه ${ArabicFormat.number(sorted[i].openCount)} مهمة مفتوحة حاليًا' : 'لا توجد مهام مفتوحة حاليًا',
                if (sorted[i].avgResolutionMinutes != null) 'متوسط الإنجاز ${ArabicFormat.duration(Duration(minutes: sorted[i].avgResolutionMinutes!))}',
              ].join(' — '),
              style: const TextStyle(fontSize: 11, color: AppColors.textFaint),
            ),
            if (i != sorted.length - 1) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}
