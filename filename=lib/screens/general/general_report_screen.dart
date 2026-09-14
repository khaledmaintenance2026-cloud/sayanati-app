import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/app_state.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// الشاشة الوحيدة لدور "قسم عام" (موظف مستودع أو مكتب إداري) — لا شريط
/// تنقّل سفلي ولا أقسام أخرى عمدًا، فصلاحية هذا الدور الوحيدة رفع بلاغ عطل
/// للصيانة. يُرسَل البلاغ عبر نفس نقطة /api/production/incidents المستخدمة
/// أصلًا لبلاغات الإنتاج (راجع AppState.addIncidentCloud)، والسيرفر يُرفق
/// موقع الموظف (general_facility) تلقائيًا في رسالة واتساب لجروب الصيانة.
class GeneralReportScreen extends StatefulWidget {
  const GeneralReportScreen({super.key});

  @override
  State<GeneralReportScreen> createState() => _GeneralReportScreenState();
}

class _GeneralReportScreenState extends State<GeneralReportScreen> {
  final _descriptionCtrl = TextEditingController();
  String? _severity; // 'simple' | 'medium' | 'critical' | null
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final description = _descriptionCtrl.text.trim();
    if (description.isEmpty) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await context.read<AppState>().addIncidentCloud(description: description, severity: _severity);
      if (!mounted) return;
      _descriptionCtrl.clear();
      setState(() => _severity = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال بلاغك، سيتواصل معك فريق الصيانة قريبًا')),
      );
    } catch (e) {
      setState(() => _error = 'تعذّر إرسال البلاغ، حاول مرة أخرى: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final location = user?.generalFacility;

    return Scaffold(
      appBar: const ScreenTopBar(title: 'رفع بلاغ صيانة'),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: ListView(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined, color: AppColors.maintenance),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      location ?? 'لم يُحدَّد موقعك بعد — راجع مدير النظام',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: location != null ? AppColors.textPrimary : AppColors.warningText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const Text('صف المشكلة', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: _descriptionCtrl,
              maxLines: 5,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'مثال: يوجد تسريب مياه بجانب رف الخام رقم ٣...',
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.border)),
              ),
            ),
            const SizedBox(height: 18),
            const Text('نوع العطل (اختياري)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                _SeverityChip(label: 'بسيط', value: 'simple', groupValue: _severity, onTap: (v) => setState(() => _severity = v)),
                const SizedBox(width: 8),
                _SeverityChip(label: 'متوسط', value: 'medium', groupValue: _severity, onTap: (v) => setState(() => _severity = v)),
                const SizedBox(width: 8),
                _SeverityChip(label: 'حرج', value: 'critical', groupValue: _severity, onTap: (v) => setState(() => _severity = v)),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              InfoNote(text: _error!, color: const Color(0xFFB3261E), icon: Icons.error_outline),
            ],
            const SizedBox(height: 24),
            _sending
                ? const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                : PrimaryButton(
                    label: 'إرسال البلاغ للصيانة',
                    color: _descriptionCtrl.text.trim().isNotEmpty ? AppColors.maintenance : AppColors.textFaint,
                    icon: Icons.send_outlined,
                    onPressed: _descriptionCtrl.text.trim().isNotEmpty ? _send : null,
                  ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: () => context.read<AuthService>().signOut(),
                child: const Text('تسجيل الخروج'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeverityChip extends StatelessWidget {
  final String label;
  final String value;
  final String? groupValue;
  final void Function(String?) onTap;
  const _SeverityChip({required this.label, required this.value, required this.groupValue, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final selected = groupValue == value;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(selected ? null : value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.maintenance : AppColors.surface,
            border: Border.all(color: selected ? AppColors.maintenance : AppColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.textSecondary)),
        ),
      ),
    );
  }
}
