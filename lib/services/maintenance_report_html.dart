import '../models/maintenance_report.dart';
import 'arabic_format.dart';

/// يبني تقرير HTML بمقاس A4 لبلاغ صيانة واحد — بنفس الهوية البصرية لتقرير
/// الإنتاج الأسبوعي — ليتحول لاحقًا لملف PDF عبر حزمة printing (والتي تستخدم
/// محرك عرض النظام نفسه، فتُخرج النص العربي بشكل سليم دون أي إعداد إضافي).
String buildMaintenanceReportHtml(MaintenanceReport report) {
  final duration = report.duration;
  final techLine = report.assignedTechnicianIds.isEmpty
      ? '—'
      : report.assignedTechnicianIds.join('، ');

  String row(String label, String value, {bool bold = false}) => '''
    <div style="display:flex; justify-content:space-between; padding:10px 0; border-bottom:1px solid #EDEFF2;">
      <span style="font-size:13px; color:#5C6673;">$label</span>
      <span style="font-size:14px; ${bold ? 'font-weight:700;' : ''} color:#1A2129;">$value</span>
    </div>
  ''';

  return '''
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<style>
  @page { size: A4; margin: 0; }
  body { margin: 0; }
</style>
</head>
<body>
<div dir="rtl" lang="ar" style="width:794px; min-height:1123px; box-sizing:border-box; background:#FFFFFF; font-family:'IBM Plex Sans Arabic','Segoe UI',Tahoma,sans-serif; color:#1A2129; padding:56px 60px; display:flex; flex-direction:column;">

  <div style="display:flex; align-items:flex-start; justify-content:space-between; padding-bottom:20px; border-bottom:2px solid #2B3487;">
    <div style="display:flex; flex-direction:column; gap:6px;">
      <div style="font-size:22px; font-weight:700; color:#2B3487;">تقرير بلاغ صيانة</div>
      <div style="font-size:14px; color:#5C6673;">رقم البلاغ: ${report.id.substring(0, 8)}</div>
    </div>
    <div style="text-align:left; font-size:12.5px; color:#8892A0;">صيانتي — إدارة الصيانة والإنتاج والسلامة</div>
  </div>

  <div style="display:grid; grid-template-columns:repeat(3, minmax(0,1fr)); gap:16px; padding:24px 0;">
    <div style="background:#F5F6F8; border-radius:12px; padding:16px;">
      <div style="font-size:12.5px; color:#5C6673; margin-bottom:6px;">الحالة</div>
      <div style="font-size:16px; font-weight:700; color:#2B3487;">${_statusLabel(report.status)}</div>
    </div>
    <div style="background:#F5F6F8; border-radius:12px; padding:16px;">
      <div style="font-size:12.5px; color:#5C6673; margin-bottom:6px;">نوع البلاغ</div>
      <div style="font-size:16px; font-weight:700; color:#2B3487;">${report.isEmergency ? 'عطل طارئ' : 'صيانة وقائية'}</div>
    </div>
    <div style="background:#F5F6F8; border-radius:12px; padding:16px;">
      <div style="font-size:12.5px; color:#5C6673; margin-bottom:6px;">مدة الإصلاح</div>
      <div style="font-size:16px; font-weight:700; color:#7A5100;">${duration != null ? ArabicFormat.duration(duration) : 'قيد التنفيذ'}</div>
    </div>
  </div>

  <div style="font-size:15px; font-weight:700; margin:8px 0 4px;">بيانات البلاغ</div>
  <div>
    ${row('الموقع / الخط', report.line)}
    ${row('المعدة', report.equipment)}
    ${row('رافع البلاغ', report.reportedBy)}
    ${row('تاريخ ووقت الرفع', ArabicFormat.dateTime(report.reportedAt))}
    ${report.assignedAt != null ? row('تاريخ التعيين', ArabicFormat.dateTime(report.assignedAt!)) : ''}
    ${row('الفني/الفنيون المعيّنون', techLine)}
  </div>

  <div style="font-size:15px; font-weight:700; margin:20px 0 8px;">وصف العطل</div>
  <div style="background:#F5F6F8; border-radius:12px; padding:14px 16px; font-size:13.5px; line-height:1.7; color:#3A4250;">
    ${report.description}
  </div>

  ${report.closedAt != null ? '''
  <div style="font-size:15px; font-weight:700; margin:20px 0 8px;">تفاصيل الإنجاز</div>
  <div>
    ${row('تاريخ ووقت الإنجاز', ArabicFormat.dateTime(report.closedAt!))}
  </div>
  <div style="background:#EAF3EF; border-radius:12px; padding:14px 16px; font-size:13.5px; line-height:1.7; color:#1F7A63; margin-top:8px;">
    <div style="font-weight:700; margin-bottom:6px; color:#1F7A63;">وصف العمل المنجز</div>
    ${report.closeDescription ?? '—'}
  </div>
  <div style="background:#F5F6F8; border-radius:12px; padding:14px 16px; font-size:13.5px; line-height:1.7; color:#3A4250; margin-top:8px;">
    <div style="font-weight:700; margin-bottom:6px;">القطع / المواد المستخدمة</div>
    ${report.partsUsed ?? '—'}
  </div>
  ''' : ''}

  <div style="margin-top:auto; padding-top:28px; border-top:1px solid #EDEFF2; font-size:11px; color:#B4BAC2; display:flex; justify-content:space-between;">
    <span>تم إنشاء هذا التقرير تلقائيًا من تطبيق صيانتي</span>
    <span>${ArabicFormat.dateTime(DateTime.now())}</span>
  </div>

</div>
</body>
</html>
''';
}

String _statusLabel(MaintenanceStatus status) {
  switch (status) {
    case MaintenanceStatus.pendingAssignment:
      return 'بانتظار التعيين';
    case MaintenanceStatus.inProgress:
      return 'قيد التنفيذ';
    case MaintenanceStatus.completed:
      return 'مكتمل';
  }
}
