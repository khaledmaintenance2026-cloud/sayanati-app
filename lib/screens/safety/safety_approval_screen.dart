import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/safety_permit.dart';
import '../../services/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// شاشة مراجعة تصريح العمل — تطابق استمارة "إجراءات ومتطلبات السلامة
/// لتصريح العمل" الورقية: أولًا يُحدَّد قرار التصريح (مقبول/مرفوض)، ثم يظهر
/// "قسم القبول" (خلو الموقع من كذا + المخاطر المحتملة + معدات الوقاية
/// الشخصية + الإجراءات الإلزامية) أو "قسم الرفض" (سبب الرفض فقط) حسب القرار.
class SafetyApprovalScreen extends StatefulWidget {
  final SafetyPermit permit;
  const SafetyApprovalScreen({super.key, required this.permit});

  @override
  State<SafetyApprovalScreen> createState() => _SafetyApprovalScreenState();
}

class _SafetyApprovalScreenState extends State<SafetyApprovalScreen> {
  bool? _approve; // null = لم يُحدَّد القرار بعد

  final Set<String> _siteHazards = {};
  final Set<String> _potentialRisks = {};
  final Set<String> _ppeRequired = {};
  final _otherPpeCtrl = TextEditingController();
  final _precautionsCtrl = TextEditingController();
  final _rejectionReasonCtrl = TextEditingController();

  @override
  void dispose() {
    _otherPpeCtrl.dispose();
    _precautionsCtrl.dispose();
    _rejectionReasonCtrl.dispose();
    super.dispose();
  }

  bool get _canConfirm {
    if (_approve == null) return false;
    if (_approve == true) {
      return _siteHazards.isNotEmpty &&
          _potentialRisks.isNotEmpty &&
          (_ppeRequired.isNotEmpty || _otherPpeCtrl.text.trim().isNotEmpty) &&
          _precautionsCtrl.text.trim().isNotEmpty;
    }
    return _rejectionReasonCtrl.text.trim().isNotEmpty;
  }

  void _confirm() {
    final appState = context.read<AppState>();
    if (_approve == true) {
      final ppe = {
        ..._ppeRequired,
        if (_otherPpeCtrl.text.trim().isNotEmpty) 'أخرى: ${_otherPpeCtrl.text.trim()}',
      };
      appState.reviewPermit(
        widget.permit.id,
        approve: true,
        reviewer: 'مسؤول السلامة',
        siteHazards: _siteHazards.toList(),
        potentialRisks: _potentialRisks.toList(),
        ppeRequired: ppe.toList(),
        precautions: _precautionsCtrl.text.trim(),
      );
    } else {
      appState.reviewPermit(
        widget.permit.id,
        approve: false,
        reviewer: 'مسؤول السلامة',
        rejectionReason: _rejectionReasonCtrl.text.trim(),
      );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final permit = widget.permit;

    return Scaffold(
      appBar: const ScreenTopBar(title: 'مراجعة تصريح العمل'),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.safety.withOpacity(0.12),
                      border: Border.all(color: AppColors.safety.withOpacity(0.4)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(permit.location, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.safetyText)),
                        const SizedBox(height: 8),
                        Text(permit.description, style: const TextStyle(fontSize: 13.5, height: 1.6, color: Color(0xFF3A4250))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _InfoRow(label: 'مقدّم الطلب', value: '${permit.requesterName} — ${permit.requesterRole}'),
                  _InfoRow(label: 'عدد العمال المطلوبين', value: permit.techniciansCount.toString()),
                  if (permit.relatedReportId != null) const _InfoRow(label: 'الحالة', value: 'مرتبط ببلاغ صيانة قائم'),
                  const SizedBox(height: 10),
                  const InfoNote(
                    text: 'موافقة قسم السلامة فقط — قسم الصيانة منفصل تمامًا ودوره الفني لا علاقة له بالاعتماد',
                    color: AppColors.safetyText,
                    icon: Icons.info_outline,
                  ),
                  const SizedBox(height: 22),
                  const _SectionTitle('هذا التصريح؟'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _DecisionButton(
                          label: 'مقبول',
                          selected: _approve == true,
                          color: AppColors.safety,
                          onTap: () => setState(() => _approve = true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _DecisionButton(
                          label: 'مرفوض',
                          selected: _approve == false,
                          color: const Color(0xFFB3261E),
                          onTap: () => setState(() => _approve = false),
                        ),
                      ),
                    ],
                  ),
                  if (_approve == true) ...[
                    const SizedBox(height: 22),
                    const _SectionTitle('قسم القبول'),
                    const SizedBox(height: 4),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text('يرجاء الالتزام بالسلامة المهنية', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    ),
                    const SizedBox(height: 14),
                    _CheckGroup(
                      title: 'خلو الموقع من التالي',
                      options: kSiteHazardOptions,
                      selected: _siteHazards,
                      onChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: 18),
                    _CheckGroup(
                      title: 'المخاطر المحتملة',
                      options: kPotentialRiskOptions,
                      selected: _potentialRisks,
                      onChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: 18),
                    _CheckGroup(
                      title: 'معدات الوقاية الشخصية التي يجب توفرها',
                      options: kPpeOptions,
                      selected: _ppeRequired,
                      onChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    const Align(alignment: Alignment.centerRight, child: Text('أخرى (اختياري)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _otherPpeCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: _decoration(hint: 'معدّة وقاية أخرى غير مذكورة أعلاه'),
                    ),
                    const SizedBox(height: 18),
                    const Align(alignment: Alignment.centerRight, child: Text('الإجراءات الإلزامية للتصريح العمل', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _precautionsCtrl,
                      minLines: 3,
                      maxLines: 5,
                      onChanged: (_) => setState(() {}),
                      decoration: _decoration(hint: 'اكتب الإجراءات الإلزامية الواجب اتباعها قبل وأثناء العمل'),
                    ),
                  ],
                  if (_approve == false) ...[
                    const SizedBox(height: 22),
                    const _SectionTitle('قسم الرفض'),
                    const SizedBox(height: 14),
                    const Align(alignment: Alignment.centerRight, child: Text('لماذا رُفض الطلب', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _rejectionReasonCtrl,
                      minLines: 3,
                      maxLines: 5,
                      onChanged: (_) => setState(() {}),
                      decoration: _decoration(hint: 'اذكر سبب رفض طلب التصريح'),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            PrimaryButton(
              label: _approve == false ? 'تأكيد الرفض' : 'تأكيد الموافقة على التصريح',
              color: !_canConfirm
                  ? AppColors.textFaint
                  : (_approve == false ? const Color(0xFFB3261E) : AppColors.safety),
              icon: _approve == false ? Icons.close : Icons.check,
              onPressed: _canConfirm ? _confirm : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
    );
  }
}

class _DecisionButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _DecisionButton({required this.label, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.14) : AppColors.surface,
          border: Border.all(color: selected ? color : AppColors.border, width: selected ? 1.6 : 1),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: selected ? color : AppColors.textSecondary),
        ),
      ),
    );
  }
}

/// مجموعة اختيار متعدد (يمكن اختيار أكثر من عنصر) — تُستخدم لكل من أقسام
/// "خلو الموقع من التالي" و"المخاطر المحتملة" و"معدات الوقاية الشخصية".
class _CheckGroup extends StatelessWidget {
  final String title;
  final List<String> options;
  final Set<String> selected;
  final VoidCallback onChanged;

  const _CheckGroup({required this.title, required this.options, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final isSelected = selected.contains(opt);
            return FilterChip(
              label: Text(opt),
              selected: isSelected,
              selectedColor: AppColors.safety.withOpacity(0.22),
              onSelected: (_) {
                if (isSelected) {
                  selected.remove(opt);
                } else {
                  selected.add(opt);
                }
                onChanged();
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
          Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

InputDecoration _decoration({String? hint}) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.border)),
  );
}
