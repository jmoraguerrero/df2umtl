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

  if (cfg.AGENT_NAME) agentNameEl.textContent = cfg.AGENT_NAME;
  if (cfg.AGENT_STATUS) agentStatusEl.textContent = cfg.AGENT_STATUS;

  var sessionId = null;
  var sequenceId = 1;
  var busy = false;
  // When no contactId is supplied we first ask the customer for their name and
  // resolve it to a contact before starting the agent session.
  var awaitingName = false;

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
      // Kick off the conversation so the agent greets and lists the offers.
      await sendToAgent("Hi! What offers do you have for me?", true);
    } catch (e) {
      hideTyping();
      showError("Couldn't start the chat: " + e.message);
    } finally {
      setBusy(false);
      input.focus();
    }
  }

  // Resolve a typed name to a contact, then start the agent session for them.
  async function resolveName(name) {
    setBusy(true);
    showTyping();
    try {
      var data = await postJson("/resolve", { name: name });
      hideTyping();
      if (data && data.found) {
        contactId = data.contactId;
        awaitingName = false;
        await startSession();
      } else if (data && data.ambiguous) {
        addMessage(
          "I found more than one account matching that. Could you share your full name (first and last) so I can find the right one?",
          "in"
        );
      } else {
        addMessage(
          'I couldn\u2019t find an account under "' +
            name +
            '". Please double-check and type your full name exactly as it appears on your account.',
          "in"
        );
      }
    } catch (e) {
      hideTyping();
      showError("Lookup failed: " + e.message);
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
    if (contactId) {
      startSession();
    } else {
      // No contact supplied: ask for the name first (client-side), then resolve.
      awaitingName = true;
      addMessage(
        "Hi! I\u2019m your Offer Concierge. What\u2019s your name so I can find your personalized offers?",
        "in"
      );
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
    refreshActionButton();
    if (awaitingName) {
      addMessage(text, "out");
      resolveName(text);
    } else {
      sendToAgent(text, false);
    }
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
          if (awaitingName) {
            addMessage(text, "out");
            resolveName(text);
          } else {
            sendToAgent(text, false);
          }
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
