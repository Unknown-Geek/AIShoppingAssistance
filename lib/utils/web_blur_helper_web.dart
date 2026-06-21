// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class WebBlurHelper {
  static void initialize() {
    final id = 'qless-web-blur-css';
    if (html.document.getElementById(id) == null) {
      final style = html.StyleElement()
        ..id = id
        ..text = '''
          flt-platform-view {
            transition: filter 0.3s ease-out;
          }
          body.dialog-blur-active flt-platform-view {
            filter: blur(8px);
          }
        ''';
      html.document.head?.append(style);
    }
  }

  static void setBlurActive(bool active) {
    if (active) {
      html.document.body?.classes.add('dialog-blur-active');
    } else {
      html.document.body?.classes.remove('dialog-blur-active');
    }
  }
}
