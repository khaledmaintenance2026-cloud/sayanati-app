import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/maintenance_report.dart';
import '../../models/work_order_note.dart';
import '../../services/api_client.dart';
import '../../services/arabic_format.dart';
import '../../services/work_order_notes_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// ملاحظات المشرف على مهمة مُسنَدة لفني (طلب 2026-10-07: "عند تحويل مهمة إلى
/// شخص يمكن للمشرف إضافة ملاحظات على المهمة سواء كانت منجزة أو تحت الإنجاز،
/// تُرسل في الجروب وأيضًا للفني").
///
/// - الكتابة ([canAdd]): مسؤول الصيانة والمدير فقط — نفس قيد
///   POST /api/work-orders/:id/notes الملزم على السيرفر.
/// - القراءة: المشرف، والفني المُسنَد للمهمة نفسها.
/// - عند الإرسال يرسل السيرفر الملاحظة بنفسه لجروب الصيانة على واتساب ولكل
///   فني على المهمة (واتساب شخصي + إشعار داخل التطبيق).

/// يفتح نافذة سفلية بملاحظات المهمة (مع مربع الكتابة لو [canAdd]).
Future<void> showWorkOrderNotesSheet(
  BuildContext context,
  MaintenanceReport report, {
  required bool canAdd,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) => _NotesSheetBody(report: report, canAdd: canAdd),
  );
}

class _NotesSheetBody extends StatelessWidget {
  final MaintenanceReport report;
  final bool canAdd;

  const _NotesSheetBody({required this.report, required this.canAdd});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 14),
            const Text('ملاحظات المشرف', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              '${report.equipment} — ${report.line}',
              style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.5),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 14),
            WorkOrderNotesPanel(report: report, canAdd: canAdd, showHeader: false),
          ],
        ),
      ),
    );
  }
}

/// أيقونة/شريحة صغيرة على بطاقة المهمة تفتح نافذة الملاحظات. تعرض العدد لو
/// وُجدت ملاحظات، أو "إضافة ملاحظة" للمشرف حين لا توجد. تُعيد رسم نفسها بعد
/// إغلاق النافذة لتعكس العدد الجديد (الذي تحدّثه [WorkOrderNotesPanel] على
/// نفس كائن [MaintenanceReport]).
class WorkOrderNotesChip extends StatefulWidget {
  final MaintenanceReport report;
  final bool canAdd;

  const WorkOrderNotesChip({super.key, required this.report, required this.canAdd});

  @override
  State<WorkOrderNotesChip> createState() => _WorkOrderNotesChipState();
}

class _WorkOrderNotesChipState extends State<WorkOrderNotesChip> {
  Future<void> _open() async {
    await showWorkOrderNotesSheet(context, widget.report, canAdd: widget.canAdd);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.report.notesCount;
    final has = count > 0;
    final label = has ? 'ملاحظات المشرف (${ArabicFormat.toEasternDigits(count)})' : 'إضافة ملاحظة';
    return InkWell(
      onTap: _open,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: has ? AppColors.maintenance.withOpacity(0.1) : Colors.transparent,
          border: Border.all(color: AppColors.maintenance.withOpacity(has ? 0.35 : 0.5)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(has ? Icons.note_alt : Icons.note_add_outlined, size: 15, color: AppColors.maintenance),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.maintenance),
            ),
          ],
        ),
      ),
    );
  }
}

/// قائمة ملاحظات المهمة (الأحدث أولًا) + مربع كتابة ملاحظة جديدة للمشرف.
/// يحمّل الملاحظات بنفسه من السيرفر عند أول ظهور.
///
/// [showHeader] يعرض عنوان "ملاحظات المشرف" وعدّادها (يُخفى داخل النافذة
/// السفلية لأن لها عنوانها). [hideWhenEmpty] يخفي اللوحة كلها حين لا توجد
/// ملاحظات ولا يملك المستخدم الإضافة (الفني على شاشة مهمته). [maxVisible]
/// يقصر المعروض على آخر N ملاحظة مع زر "عرض الكل". [topGap] مسافة علوية لا
/// تُرسَم إلا حين تظهر اللوحة فعلًا.
class WorkOrderNotesPanel extends StatefulWidget {
  final MaintenanceReport report;
  final bool canAdd;
  final bool showHeader;
  final bool hideWhenEmpty;
  final int? maxVisible;
  final double topGap;

  const WorkOrderNotesPanel({
    super.key,
    required this.report,
    required this.canAdd,
    this.showHeader = true,
    this.hideWhenEmpty = false,
    this.maxVisible,
    this.topGap = 0,
  });

  @override
  State<WorkOrderNotesPanel> createState() => _WorkOrderNotesPanelState();
}

class _WorkOrderNotesPanelState extends State<WorkOrderNotesPanel> with AutomaticKeepAliveClientMixin {
  static const int _maxLength = 1000;

  final TextEditingController _ctrl = TextEditingController();
  List<WorkOrderNote> _notes = <WorkOrderNote>[];
  bool _loading = true;
  bool _sending = false;
  bool _showAll = false;
  String? _error;

  /// خطأ فشل الإرسال — يظهر داخل اللوحة نفسها (وليس SnackBar فقط) لأن
  /// SnackBar يُرسَم خلف النافذة السفلية فلا يراه المستخدم أثناء فتحها.
  String? _sendError;

  /// السيرفر رفض عرض الملاحظات (403): مثل فني أنشأ المهمة بنفسه دون أن يكون
  /// مُسنَدًا لها. للقارئ فقط (لا الكاتب) نُخفي اللوحة بدل عرض خطأ أحمر.
  bool _forbidden = false;

  // نحتفظ بحالة اللوحة (المسودة المكتوبة والملاحظات المحمّلة) حتى لو خرجت من
  // نطاق ListView في شاشة إغلاق المهمة أثناء التمرير.
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load(initial: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool initial = false}) async {
    if (!initial) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final notes = await WorkOrderNotesService.fetch(widget.report.id);
      if (!mounted) return;
      widget.report.notesCount = notes.length;
      setState(() {
        _notes = notes;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      final denied = e is ApiException && e.statusCode == 403;
      setState(() {
        _forbidden = denied && !widget.canAdd;
        _error = '$e';
        _loading = false;
      });
    }
  }

  bool get _canSend => !_sending && _ctrl.text.trim().isNotEmpty;

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;

    // الإرسال يصل فورًا لجروب واتساب كامل ولا يمكن سحبه — نؤكد قبله حتى لا
    // تُرسَل ملاحظة ناقصة بضغطة خاطئة.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إرسال الملاحظة؟', style: TextStyle(fontSize: 15)),
        content: const Text(
          'ستُرسل هذه الملاحظة فورًا إلى جروب الصيانة على واتساب، وإلى كل فني على هذه المهمة '
          '(واتساب وإشعار داخل التطبيق). لا يمكن سحبها بعد الإرسال.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.maintenance, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // نلتقط المهمة قبل الانتظار: لو أُغلقت النافذة والطلب ما زال جاريًا (الملاحظة
    // تُحفظ وتُرسل على أي حال) نُحدّث العدّاد على البطاقة رغم ذلك.
    final report = widget.report;
    setState(() {
      _sending = true;
      _sendError = null;
    });
    try {
      final result = await WorkOrderNotesService.add(report.id, text);
      report.notesCount = result.count;
      if (!mounted) return;
      _ctrl.clear();
      setState(() {
        _notes = <WorkOrderNote>[result.note, ..._notes];
        _sending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت إضافة الملاحظة وإرسالها للجروب والفني')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _sendError = 'تعذّرت إضافة الملاحظة: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // مطلوب لـAutomaticKeepAliveClientMixin
    final canAdd = widget.canAdd;
    if (widget.hideWhenEmpty && !canAdd) {
      // الفني على شاشة مهمته: لا نُظهر شيئًا إلا لو وُجدت ملاحظات فعلًا — فلا
      // وميض مؤشر تحميل ولا قفزة في التخطيط لمهمة بلا ملاحظات.
      if (_forbidden) return const SizedBox.shrink();
      if (_loading && widget.report.notesCount == 0) return const SizedBox.shrink();
      if (!_loading && _error == null && _notes.isEmpty) return const SizedBox.shrink();
    }

    final limit = widget.maxVisible;
    final visible = (limit != null && !_showAll && _notes.length > limit) ? _notes.take(limit).toList() : _notes;
    final hiddenCount = _notes.length - visible.length;

    return Padding(
      padding: EdgeInsets.only(top: widget.topGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showHeader) ...[
            Row(
              children: [
                const Icon(Icons.note_alt_outlined, size: 18, color: AppColors.maintenance),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text('ملاحظات المشرف', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
                ),
                if (_notes.isNotEmpty)
                  StatusPill(
                    label: ArabicFormat.toEasternDigits(_notes.length),
                    color: AppColors.maintenance,
                    background: AppColors.maintenance.withOpacity(0.1),
                  ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4)),
              ),
            )
          else if (_error != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InfoNote(text: 'تعذّر تحميل الملاحظات: $_error', color: const Color(0xFFB3261E), icon: Icons.error_outline),
                TextButton(onPressed: _load, child: const Text('إعادة المحاولة')),
              ],
            )
          else if (_notes.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'لا توجد ملاحظات على هذه المهمة بعد',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
            )
          else
            for (final n in visible)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _NoteCard(note: n),
              ),
          if (hiddenCount > 0)
            TextButton(
              onPressed: () => setState(() => _showAll = true),
              child: Text('عرض كل الملاحظات (${ArabicFormat.toEasternDigits(_notes.length)})'),
            ),
          if (canAdd) ...[
            const SizedBox(height: 4),
            _composer(),
          ],
        ],
      ),
    );
  }

  Widget _composer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'ملاحظة جديدة',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _ctrl,
            enabled: !_sending,
            minLines: 2,
            maxLines: 5,
            inputFormatters: [LengthLimitingTextInputFormatter(_maxLength)],
            onChanged: (_) => setState(() => _sendError = null),
            decoration: InputDecoration(
              hintText: 'اكتب ملاحظتك على هذه المهمة...',
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const InfoNote(
            text: 'تُرسل فورًا لجروب الصيانة على واتساب ولكل فني على المهمة (واتساب + إشعار داخل التطبيق)',
            color: AppColors.maintenance,
            icon: Icons.send_outlined,
          ),
          if (_sendError != null) ...[
            const SizedBox(height: 8),
            InfoNote(text: _sendError!, color: const Color(0xFFB3261E), icon: Icons.error_outline),
          ],
          const SizedBox(height: 10),
          _sending
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(color: AppColors.maintenance),
                  ),
                )
              : PrimaryButton(
                  label: 'إرسال الملاحظة',
                  color: _canSend ? AppColors.maintenance : AppColors.textFaint,
                  icon: Icons.send,
                  onPressed: _canSend ? _send : null,
                ),
        ],
      ),
    );
  }
}

/// بطاقة ملاحظة واحدة: الكاتب + حالة المهمة وقت الكتابة + النص + التاريخ.
class _NoteCard extends StatelessWidget {
  final WorkOrderNote note;

  const _NoteCard({required this.note});

  @override
  Widget build(BuildContext context) {
    final done = note.wasCompleted;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline, size: 15, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  note.authorDisplay,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
              ),
              StatusPill(
                label: note.statusLabel,
                color: done ? AppColors.successText : AppColors.maintenance,
                background: done ? AppColors.successBg : AppColors.maintenance.withOpacity(0.1),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(note.note, style: const TextStyle(fontSize: 13.5, height: 1.6)),
          const SizedBox(height: 6),
          Text(
            ArabicFormat.dateTime(note.createdAt),
            style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
