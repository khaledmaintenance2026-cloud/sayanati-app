import 'package:flutter/material.dart';

import '../../models/leaves.dart';
import '../../services/leaves_service.dart';
import '../../theme/app_theme.dart';
import 'leave_employee_screen.dart';
import 'leaves_widgets.dart';

/// تبويب «الملخص»: أرقام اليوم + قوائم ما يحتاج انتباهًا (متأخرون، إجازات بلا
/// عودة، إجازات قادمة، خارج العمل الآن، وصلوا الحد الأقصى، رقم يحتاج تصحيحًا،
/// موظفون بلا تاريخ تعيين/مباشرة). كل شيء محسوب في السيرفر؛ هنا عرض فقط.
class LeavesSummaryTab extends StatefulWidget {
  const LeavesSummaryTab({super.key});

  @override
  State<LeavesSummaryTab> createState() => _LeavesSummaryTabState();
}

class _LeavesSummaryTabState extends State<LeavesSummaryTab> with AutomaticKeepAliveClientMixin {
  LeaveSummary? _summary;
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    leavesChanged.addListener(_onChanged);
    _load();
  }

  @override
  void dispose() {
    leavesChanged.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await LeavesService.fetchSummary();
      if (!mounted) return;
      setState(() {
        _summary = s;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = leavesErrorText(e);
        _loading = false;
      });
    }
  }

  void _openEmployee(LeaveSummaryItem item) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => LeaveEmployeeScreen(employeeId: item.employeeId, initialName: item.name)),
    );
  }

  // ------------------------------- نصوص الأسطر -------------------------------

  static String _rangeText(LeaveSummaryItem it) {
    final start = it.start;
    if (start == null) return '';
    final expected = it.expected;
    if (expected == null) return 'من ${leaveDateLabel(start)} (بلا تاريخ عودة)';
    return 'من ${leaveDateLabel(start)} إلى ${leaveDateLabel(expected)}';
  }

  static String _upcomingText(LeaveSummaryItem it) {
    final start = it.start;
    final left = it.daysLeft;
    final when = left == null ? '' : (left == 1 ? ' — غدًا' : ' — بعد ${leaveDays(left)}');
    return start == null ? '' : 'تبدأ ${leaveDateLabel(start)}$when';
  }

  static String _lateText(LeaveSummaryItem it) => it.note ?? 'متأخر عن المباشرة';

  static String _noReturnText(LeaveSummaryItem it) {
    final start = it.start;
    final from = start == null ? 'إجازة' : 'إجازة بدأت ${leaveDateLabel(start)}';
    return '$from بلا تاريخ عودة — أدخل العودة أو سجّل المباشرة';
  }

  static String _capText(LeaveSummaryItem it) {
    final a = it.available;
    return a == null ? 'وصل الحد الأقصى' : 'الرصيد ${leaveAmountDays(a)}';
  }

  static String _missingDatesText(LeaveSummaryItem it) => 'أدخل تاريخ التعيين والمباشرة';

  static String _fixNumberText(LeaveSummaryItem it) => 'يجب تصحيح الرقم الوظيفي';

  // ------------------------------- البناء -------------------------------

  Widget _content(LeaveSummary s) {
    final c = s.counts;
    final tiles = <Widget>[
      LeaveStatTile(label: 'إجمالي الموظفين', value: leaveNum(c.employees)),
      LeaveStatTile(label: 'على رأس العمل', value: leaveNum(c.active), valueColor: AppColors.successText),
      LeaveStatTile(label: 'في إجازة الآن', value: leaveNum(c.onLeave), valueColor: AppColors.maintenance),
      LeaveStatTile(
        label: 'متأخرون عن المباشرة',
        value: leaveNum(c.lateCount),
        valueColor: c.lateCount > 0 ? kLeavesDanger : AppColors.textPrimary,
      ),
      LeaveStatTile(label: 'إجازات قادمة', value: leaveNum(c.upcomingLeaves), valueColor: AppColors.warningText),
      LeaveStatTile(
        label: 'وصلوا الحد الأقصى (${leaveNum(s.settings.capDays.round())} يومًا)',
        value: leaveNum(c.atCap),
        valueColor: c.atCap > 0 ? AppColors.warningText : AppColors.textPrimary,
      ),
      LeaveStatTile(
        label: 'بلا تاريخ تعيين/مباشرة',
        value: leaveNum(c.missingDates),
        valueColor: c.missingDates > 0 ? AppColors.warningText : AppColors.textPrimary,
      ),
      LeaveStatTile(
        label: 'إجازة بلا تاريخ عودة',
        value: leaveNum(c.noReturn),
        valueColor: c.noReturn > 0 ? kLeavesDanger : AppColors.textPrimary,
      ),
    ];

    final sections = <Widget>[];
    void addSection(String title, Color color, List<LeaveSummaryItem> items, String Function(LeaveSummaryItem) subtitle) {
      if (items.isEmpty) return;
      sections.add(_SummarySection(title: title, color: color, items: items, subtitle: subtitle, onOpen: _openEmployee));
      sections.add(const SizedBox(height: 14));
    }

    addSection('متأخرون عن المباشرة', kLeavesDanger, s.lateEmployees, _lateText);
    addSection('إجازات بلا تاريخ عودة', kLeavesDanger, s.noReturn, _noReturnText);
    addSection('إجازات قادمة', AppColors.warningText, s.upcoming, _upcomingText);
    addSection('خارج العمل الآن', AppColors.maintenance, s.awayNow, _rangeText);
    addSection('وصل رصيدهم الحد الأقصى', AppColors.warningText, s.atCap, _capText);
    addSection('رقم وظيفي يحتاج تصحيحًا', kLeavesDanger, s.fixNumber, _fixNumberText);
    addSection('موظفون بلا تاريخ تعيين أو مباشرة', AppColors.warningText, s.missingDates, _missingDatesText);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
      children: [
        Text(
          'اليوم: ${leaveDateLabel(s.today)}',
          style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
        ),
        const SizedBox(height: 10),
        LeavesTilesGrid(tiles: tiles),
        const SizedBox(height: 4),
        if (sections.isEmpty)
          const LeavesEmptyState(icon: Icons.check_circle_outline, text: 'لا توجد تنبيهات الآن — كل شيء تحت السيطرة')
        else
          ...sections,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = _summary;
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: kLeavesColor));
    }
    Widget body;
    if (s == null) {
      body = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [LeavesErrorView(message: _error ?? 'تعذّر تحميل الملخص', onRetry: _load)],
      );
    } else {
      body = _content(s);
    }
    return RefreshIndicator(color: kLeavesColor, onRefresh: _load, child: body);
  }
}

/// قسم في الملخص: عنوان + عدد، وبطاقة أسطر (الأولى منها فقط، والباقي بزر «عرض الكل»).
class _SummarySection extends StatefulWidget {
  final String title;
  final Color color;
  final List<LeaveSummaryItem> items;
  final String Function(LeaveSummaryItem) subtitle;
  final ValueChanged<LeaveSummaryItem> onOpen;

  const _SummarySection({
    required this.title,
    required this.color,
    required this.items,
    required this.subtitle,
    required this.onOpen,
  });

  @override
  State<_SummarySection> createState() => _SummarySectionState();
}

class _SummarySectionState extends State<_SummarySection> {
  static const int _limit = 6;
  bool _showAll = false;

  Widget _row(LeaveSummaryItem it) {
    final sub = widget.subtitle(it);
    final number = it.employeeNumber;
    return InkWell(
      onTap: () => widget.onOpen(it),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(it.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  if (sub.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
                  ],
                ],
              ),
            ),
            if (number != null) ...[
              const SizedBox(width: 8),
              Text(leaveEastern(number), style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
            const SizedBox(width: 4),
            const Icon(Icons.chevron_left, size: 20, color: AppColors.textFaint),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final shown = (_showAll || items.length <= _limit) ? items : items.sublist(0, _limit);
    final rows = <Widget>[];
    for (var i = 0; i < shown.length; i++) {
      if (i > 0) rows.add(const Divider(height: 1, color: AppColors.divider));
      rows.add(_row(shown[i]));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: widget.color),
                ),
              ),
              Text(leaveNum(items.length), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: widget.color)),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(14),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: rows),
        ),
        if (items.length > _limit)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() => _showAll = !_showAll),
              style: TextButton.styleFrom(foregroundColor: kLeavesColor),
              child: Text(_showAll ? 'عرض أقل' : 'عرض الكل (${leaveNum(items.length)})'),
            ),
          ),
      ],
    );
  }
}
