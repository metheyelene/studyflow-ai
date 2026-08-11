/// Non-web implementation of capture-storage: there is no localStorage, so
/// the capture signed-in flag never persists (and never leaks the `web`
/// package into VM/native builds or tests).
library;

bool captureSignedIn() => false;

void captureSetSignedIn(bool value) {}
