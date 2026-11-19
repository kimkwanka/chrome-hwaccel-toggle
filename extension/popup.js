const $ = (id) => document.getElementById(id);
let savedEnabled = null;

function detectRenderer() {
  try {
    const gl = document.createElement("canvas").getContext("webgl");
    if (!gl) return { renderer: "WebGL unavailable", accelerated: false };
    const ext = gl.getExtension("WEBGL_debug_renderer_info");
    const renderer = ext ? gl.getParameter(ext.UNMASKED_RENDERER_WEBGL) : "unknown";
    const software = /SwiftShader|Microsoft Basic Render/i.test(renderer);
    return { renderer, accelerated: !software };
  } catch (e) {
    return { renderer: String(e), accelerated: false };
  }
}

function showError(text) {
  $("error").textContent = text;
  $("error").hidden = false;
}

function hostError(reply) {
  if (reply.notInstalled) {
    return "Native helper not found (" + reply.error + "). Run install.ps1 from the project folder, then reload the extension.";
  }
  return "Helper error: " + (reply.error || "unknown");
}

function render(enabled) {
  savedEnabled = enabled;
  $("saved").textContent = enabled ? "ON" : "OFF";
  const btn = $("toggle");
  btn.textContent = enabled ? "Turn OFF & restart Chrome" : "Turn ON & restart Chrome";
  btn.disabled = false;
}

async function init() {
  const r = detectRenderer();
  $("running").textContent = r.accelerated ? "ON (GPU)" : "OFF (software)";
  $("renderer").textContent = r.renderer;
  const reply = await chrome.runtime.sendMessage({ type: "get" });
  if (reply && reply.ok) render(reply.enabled);
  else {
    $("saved").textContent = "?";
    $("toggle").textContent = "Unavailable";
    showError(hostError(reply || { error: "no response" }));
  }
}

$("toggle").addEventListener("click", async () => {
  $("toggle").disabled = true;
  $("error").hidden = true;
  const reply = await chrome.runtime.sendMessage({
    type: "toggle",
    message: { cmd: "set", enabled: !savedEnabled },
  });
  if (!reply || !reply.ok) {
    showError(hostError(reply || { error: "no response" }));
    $("toggle").disabled = false;
  } else {
    $("toggle").textContent = "Restarting Chrome…";
  }
});

init();
