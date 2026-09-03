import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/app_state.dart';
import '../../services/constants.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class SafetyPermitRequestScreen extends StatefulWidget {
  const SafetyPermitRequestScreen({super.key});

  @override
  State<SafetyPermitRequestScreen> createState() => _SafetyPermitRequestScreenState();
}

class _SafetyPermitRequestScreenState extends State<SafetyPermitRequestScreen> {
  String _location = kFacilityLocations.first;
  final _detailCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _countCtrl = TextEditingController(text: '1');
  String? _relatedReportId;

  @override
  void dispose() {
    _detailCtrl.dispose();
    _descCtrl.dispose();
    _countCtrl.dispose();
    super.dispose();
  }

  String get _fullLocation =>
      _detailCtrl.text.trim().isEmpty ? _location : '$_location — ${_detailCtrl.text.trim()}';

  bool get _canSubmit => _descCtrl.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final openReports = state.openEmergencyReports;

    return Scaffold(
      appBar: const ScreenTopBar(title: 'طلب تصريح عمل'),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                children: [
                  if (openReports.isNotEmpty) ...[
                    const Text('ربط بعملية بلاغ قائمة (اختياري)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('بدون ربط'),
                          selected: _relatedReportId == null,
                          onSelected: (_) => setState(() => _relatedReportId = null),
                        ),
                        ...openReports.map((r) => ChoiceChip(
                              label: Text('${r.equipment} — ${r.line}'),
                              selected: _relatedReportId == r.id,
                              selectedColor: AppColors.safety.withOpacity(0.28),
                              onSelected: (_) => setState(() => _relatedReportId = r.id),
                            )),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Text('الموقع', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _location,
                    decoration: _decoration(),
                    items: kFacilityLocations.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                    onChanged: (v) => setState(() => _location = v ?? _location),
                  ),
                  const SizedBox(height: 10),
                  const Text('تفاصيل الموقع (اختياري)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  TextField(controller: _detailCtrl, decoration: _decoration(hint: 'مثال: خط ٩ — ماكينة الخلط')),
                  const SizedBox(height: 14),
                  const Text('البيان (وصف العمل)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _descCtrl,
                    minLines: 3,
                    maxLines: 4,
                    onChanged: (_) => setState(() {}),
                    decoration: _decoration(hint: 'مثال: أعمال لحام لإصلاح تسريب في خط الأنابيب'),
                  ),
                  const SizedBox(height: 14),
                  const Text('عدد العمال / الفنيين', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  TextField(controller: _countCtrl, keyboardType: TextInputType.number, decoration: _decoration()),
                  const SizedBox(height: 16),
                  const InfoNote(
                    text: 'يُرسل الطلب لقسم السلامة للمراجعة والاعتماد فقط — لا علاقة لقسم الصيانة بالموافقة',
                    color: AppColors.safetyText,
                    icon: Icons.verified_user_outlined,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            PrimaryButton(
              label: 'إرسال طلب التصريح',
              color: _canSubmit ? AppColors.safety : AppColors.textFaint,
              onPressed: _canSubmit
                  ? () {
                      context.read<AppState>().requestPermit(
                            requesterName: 'عبدالله حسن',
                            requesterRole: 'فني صيانة',
                            location: _fullLocation,
                            description: _descCtrl.text.trim(),
                            techniciansCount: int.tryParse(_countCtrl.text.trim()) ?? 1,
                            relatedReportId: _relatedReportId,
                          );
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم إرسال طلب التصريح لقسم السلامة')),
                      );
                    }
                  : null,
            ),
          ],
        ),
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
