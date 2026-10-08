(function () {
  "use strict";

  var cfg = window.OFFER_DEMO_CONFIG || {};
  var BASE = (cfg.BROKER_BASE_URL || "").replace(/\/+$/, "");

  // Resolve the contact id from the URL (?contactId=... or ?c=...), else default.
  var params = new URLSearchParams(window.location.search);
  var contactId =
    params.get("contactId") || params.get("c") || cfg.DEFAULT_CONTACT_ID || "";

  var chatBody = document.getElementById("chatBody");
  var input = document.getElementById("messageInput");
  var sendBtn = document.getElementById("sendBtn");
  var agentNameEl = document.getElementById("agentName");
  var agentStatusEl = document.getElementById("agentStatus");

  if (cfg.AGENT_NAME) agentNameEl.textContent = cfg.AGENT_NAME;
  if (cfg.AGENT_STATUS) agentStatusEl.textContent = cfg.AGENT_STATUS;

  var sessionId = null;
  var sequenceId = 1;
  var busy = false;

  function scrollDown() {
    chatBody.scrollTop = chatBody.scrollHeight;
  }

  function nowTime() {
    var d = new Date();
    var h = d.getHours();
    var m = d.getMinutes();
    var ampm = h >= 12 ? "PM" : "AM";
    h = h % 12 || 12;
    return h + ":" + (m < 10 ? "0" + m : m) + " " + ampm;
  }

  function addMessage(text, who) {
    var el = document.createElement("div");
    el.className = "msg " + who;
    el.textContent = text;
    var meta = document.createElement("span");
    meta.className = "meta";
    meta.textContent = nowTime();
    el.appendChild(meta);
    chatBody.appendChild(el);
    scrollDown();
    return el;
  }

  function showTyping() {
    var el = document.createElement("div");
    el.className = "typing";
    el.id = "typingIndicator";
    el.innerHTML = "<span></span><span></span><span></span>";
    chatBody.appendChild(el);
    scrollDown();
  }

  function hideTyping() {
    var el = document.getElementById("typingIndicator");
    if (el) el.remove();
  }

  function showError(text) {
    var el = document.createElement("div");
    el.className = "error-banner";
    el.textContent = text;
    chatBody.appendChild(el);
    scrollDown();
  }

  function setBusy(state) {
    busy = state;
    sendBtn.disabled = state;
    input.disabled = state;
  }

  async function postJson(path, body) {
    var res = await fetch(BASE + path, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
    var data = null;
    try {
      data = await res.json();
    } catch (e) {
      /* non-JSON */
    }
    if (!res.ok) {
      var msg = data && data.error ? data.error : "HTTP " + res.status;
      throw new Error(msg);
    }
    return data || {};
  }

  async function startSession() {
    setBusy(true);
    showTyping();
    try {
      var data = await postJson("/session", { contactId: contactId });
      sessionId = data.sessionId;
      hideTyping();
      // Kick off the conversation so the agent greets and lists offers.
      await sendToAgent("Hi! What offers do you have for me?", true);
    } catch (e) {
      hideTyping();
      showError("Couldn't start the chat: " + e.message);
    } finally {
      setBusy(false);
      input.focus();
    }
  }

  async function sendToAgent(text, silentOutgoing) {
    if (!sessionId) {
      showError("No active session.");
      return;
    }
    if (!silentOutgoing) addMessage(text, "out");
    setBusy(true);
    showTyping();
    try {
      var data = await postJson("/message", {
        sessionId: sessionId,
        message: text,
        sequenceId: ++sequenceId,
        contactId: contactId,
      });
      hideTyping();
      var reply = (data.reply || "").trim();
      addMessage(reply || "(no response)", "in");
    } catch (e) {
      hideTyping();
      showError("Message failed: " + e.message);
    } finally {
      setBusy(false);
      input.focus();
    }
  }

  function handleSend() {
    var text = input.value.trim();
    if (!text || busy) return;
    input.value = "";
    sendToAgent(text, false);
  }

  sendBtn.addEventListener("click", handleSend);
  input.addEventListener("keydown", function (e) {
    if (e.key === "Enter") handleSend();
  });

  if (!BASE) {
    showError("Broker URL is not configured (see config.js).");
  } else {
    startSession();
  }
})();
