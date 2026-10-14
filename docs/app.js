(function () {
  "use strict";

  var cfg = window.OFFER_DEMO_CONFIG || {};
  var BASE = (cfg.BROKER_BASE_URL || "").replace(/\/+$/, "");

  // Resolve the contact id from the URL (?contactId=... or ?c=...). When none is
  // supplied we start an anonymous session and let the agent ask for the name.
  var params = new URLSearchParams(window.location.search);
  var contactId = params.get("contactId") || params.get("c") || "";

  var chatBody = document.getElementById("chatBody");
  var input = document.getElementById("messageInput");
  var actionBtn = document.getElementById("actionBtn");
  var composer = document.querySelector(".composer");
  var voiceToggle = document.getElementById("voiceToggle");
  var agentNameEl = document.getElementById("agentName");
  var agentStatusEl = document.getElementById("agentStatus");
  var agentSubtitleEl = document.getElementById("agentSubtitle");
  var quickRepliesEl = document.getElementById("quickReplies");
  var flow = cfg.GIVEAWAY_FLOW || null;

  if (cfg.AGENT_NAME) agentNameEl.textContent = cfg.AGENT_NAME;
  if (cfg.AGENT_STATUS) agentStatusEl.textContent = cfg.AGENT_STATUS;
  if (cfg.AGENT_SUBTITLE && agentSubtitleEl && !contactId) {
    agentSubtitleEl.textContent = cfg.AGENT_SUBTITLE;
    agentSubtitleEl.hidden = false;
  }

  var sessionId = null;
  var sequenceId = 1;
  var busy = false;
  /** @type {'goal'|'timeline'|'customer'|'details'|'free'|null} */
  var giveawayPhase = contactId || !flow ? "free" : null;

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
    if (who === "in") speak(text);
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
    actionBtn.disabled = state;
    input.disabled = state;
    if (quickRepliesEl) {
      quickRepliesEl.querySelectorAll("button").forEach(function (btn) {
        btn.disabled = state;
      });
    }
  }

  function setGiveawayPhase(phase) {
    if (!flow || contactId) {
      giveawayPhase = "free";
      hideQuickReplies();
      return;
    }
    giveawayPhase = phase;
    if (phase === "free") {
      hideQuickReplies();
      return;
    }
    if (phase === "details") {
      renderIntakeForm();
      return;
    }
    renderQuickOptions(phase);
  }

  function hideQuickReplies() {
    if (!quickRepliesEl) return;
    quickRepliesEl.hidden = true;
    quickRepliesEl.innerHTML = "";
    composer.classList.remove("composer-dimmed");
  }

  function renderQuickOptions(phase) {
    if (!quickRepliesEl || !flow) return;
    var items = [];
    if (phase === "goal") items = flow.goals || [];
    else if (phase === "timeline") items = flow.timelines || [];
    else if (phase === "customer") items = flow.customerStatus || [];

    if (!items.length) {
      hideQuickReplies();
      return;
    }

    quickRepliesEl.hidden = false;
    composer.classList.add("composer-dimmed");
    quickRepliesEl.innerHTML =
      '<div class="quick-opts">' +
      items
        .map(function (it) {
          return (
            '<button type="button" class="quick-opt" data-label="' +
            escapeAttr(it.label) +
            '">' +
            escapeHtml(it.label) +
            "</button>"
          );
        })
        .join("") +
      "</div>";

    quickRepliesEl.querySelectorAll(".quick-opt").forEach(function (btn) {
      btn.addEventListener("click", function () {
        if (busy) return;
        var label = btn.getAttribute("data-label");
        onQuickPick(label, phase);
      });
    });
  }

  function renderIntakeForm() {
    if (!quickRepliesEl) return;
    quickRepliesEl.hidden = false;
    composer.classList.add("composer-dimmed");
    quickRepliesEl.innerHTML =
      '<form class="intake-form" id="intakeForm">' +
      '<div><label for="intakeName">Name</label>' +
      '<input type="text" id="intakeName" autocomplete="name" maxlength="80">' +
      '<div class="field-err" id="intakeNameErr"></div></div>' +
      '<div><label for="intakeEmail">Email</label>' +
      '<input type="email" id="intakeEmail" autocomplete="email" maxlength="120">' +
      '<div class="field-err" id="intakeEmailErr"></div></div>' +
      '<label class="intake-consent"><input type="checkbox" id="intakeConsent">' +
      "<span>Yes, send me tailored offers by email. I can opt out anytime. (Optional — you can still enter the draw without this.)</span></label>" +
      '<button type="submit" class="intake-submit">Enter the draw</button></form>';

    var form = document.getElementById("intakeForm");
    form.addEventListener("submit", function (e) {
      e.preventDefault();
      if (busy) return;
      var nameEl = document.getElementById("intakeName");
      var emailEl = document.getElementById("intakeEmail");
      var consentEl = document.getElementById("intakeConsent");
      var nameErr = document.getElementById("intakeNameErr");
      var emailErr = document.getElementById("intakeEmailErr");
      var ok = true;
      var name = nameEl.value.trim();
      var email = emailEl.value.trim();
      nameErr.textContent = "";
      emailErr.textContent = "";
      nameEl.classList.remove("bad");
      emailEl.classList.remove("bad");
      if (!name) {
        nameErr.textContent = "Enter your name";
        nameEl.classList.add("bad");
        ok = false;
      }
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email)) {
        emailErr.textContent = email ? "Check the email format" : "Enter your email";
        emailEl.classList.add("bad");
        ok = false;
      }
      if (!ok) return;

      var consent = consentEl.checked ? "yes" : "no";
      var msg =
        "Enter draw: Name: " +
        name +
        ", Email: " +
        email +
        ", Marketing consent: " +
        consent;
      setGiveawayPhase("free");
      addMessage(name, "out");
      sendToAgent(msg, true);
    });
  }

  function onQuickPick(label, phase) {
    addMessage(label, "out");
    if (phase === "goal") {
      if (label === "Something else") {
        hideQuickReplies();
        composer.classList.remove("composer-dimmed");
        input.focus();
        giveawayPhase = "other";
      } else {
        setGiveawayPhase("timeline");
      }
    } else if (phase === "timeline") setGiveawayPhase("customer");
    else if (phase === "customer") setGiveawayPhase("details");
    sendToAgent(label, true);
  }

  function escapeHtml(s) {
    return String(s)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/"/g, "&quot;");
  }

  function escapeAttr(s) {
    return escapeHtml(s).replace(/'/g, "&#39;");
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
      if (contactId) {
        await sendToAgent("Hi! What offers do you have for me?", true);
      } else if (flow) {
        setGiveawayPhase("goal");
        await sendToAgent("Hi", true);
      } else {
        await sendToAgent("Hi", true);
      }
    } catch (e) {
      hideTyping();
      showError("Couldn't start the chat: " + e.message);
    } finally {
      setBusy(false);
      input.focus();
    }
  }

  function init() {
    if (!BASE) {
      showError("Broker URL is not configured (see config.js).");
      return;
    }
    // No contactId: start anonymous session; agent runs Lead intake in chat.
    startSession();
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
    refreshActionButton();
    if (giveawayPhase === "other") {
      setGiveawayPhase("timeline");
    }
    sendToAgent(text, false);
  }

  // --- Morphing action button (mic when empty, send when text) ---

  function refreshActionButton() {
    if (input.value.trim()) {
      composer.classList.add("has-text");
      actionBtn.setAttribute("aria-label", "Send message");
    } else {
      composer.classList.remove("has-text");
      actionBtn.setAttribute(
        "aria-label",
        recognition ? "Record voice message" : "Send message"
      );
    }
  }

  // --- Speech-to-text (Web Speech API) ---

  var SR = window.SpeechRecognition || window.webkitSpeechRecognition;
  var recognition = null;
  var listening = false;

  function showListeningPill(on) {
    var existing = document.getElementById("listeningPill");
    if (on && !existing) {
      var pill = document.createElement("div");
      pill.className = "listening-pill";
      pill.id = "listeningPill";
      pill.textContent = "Listening…";
      chatBody.appendChild(pill);
      scrollDown();
    } else if (!on && existing) {
      existing.remove();
    }
  }

  function setupRecognition() {
    if (!SR) return;
    recognition = new SR();
    recognition.lang = "en-US";
    recognition.interimResults = true;
    recognition.continuous = false;
    recognition.maxAlternatives = 1;

    recognition.onresult = function (e) {
      var transcript = "";
      for (var i = 0; i < e.results.length; i++) {
        transcript += e.results[i][0].transcript;
      }
      input.value = transcript;
      refreshActionButton();
      // When the engine marks a final result, send it automatically.
      if (e.results[e.results.length - 1].isFinal) {
        stopRecognition();
        var text = input.value.trim();
        if (text) {
          input.value = "";
          refreshActionButton();
          sendToAgent(text, false);
        }
      }
    };

    recognition.onend = function () {
      listening = false;
      actionBtn.classList.remove("recording");
      showListeningPill(false);
      refreshActionButton();
    };

    recognition.onerror = function (ev) {
      listening = false;
      actionBtn.classList.remove("recording");
      showListeningPill(false);
      if (ev.error !== "no-speech" && ev.error !== "aborted") {
        showError("Mic error: " + ev.error);
      }
    };
  }

  function startRecognition() {
    if (!recognition || busy) return;
    try {
      // Cancel any ongoing voice output so the mic doesn't hear the agent.
      if (window.speechSynthesis) window.speechSynthesis.cancel();
      input.value = "";
      refreshActionButton();
      recognition.start();
      listening = true;
      actionBtn.classList.add("recording");
      showListeningPill(true);
    } catch (e) {
      /* start() can throw if already started */
    }
  }

  function stopRecognition() {
    if (recognition && listening) {
      try {
        recognition.stop();
      } catch (e) {
        /* noop */
      }
    }
  }

  // --- Text-to-speech (agent replies) ---

  var voiceOn = localStorage.getItem("offerDemoVoiceOn") === "1";

  function reflectVoiceToggle() {
    if (!window.speechSynthesis) {
      voiceToggle.style.display = "none";
      return;
    }
    voiceToggle.classList.toggle("active", voiceOn);
    voiceToggle.innerHTML = voiceOn ? "&#128266;" : "&#128263;";
    voiceToggle.title = voiceOn ? "Voice replies on" : "Voice replies off";
  }

  function speak(text) {
    if (!voiceOn || !window.speechSynthesis || !text) return;
    try {
      var u = new SpeechSynthesisUtterance(text);
      u.lang = "en-US";
      u.rate = 1.02;
      window.speechSynthesis.cancel();
      window.speechSynthesis.speak(u);
    } catch (e) {
      /* noop */
    }
  }

  voiceToggle.addEventListener("click", function () {
    voiceOn = !voiceOn;
    localStorage.setItem("offerDemoVoiceOn", voiceOn ? "1" : "0");
    reflectVoiceToggle();
    if (!voiceOn && window.speechSynthesis) window.speechSynthesis.cancel();
  });

  // --- Wiring ---

  actionBtn.addEventListener("click", function () {
    if (input.value.trim()) {
      handleSend();
    } else if (recognition) {
      if (listening) stopRecognition();
      else startRecognition();
    }
  });

  input.addEventListener("input", refreshActionButton);
  input.addEventListener("keydown", function (e) {
    if (e.key === "Enter") handleSend();
  });

  setupRecognition();
  reflectVoiceToggle();
  refreshActionButton();
  init();
})();
