(function () {
  "use strict";

  var EMAIL_RE = /^[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}$/;
  var SUCCESS_MESSAGE =
    "You're on the list. Check your email and click the confirm link so we can send the voucher at launch.";
  var INPUT_ERROR = "Enter an email that looks like name@example.com.";
  var SERVER_ERROR = "Something on our end went wrong. Try again in a minute.";
  var CONFIG_ERROR =
    "This page is missing its Supabase settings, so signups cannot be saved.";

  var form = document.getElementById("waitlist-form");
  var emailInput = document.getElementById("email");
  var honeypot = document.getElementById("company");
  var button = document.getElementById("submit-btn");
  var statusEl = document.getElementById("status");
  var config = window.TEAHAPPY_CONFIG || {};

  function normalizeEmail(value) {
    return String(value || "").trim().toLowerCase();
  }

  function isValidEmail(value) {
    return value.length >= 3 && value.length <= 254 && EMAIL_RE.test(value);
  }

  function setStatus(kind, message) {
    statusEl.className = "status" + (kind ? " is-" + kind : "");
    statusEl.textContent = message;
    statusEl.focus();
  }

  function configured() {
    return (
      config.supabaseUrl &&
      config.supabaseAnonKey &&
      config.supabaseUrl.indexOf("__SUPABASE") === -1 &&
      config.supabaseAnonKey.indexOf("__SUPABASE") === -1
    );
  }

  function joinUrl() {
    return (
      config.supabaseUrl.replace(/\/$/, "") + "/rest/v1/waitlist"
    );
  }

  function fakeSuccess() {
    window.setTimeout(function () {
      button.disabled = false;
      setStatus("ok", SUCCESS_MESSAGE);
      form.reset();
    }, 400);
  }

  function submitEmail(email) {
    var headers = {
      apikey: config.supabaseAnonKey,
      "Content-Type": "application/json",
      Prefer: "return=minimal",
    };
    // Legacy JWT anon keys use Bearer. Publishable keys (sb_publishable_) do not.
    if (String(config.supabaseAnonKey).indexOf("eyJ") === 0) {
      headers.Authorization = "Bearer " + config.supabaseAnonKey;
    }
    return fetch(joinUrl(), {
      method: "POST",
      headers: headers,
      body: JSON.stringify({ email: email }),
    });
  }

  form.addEventListener("submit", function (event) {
    event.preventDefault();
    setStatus("", "");

    if (honeypot.value) {
      button.disabled = true;
      fakeSuccess();
      return;
    }

    var email = normalizeEmail(emailInput.value);
    emailInput.value = email;

    if (!isValidEmail(email)) {
      setStatus("error", INPUT_ERROR);
      emailInput.focus();
      return;
    }

    if (!configured()) {
      setStatus("error", CONFIG_ERROR);
      return;
    }

    button.disabled = true;
    button.textContent = "Saving…";

    submitEmail(email)
      .then(function (response) {
        // 201: inserted. 409: unique email already present; same user-facing result.
        if (response.ok || response.status === 409) {
          setStatus("ok", SUCCESS_MESSAGE);
          form.reset();
          return;
        }
        if (response.status === 400) {
          setStatus("error", INPUT_ERROR);
          emailInput.focus();
          return;
        }
        setStatus("error", SERVER_ERROR);
      })
      .catch(function () {
        setStatus("error", SERVER_ERROR);
      })
      .then(function () {
        button.disabled = false;
        button.textContent = "Save my voucher spot";
      });
  });
})();
