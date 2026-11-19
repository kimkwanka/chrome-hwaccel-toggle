// Shared by the popup (<script>) and the service worker (importScripts).

// Returns {renderer, accelerated} from a canvas/OffscreenCanvas, or null if WebGL is unavailable.
function probeGpu(canvas) {
  try {
    const gl = canvas.getContext("webgl");
    if (!gl) return null;
    const ext = gl.getExtension("WEBGL_debug_renderer_info");
    const renderer = ext ? String(gl.getParameter(ext.UNMASKED_RENDERER_WEBGL)) : "unknown";
    return { renderer, accelerated: !/SwiftShader|Microsoft Basic Render/i.test(renderer) };
  } catch (e) {
    return null;
  }
}

// Updates the toolbar icon, tooltip and badge. running/saved are booleans or undefined (unknown).
// `running` is what the GPU probe shows (or the saved setting if the probe is unavailable).
function applyActionState(running, saved) {
  if (running === undefined) return;
  const suffix = running ? "" : "-off";
  const path = {};
  for (const size of [16, 32, 48, 128]) path[size] = `icons/icon${size}${suffix}.png`;
  const mismatch = saved !== undefined && saved !== running;
  let title = "Hardware acceleration: " + (running ? "ON" : "OFF (software rendering)");
  if (mismatch) {
    title += `\nSaved setting is ${saved ? "ON" : "OFF"}: restart pending, or the GPU is unavailable.`;
  }
  chrome.action.setIcon({ path });
  chrome.action.setTitle({ title });
  chrome.action.setBadgeText({ text: mismatch ? "!" : "" });
  if (mismatch) chrome.action.setBadgeBackgroundColor({ color: "#d93025" });
}
