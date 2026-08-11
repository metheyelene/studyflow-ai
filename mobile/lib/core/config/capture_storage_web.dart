/// Web implementation of capture-storage: the signed-in flag lives in
/// localStorage so it survives full page reloads between screenshots (the
/// capture driver navigates with page.goto, which reloads the app).
library;

import 'package:web/web.dart' as web;

const _signedInKey = 'studyflow.capture_signed_in';

bool captureSignedIn() {
  try {
    return web.window.localStorage.getItem(_signedInKey) == '1';
  } catch (_) {
    return false;
  }
}

void captureSetSignedIn(bool value) {
  try {
    web.window.localStorage.setItem(_signedInKey, value ? '1' : '0');
  } catch (_) {}
}
