import 'package:flutter/material.dart';

import '../../models/leaves.dart';
import '../../services/leaves_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'leaves_widgets.dart';

/// إعدادات الإجازات (لمدير النظام فقط): أيام الاستحقاق السنوي، مدة صلاحية الرصيد،
/// طريقة تقريب الأيام المدفوعة، مدة تنبيه «إجازة قادمة»، وتشغيل التنبيهات. لا شيء
/// مخزَّن في الأرصدة (التواريخ فقط)، لذا أي تعديل هنا يُعيد حساب كل الأرصدة فورًا.
class LeavesSettingsScreen extends StatefulWidget {
  const LeavesSettingsScreen({super.key});

  @override
  State<LeavesSettingsScreen> createState() => _LeavesSettingsScreenState();
}

class _LeavesSettingsScreenState extends State<LeavesSettingsScreen> {
  final TextEditingController _annual = TextEditingController();
  final TextEditingController _expiry = TextEditingController();
  final TextEditingController _soon = TextEditingController();
  String _rounding = 'nearest';
  bool _alerts = true;

  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _annual.dispose();
    _expiry.dispose();
    _soon.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final s = await LeavesService.fetchSettings();
      if (!mounted) return;
      setState(() {
        _annual.text = _plain(s.annualDays);
        _expiry.text = s.expiryYears.toString();
        _soon.text = s.soonDays.toString();
        _rounding = s.paidRounding == 'floor' ? 'floor' : 'nearest';
        _alerts = s.alertsEnabled;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = leavesErrorText(e);
        _loading = false;
      });
    }
  }

  /// 21.0 → "21" ، 10.5 → "10.5" (للحقل النصي، بأرقام لاتينية).
  static String _plain(double v) {
    if (v == v.roundToDouble()) return v.round().toString();
    return v.toString();
  }

  Future<void> _save() async {
    final annual = double.tryParse(leaveWesternDigits(_annual.text.trim()).replaceAll('٫', '.').replaceAll(',', '.'));
    final expiry = int.tryParse(leaveWesternDigits(_expiry.text.trim()));
    final soon = int.tryParse(leaveWesternDigits(_soon.text.trim()));
    if (annual == null || annual < 1 || annual > 365) {
      setState(() => _error = 'أيام الاستحقاق السنوي: رقم بين ١ و٣٦٥');
      return;
    }
    if (expiry == null || expiry < 1 || expiry > 10) {
      setState(() => _error = 'مدة صلاحية الرصيد: عدد صحيح من السنوات بين ١ و١٠');
      return;
    }
    if (soon == null || soon < 1 || soon > 60) {
      setState(() => _error = 'تنبيه الإجازة القادمة: عدد صحيح من الأيام بين ١ و٦٠');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await LeavesService.saveSettings(
        annualDays: annual,
        expiryYears: expiry,
        paidRounding: _rounding,
        soonDays: soon,
        alertsEnabled: _alerts,
      );
      notifyLeavesChanged();
      if (!mounted) return;
      showLeavesSnack(context, 'تم حفظ الإعدادات وإعادة حساب الأرصدة');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = leavesErrorText(e);
      });
    }
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      );

  Widget _roundingOption(String value, String title, String subtitle) {
    final selected = _rounding == value;
    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: () => setState(() => _rounding = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? kLeavesColor.withOpacity(0.08) : AppColors.surface,
          border: Border.all(color: selected ? kLeavesColor : AppColors.border),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 22,
              color: selected ? kLeavesColor : AppColors.textMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _form() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
      children: [
        _label('أيام الاستحقاق في السنة'),
        TextField(
          controller: _annual,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: fieldDecoration(hint: '21'),
        ),
        const SizedBox(height: 6),
        const Text(
          'يتراكم الاستحقاق يوميًا (هذا الرقم ÷ ٣٦٥ لكل يوم) من تاريخ المباشرة.',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 14),
        _label('مدة صلاحية الرصيد (بالسنوات)'),
        TextField(
          controller: _expiry,
          keyboardType: TextInputType.number,
          decoration: fieldDecoration(hint: '2'),
        ),
        const SizedBox(height: 6),
        const Text(
          'ما لم يُستعمل خلال هذه المدة يسقط (الأقدم أولًا). الحد الأقصى للرصيد = الاستحقاق السنوي × المدة.',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.5),
        ),
        const SizedBox(height: 14),
        _label('تنبيه «إجازة قادمة» قبل البدء بـ (أيام)'),
        TextField(
          controller: _soon,
          keyboardType: TextInputType.number,
          decoration: fieldDecoration(hint: '7'),
        ),
        const SizedBox(height: 18),
        _label('تقريب الأيام المدفوعة'),
        _roundingOption('nearest', 'لأقرب يوم', 'رصيد ٩٫٩٥ يوم يُحتسب ١٠ أيام مدفوعة (والباقي بدون راتب).'),
        const SizedBox(height: 8),
        _roundingOption('floor', 'للأسفل', 'رصيد ٩٫٩٥ يوم يُحتسب ٩ أيام مدفوعة (والباقي بدون راتب).'),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(13),
          ),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeColor: kLeavesColor,
            title: const Text('تشغيل التنبيهات التلقائية', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            subtitle: const Text(
              'وصول الرصيد للحد الأقصى، التأخر عن المباشرة، إجازة قادمة، إجازة بلا تاريخ عودة — تُرسل مرة واحدة لكل حالة (إشعار + واتساب).',
              style: TextStyle(fontSize: 12, height: 1.5),
            ),
            value: _alerts,
            onChanged: (v) => setState(() => _alerts = v),
          ),
        ),
        const SizedBox(height: 14),
        const InfoNote(
          text: 'لا تُخزَّن أي أرصدة: النظام يحسبها من التواريخ، فتغيير هذه القيم يُعيد حساب كل الموظفين فورًا.',
          color: kLeavesColor,
          icon: Icons.calculate_outlined,
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          InfoNote(text: _error!, color: kLeavesDanger, icon: Icons.error_outline),
        ],
        const SizedBox(height: 18),
        PrimaryButton(
          label: _saving ? 'جارٍ الحفظ...' : 'حفظ الإعدادات',
          color: kLeavesColor,
          icon: Icons.check,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator(color: kLeavesColor));
    } else if (_loadError != null) {
      body = ListView(children: [LeavesErrorView(message: _loadError!, onRetry: _load)]);
    } else {
      body = _form();
    }
    return Scaffold(
      appBar: const ScreenTopBar(title: 'إعدادات الإجازات'),
      body: body,
    );
  }
}
