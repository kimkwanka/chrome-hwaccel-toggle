const HOST = "com.local.hwaccel_toggle";

function callHost(message) {
  return new Promise((resolve) => {
    chrome.runtime.sendNativeMessage(HOST, message, (reply) => {
      const err = chrome.runtime.lastError;
      if (err) resolve({ ok: false, notInstalled: true, error: err.message });
      else resolve(reply || { ok: false, error: "Empty reply from helper." });
    });
  });
}

function closeAllWindows() {
  chrome.windows.getAll({}, (wins) => {
    for (const w of wins) chrome.windows.remove(w.id);
  });
}


chrome.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
  if (msg && msg.type === "get") {
    callHost({ cmd: "get" }).then(sendResponse);
    return true;
  }
  if (msg && msg.type === "toggle") {
    callHost(msg.message || { cmd: "toggle" }).then((reply) => {
      sendResponse(reply);
      if (reply.ok) setTimeout(closeAllWindows, 200);
    });
    return true;
  }
});

chrome.commands.onCommand.addListener(async (command) => {
  if (command !== "toggle-hwaccel") return;
  const reply = await callHost({ cmd: "toggle" });
  if (reply.ok) closeAllWindows();
  else console.error("hwaccel toggle failed:", reply.error);
});
