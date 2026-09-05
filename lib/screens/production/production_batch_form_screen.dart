import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/production.dart';
import '../../services/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class ProductionBatchFormScreen extends StatefulWidget {
  final ProductionLine line;
  const ProductionBatchFormScreen({super.key, required this.line});

  @override
  State<ProductionBatchFormScreen> createState() => _ProductionBatchFormScreenState();
}

class _ProductionBatchFormScreenState extends State<ProductionBatchFormScreen> with SingleTickerProviderStateMixin {
  final _batchNumberCtrl = TextEditingController();
  final _productCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _minutesCtrl = TextEditingController();
  final _operationalNotesCtrl = TextEditingController();
  final _actionsTakenCtrl = TextEditingController();
  bool _hasStoppage = false;
  bool _submitting = false;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _batchNumberCtrl.dispose();
    _productCtrl.dispose();
    _qtyCtrl.dispose();
    _reasonCtrl.dispose();
    _minutesCtrl.dispose();
    _operationalNotesCtrl.dispose();
    _actionsTakenCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    if (_submitting) return false;
    final qty = int.tryParse(_qtyCtrl.text.trim());
    if (_batchNumberCtrl.text.trim().isEmpty) return false;
    if (_productCtrl.text.trim().isEmpty || qty == null || qty <= 0) return false;
    if (_hasStoppage && _reasonCtrl.text.trim().isEmpty) return false;
    return true;
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await context.read<AppState>().recordBatchCloud(
            lineId: widget.line.id,
            batchNumber: _batchNumberCtrl.text.trim(),
            productName: _productCtrl.text.trim(),
            quantity: int.parse(_qtyCtrl.text.trim()),
            hasStoppage: _hasStoppage,
            stoppageReason: _hasStoppage ? _reasonCtrl.text.trim() : null,
            stoppageMinutes: _hasStoppage ? int.tryParse(_minutesCtrl.text.trim()) : null,
            operationalNotes:
                _operationalNotesCtrl.text.trim().isNotEmpty ? _operationalNotesCtrl.text.trim() : null,
            actionsTaken: _hasStoppage && _actionsTakenCtrl.text.trim().isNotEmpty
                ? _actionsTakenCtrl.text.trim()
                : null,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل الباتش وحفظه على السيرفر')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر تسجيل الباتش: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ScreenTopBar(title: 'باتش جديد — ${widget.line.name}'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabBar(
            controller: _tabController,
            labelColor: AppColors.production,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.production,
            tabs: const [
              Tab(text: 'بيانات الباتش'),
              Tab(text: 'الملاحظات التشغيلية'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: ListView(
                    children: [
                      const _Label('رقم الباتش'),
                      TextField(
                        controller: _batchNumberCtrl,
                        decoration: _decoration(hint: 'مثال: B-2026-0145'),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 14),
                      const _Label('اسم المنتج'),
                      TextField(controller: _productCtrl, decoration: _decoration(hint: 'مثال: حديد تسليح ١٢ مم'), onChanged: (_) => setState(() {})),
                      const SizedBox(height: 14),
                      const _Label('الكمية'),
                      TextField(
                        controller: _qtyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: _decoration(hint: 'مثال: 310'),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(14)),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text('هل حدث توقف أثناء هذا الباتش؟', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                  Text('فعّل الخيار فقط عند وجود توقف فعلي', style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                                ],
                              ),
                            ),
                            Switch(
                              value: _hasStoppage,
                              activeColor: AppColors.safety,
                              onChanged: (v) => setState(() => _hasStoppage = v),
                            ),
                          ],
                        ),
                      ),
                      if (_hasStoppage) ...[
                        const SizedBox(height: 14),
                        const _Label('سبب التوقف'),
                        TextField(controller: _reasonCtrl, decoration: _decoration(hint: 'مثال: عطل ميكانيكي مفاجئ'), onChanged: (_) => setState(() {})),
                        const SizedBox(height: 14),
                        const _Label('مدة التوقف (بالدقائق)'),
                        TextField(controller: _minutesCtrl, keyboardType: TextInputType.number, decoration: _decoration(hint: 'مثال: 45')),
                        const SizedBox(height: 14),
                        const _Label('الحلول والإجراءات المتخذة'),
                        TextField(
                          controller: _actionsTakenCtrl,
                          maxLines: 3,
                          decoration: _decoration(hint: 'ما الذي تم اتخاذه لحل المشكلة؟'),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: ListView(
                    children: [
                      const _Label('الملاحظات التشغيلية'),
                      TextField(
                        controller: _operationalNotesCtrl,
                        maxLines: 6,
                        decoration: _decoration(hint: 'أي ملاحظات عن سير العمل خلال هذا الباتش — ليست مرتبطة بالضرورة بتوقف'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: _submitting
                ? const Center(child: Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator()))
                : PrimaryButton(
                    label: 'تسجيل الباتش',
                    color: _canSubmit ? AppColors.production : AppColors.textFaint,
                    icon: Icons.check,
                    onPressed: _canSubmit ? _submit : null,
                  ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
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
