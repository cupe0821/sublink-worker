// Minimal KernelSU WebUI bridge. API shape follows tiann/KernelSU js/index.js (Apache-2.0).
let callbackCounter = 0;
function callbackName(prefix) { return `${prefix}_${Date.now()}_${callbackCounter++}`; }

export function exec(command, options = {}) {
  return new Promise((resolve, reject) => {
    const cb = callbackName('exec');
    window[cb] = (errno, stdout, stderr) => {
      delete window[cb];
      resolve({ errno, stdout, stderr });
    };
    try { ksu.exec(command, JSON.stringify(options), cb); }
    catch (e) { delete window[cb]; reject(e); }
  });
}

export function toast(message) {
  try { ksu.toast(String(message)); } catch (_) {}
}

export function listPackages(type) {
  try { return JSON.parse(ksu.listPackages(type)); } catch (_) { return []; }
}

export function getPackagesInfo(packages) {
  try {
    const arg = typeof packages === 'string' ? packages : JSON.stringify(packages);
    return JSON.parse(ksu.getPackagesInfo(arg));
  } catch (_) { return []; }
}
