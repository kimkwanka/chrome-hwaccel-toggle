const $ = (id) => document.getElementById(id);
let savedEnabled = null;

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
  btn.textContent = enabled ? "Turn OFF & restart browser" : "Turn ON & restart browser";
  btn.disabled = false;
}

async function init() {
  const probe = probeGpu(document.createElement("canvas"));
  const r = probe || { renderer: "WebGL unavailable", accelerated: false };
  $("running").textContent = r.accelerated ? "ON (GPU)" : "OFF (software)";
  $("renderer").textContent = r.renderer;
  const reply = await chrome.runtime.sendMessage({ type: "get" });
  if (reply && reply.ok) {
    if (reply.browser) $("browser").textContent = "(" + reply.browser + ")";
    render(reply.enabled);
    applyActionState(probe ? probe.accelerated : reply.enabled, reply.enabled);
  }
  else {
    $("saved").textContent = "?";
    $("toggle").textContent = "Unavailable";
    if (probe) applyActionState(probe.accelerated, undefined);
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
    $("toggle").textContent = "Restarting browser…";
  }
});

init();
