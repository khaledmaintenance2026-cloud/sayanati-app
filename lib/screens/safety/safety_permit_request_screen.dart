import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/safety_permit.dart';
import '../../services/app_state.dart';
import '../../services/auth_service.dart';
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
  final _officeNameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _countCtrl = TextEditingController(text: '1');
  final _equipmentUsedCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String? _relatedReportId;

  final Set<String> _operationTypes = {};

  DateTime? _startAt;
  DateTime? _endAt;

  // بيانات صورة المعدات كـ data URL جاهزة للإرسال، مع نسخة للعرض داخل الشاشة.
  String? _equipmentPhotoDataUrl;
  Uint8List? _equipmentPhotoBytes;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final phone = context.read<AuthService>().currentUser?.phone;
    if (phone != null && phone.isNotEmpty) _phoneCtrl.text = phone;
  }

  @override
  void dispose() {
    _detailCtrl.dispose();
    _officeNameCtrl.dispose();
    _descCtrl.dispose();
    _countCtrl.dispose();
    _equipmentUsedCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  String get _fullLocation =>
      _detailCtrl.text.trim().isEmpty ? _location : '$_location — ${_detailCtrl.text.trim()}';

  bool get _canSubmit =>
      !_submitting &&
      _descCtrl.text.trim().isNotEmpty &&
      _operationTypes.isNotEmpty &&
      _equipmentPhotoDataUrl != null;

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 80);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final ext = picked.name.toLowerCase().endsWith('.png')
          ? 'png'
          : picked.name.toLowerCase().endsWith('.webp')
              ? 'webp'
              : 'jpeg';
      setState(() {
        _equipmentPhotoBytes = bytes;
        _equipmentPhotoDataUrl = 'data:image/$ext;base64,${base64Encode(bytes)}';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر اختيار الصورة: $e')));
    }
  }

  void _showPhotoSourceSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('التقاط صورة بالكاميرا'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('اختيار من المعرض'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final now = DateTime.now();
    final initial = (isStart ? _startAt : _endAt) ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null) return;
    final combined = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _startAt = combined;
      } else {
        _endAt = combined;
      }
    });
  }

  String _formatDateTime(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/${dt.year} — $h:$mi';
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await context.read<AppState>().requestPermitCloud(
            location: _fullLocation,
            description: _descCtrl.text.trim(),
            workersCount: int.tryParse(_countCtrl.text.trim()) ?? 1,
            operationTypes: _operationTypes.toList(),
            equipmentPhotoBase64: _equipmentPhotoDataUrl!,
            officeName: _officeNameCtrl.text.trim().isNotEmpty ? _officeNameCtrl.text.trim() : null,
            equipmentUsed: _equipmentUsedCtrl.text.trim().isNotEmpty ? _equipmentUsedCtrl.text.trim() : null,
            responsiblePhone: _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
            startAt: _startAt,
            endAt: _endAt,
            relatedWorkOrderId: _relatedReportId,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال طلب التصريح لقسم السلامة')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر إرسال طلب التصريح: $e')),
      );
    }
  }

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
                  const Text('اسم المكتب/الجهة الطالبة (اختياري)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  TextField(controller: _officeNameCtrl, decoration: _decoration(hint: 'مثال: قسم الصيانة الميكانيكية')),
                  const SizedBox(height: 14),
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
                  const Text('نوع العمل الخطر (اختر واحدًا أو أكثر)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kOperationTypeLabels.entries.map((e) {
                      final selected = _operationTypes.contains(e.key);
                      return FilterChip(
                        label: Text(e.value),
                        selected: selected,
                        selectedColor: AppColors.safety.withOpacity(0.22),
                        onSelected: (_) => setState(() {
                          if (selected) {
                            _operationTypes.remove(e.key);
                          } else {
                            _operationTypes.add(e.key);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  const Text('عدد العمال / الفنيين', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  TextField(controller: _countCtrl, keyboardType: TextInputType.number, decoration: _decoration()),
                  const SizedBox(height: 14),
                  const Text('رقم جوال المسؤول عن العمل (اختياري)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: _decoration(hint: '05xxxxxxxx')),
                  const SizedBox(height: 14),
                  const Text('المعدات/الأدوات المستخدمة (اختياري)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  TextField(controller: _equipmentUsedCtrl, decoration: _decoration(hint: 'مثال: ماكينة لحام كهربائي')),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _DateTimeField(
                          label: 'بداية العمل (اختياري)',
                          value: _startAt,
                          formatter: _formatDateTime,
                          onTap: () => _pickDateTime(isStart: true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _DateTimeField(
                          label: 'نهاية العمل (اختياري)',
                          value: _endAt,
                          formatter: _formatDateTime,
                          onTap: () => _pickDateTime(isStart: false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('صورة المعدات/موقع العمل (إلزامية)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  _EquipmentPhotoPicker(bytes: _equipmentPhotoBytes, onTap: _showPhotoSourceSheet),
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
              label: _submitting ? 'جارٍ الإرسال...' : 'إرسال طلب التصريح',
              color: _canSubmit ? AppColors.safety : AppColors.textFaint,
              onPressed: _canSubmit ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _DateTimeField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final String Function(DateTime) formatter;
  final VoidCallback onTap;

  const _DateTimeField({required this.label, required this.value, required this.formatter, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    value != null ? formatter(value!) : 'اختر',
                    style: TextStyle(fontSize: 12.5, color: value != null ? AppColors.textPrimary : AppColors.textFaint),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EquipmentPhotoPicker extends StatelessWidget {
  final Uint8List? bytes;
  final VoidCallback onTap;

  const _EquipmentPhotoPicker({required this.bytes, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: bytes != null ? AppColors.safety : AppColors.border, width: bytes != null ? 1.6 : 1),
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: bytes != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(bytes!, fit: BoxFit.cover),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(10)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.refresh, size: 14, color: Colors.white),
                          SizedBox(width: 6),
                          Text('تغيير الصورة', style: TextStyle(fontSize: 11.5, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_a_photo_outlined, size: 28, color: AppColors.textMuted),
                    SizedBox(height: 8),
                    Text('التقاط أو اختيار صورة', style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
                  ],
                ),
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
