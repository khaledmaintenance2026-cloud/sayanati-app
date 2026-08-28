import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class MaintenanceNewReportScreen extends StatefulWidget {
  const MaintenanceNewReportScreen({super.key});

  @override
  State<MaintenanceNewReportScreen> createState() => _MaintenanceNewReportScreenState();
}

class _MaintenanceNewReportScreenState extends State<MaintenanceNewReportScreen> {
  String _line = 'خط ٩';
  final _equipmentCtrl = TextEditingController(text: 'ماكينة الخلط');
  final _descriptionCtrl = TextEditingController();

  final _lines = ['خط ٧', 'خط ٨', 'خط ٩', 'خط ١٠', 'خط ١١', 'خط ١٢'];

  @override
  void dispose() {
    _equipmentCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_descriptionCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('وصف العطل إلزامي')),
      );
      return;
    }
    context.read<AppState>().createReport(
          equipment: _equipmentCtrl.text.trim(),
          line: _line,
          description: _descriptionCtrl.text.trim(),
          reportedBy: 'محمد — مشرف الإنتاج',
        );
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم إرسال البلاغ لقسم الصيانة')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ScreenTopBar(title: 'بلاغ عطل جديد'),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.maintenance.withOpacity(0.06),
                      border: Border.all(color: AppColors.maintenance.withOpacity(0.16)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      children: [
                        CircleAvatar(radius: 18, backgroundColor: Color(0x1F2B3487), child: Text('م.ع', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.maintenance))),
                        SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('محمد — مشرف الإنتاج', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                            Text('رافع البلاغ (تلقائيًا من حسابك)', style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _FieldLabel('الخط / الموقع'),
                  DropdownButtonFormField<String>(
                    value: _line,
                    decoration: _fieldDecoration(),
                    items: _lines.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                    onChanged: (v) => setState(() => _line = v ?? _line),
                  ),
                  const SizedBox(height: 14),
                  const _FieldLabel('المعدة'),
                  TextField(controller: _equipmentCtrl, decoration: _fieldDecoration()),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const _FieldLabel('وصف العطل'),
                      const SizedBox(width: 6),
                      Text('إلزامي', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.warningText)),
                    ],
                  ),
                  TextField(
                    controller: _descriptionCtrl,
                    minLines: 3,
                    maxLines: 5,
                    decoration: _fieldDecoration(hint: 'مثال: توقف مفاجئ — صوت غير طبيعي بالمحرك'),
                  ),
                  const SizedBox(height: 16),
                  const InfoNote(
                    text: 'سيصل إشعار فوري لمسؤولَي الصيانة + رسالة في جروب واتساب الصيانة',
                    color: AppColors.production,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            PrimaryButton(label: 'إرسال البلاغ', color: AppColors.maintenance, icon: Icons.send, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
    );
  }
}

InputDecoration _fieldDecoration({String? hint}) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.border)),
  );
}
