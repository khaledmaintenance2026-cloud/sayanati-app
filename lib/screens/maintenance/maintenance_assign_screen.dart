import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/maintenance_report.dart';
import '../../models/technician.dart';
import '../../services/app_state.dart';
import '../../services/work_order_notes_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class MaintenanceAssignScreen extends StatefulWidget {
  final MaintenanceReport report;
  const MaintenanceAssignScreen({super.key, required this.report});

  @override
  State<MaintenanceAssignScreen> createState() => _MaintenanceAssignScreenState();
}

class _MaintenanceAssignScreenState extends State<MaintenanceAssignScreen> {
  // يدعم النظام الآن تعيين أكثر من فني لنفس البلاغ — راجع
  // work_order_technicians على السيرفر وservices/notifications.js حيث تصل
  // رسالة واتساب الإنجاز بأسماء كل الفنيين معًا.
  //
  // هذه الشاشة نفسها تُستخدم الآن لحالتين: التعيين الأولي (البلاغ بلا أي فني
  // بعد) أو إضافة فني/فنيين إضافيين لبلاغ سبق تعيين فني له وهو قيد التنفيذ
  // (راجع زر "إضافة فني" في maintenance_task_close_screen.dart وبطاقة البلاغ
  // في maintenance_dashboard_screen.dart). التمييز بين الحالتين هنا آليًا عبر
  // technicianDisplayNames: الفني/الفنيون المُسندون سابقًا يظهرون أصلًا
  // "غير متاح" في القائمة أدناه (technician.available صار false منذ تعيينهم)
  // فلا يقدر أحد إلغاء تعيينهم عرضًا من هذه الشاشة — الاختيار هنا يضيف فقط.
  final Set<String> _selectedIds = {};
  bool _submitting = false;

  /// ملاحظة المشرف الاختيارية للفني (طلب 2026-10-07: "من المفروض كتابة
  /// الملاحظات أثناء التعيين وتندمج مع رسالة الواتساب والخاص في التعيين").
  /// تُرسَل مع طلب التعيين نفسه فتصل ضمن رسالة التعيين لجروب الصيانة
  /// وللفني، وتُحفظ في سجل ملاحظات المهمة.
  final TextEditingController _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  bool get _isAdding => widget.report.technicianDisplayNames != '—';

  Future<void> _assign() async {
    final note = _noteCtrl.text.trim();
    final state = context.read<AppState>();
    setState(() => _submitting = true);
    try {
      if (note.isEmpty) {
        // بلا ملاحظة: المسار القديم نفسه تمامًا (بلا أي تغيير في السلوك).
        await state.assignTechnicians(widget.report.id, _selectedIds.toList());
      } else {
        await WorkOrderNotesService.assignWithNote(widget.report.id, _selectedIds.toList(), note);
        // التعيين تمّ على السيرفر — نحدّث قائمة المهام والفنيين محليًا (يتولى
        // كل منهما التقاط أخطائه الداخلية بنفسه فلا يرميان هنا).
        await Future.wait([state.reloadWorkOrders(), state.reloadTechnicians()]);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر تعيين الفني: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final selectedNames = state.technicians
        .where((t) => _selectedIds.contains(t.id))
        .map((t) => t.name)
        .join('، ');

    return Scaffold(
      appBar: ScreenTopBar(title: _isAdding ? 'إضافة فني' : 'تعيين فني'),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // عند ظهور لوحة المفاتيح (كتابة ملاحظة) نُخفي بطاقة البلاغ وعنوان القائمة
            // مؤقتًا لتبقى مساحة كافية للقائمة ومربع الكتابة على الشاشات الصغيرة.
            if (!keyboardOpen) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.maintenance.withOpacity(0.06),
                  border: Border.all(color: AppColors.maintenance.withOpacity(0.16)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('${widget.report.equipment} — ${widget.report.line}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.maintenance)),
                        ),
                        const StatusPill(label: 'بلاغ طارئ', color: AppColors.warningText, background: AppColors.warningBg),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(widget.report.description, style: const TextStyle(fontSize: 13.5, height: 1.5, color: Color(0xFF3A4250))),
                    const SizedBox(height: 6),
                    Text('رُفع بواسطة ${widget.report.reportedBy}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    if (_isAdding) ...[
                      const SizedBox(height: 6),
                      Text('مُسنَد حاليًا إلى: ${widget.report.technicianDisplayNames}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.maintenance)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: Text(_isAdding ? 'اختر فنيًا إضافيًا واحدًا أو أكثر متاحًا' : 'اختر فنيًا واحدًا أو أكثر متاحًا',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 10),
            ],
            Expanded(
              child: ListView.separated(
                itemCount: state.technicians.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final tech = state.technicians[i];
                  final isSelected = _selectedIds.contains(tech.id);
                  return _TechnicianTile(
                    technician: tech,
                    selected: isSelected,
                    onTap: tech.available
                        ? () => setState(() {
                              if (isSelected) {
                                _selectedIds.remove(tech.id);
                              } else {
                                _selectedIds.add(tech.id);
                              }
                            })
                        : null,
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            // ملاحظات للفني (اختياري) — تصل مع رسالة التعيين.
            TextField(
              controller: _noteCtrl,
              enabled: !_submitting,
              minLines: 1,
              maxLines: 3,
              inputFormatters: [LengthLimitingTextInputFormatter(1000)],
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                labelText: 'ملاحظات للفني (اختياري)',
                hintText: 'مثال: ركّز على فحص الحزام قبل التشغيل',
                helperText: 'تصل مع رسالة التعيين لجروب الصيانة ولواتساب الفني',
                prefixIcon: const Icon(Icons.note_alt_outlined, size: 20, color: AppColors.maintenance),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.border)),
              ),
            ),
            const SizedBox(height: 10),
            _submitting
                ? const Center(child: Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(color: AppColors.maintenance)))
                : PrimaryButton(
                    label: selectedNames.isEmpty
                        ? 'اختر فنيًا للمتابعة'
                        : (_isAdding ? 'إضافة $selectedNames للبلاغ' : 'تعيين البلاغ لـ $selectedNames'),
                    color: AppColors.maintenance,
                    onPressed: _selectedIds.isEmpty ? null : _assign,
                  ),
          ],
        ),
      ),
    );
  }
}

class _TechnicianTile extends StatelessWidget {
  final Technician technician;
  final bool selected;
  final VoidCallback? onTap;

  const _TechnicianTile({required this.technician, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final available = technician.available;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: selected ? AppColors.maintenance : AppColors.border, width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: available ? AppColors.maintenance.withOpacity(0.1) : AppColors.divider,
              child: Text(technician.initials,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: available ? AppColors.maintenance : AppColors.textMuted)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(technician.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: available ? AppColors.textPrimary : AppColors.textMuted)),
                  Text('تخصص: ${technician.specialty}', style: TextStyle(fontSize: 12, color: available ? AppColors.textMuted : AppColors.textFaint)),
                ],
              ),
            ),
            StatusPill(
              label: available ? 'متاح' : 'غير متاح',
              color: available ? AppColors.successText : const Color(0xFF9AA3AF),
              background: available ? AppColors.successBg : AppColors.divider,
            ),
          ],
        ),
      ),
    );
  }
}
