import 'dart:html' as html;

bool openHtmlReportInNewTab(String htmlContent) {
  final blob = html.Blob([htmlContent], 'text/html');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final opened = html.window.open(url, '_blank');
  return opened != null;
}
