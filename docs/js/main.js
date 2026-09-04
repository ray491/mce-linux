/* Minecraft Education for Linux — landing page interactions */
(function () {
  "use strict";

  var nav = document.getElementById("site-nav");
  var toggle = document.getElementById("nav-toggle");
  var menu = document.getElementById("nav-menu");

  /* ---------- Mobile menu ---------- */
  function closeMenu() {
    if (!menu) return;
    menu.classList.remove("open");
    if (toggle) toggle.setAttribute("aria-expanded", "false");
  }

  if (toggle && menu) {
    toggle.addEventListener("click", function () {
      var open = menu.classList.toggle("open");
      toggle.setAttribute("aria-expanded", String(open));
    });
    menu.addEventListener("click", function (e) {
      if (e.target.closest("a")) closeMenu();
    });
    document.addEventListener("keydown", function (e) {
      if (e.key === "Escape") closeMenu();
    });
  }

  /* ---------- Nav shadow after scroll ---------- */
  if (nav) {
    var onScroll = function () {
      nav.style.boxShadow = window.scrollY > 8
        ? "0 8px 30px -12px rgba(0, 0, 0, 0.6)"
        : "none";
    };
    window.addEventListener("scroll", onScroll, { passive: true });
    onScroll();
  }

  /* ---------- Scrollspy ---------- */
  var links = Array.prototype.slice.call(document.querySelectorAll(".nav-link"));
  var sections = links
    .map(function (l) {
      var id = l.getAttribute("href");
      return id && id.charAt(0) === "#" ? document.querySelector(id) : null;
    })
    .filter(Boolean);

  function spy() {
    var pos = window.scrollY + nav.offsetHeight + 24;
    var current = null;
    sections.forEach(function (s) {
      if (s.offsetTop <= pos) current = s.getAttribute("id");
    });
    if (window.innerHeight + window.scrollY >= document.body.scrollHeight - 40) {
      var last = sections[sections.length - 1];
      if (last) current = last.getAttribute("id");
    }
    links.forEach(function (l) {
      var active = l.getAttribute("href") === "#" + current;
      l.classList.toggle("active", active);
      if (active) l.setAttribute("aria-current", "true");
      else l.removeAttribute("aria-current");
    });
  }
  if (sections.length) {
    window.addEventListener("scroll", spy, { passive: true });
    window.addEventListener("resize", spy);
    spy();
  }

  /* ---------- Copy buttons ---------- */
  function copyText(text) {
    if (navigator.clipboard && window.isSecureContext) {
      return navigator.clipboard.writeText(text);
    }
    return new Promise(function (resolve, reject) {
      var ta = document.createElement("textarea");
      ta.value = text;
      ta.style.position = "fixed";
      ta.style.opacity = "0";
      document.body.appendChild(ta);
      ta.select();
      try {
        document.execCommand("copy");
        resolve();
      } catch (err) {
        reject(err);
      }
      document.body.removeChild(ta);
    });
  }

  document.querySelectorAll(".copy-btn").forEach(function (btn) {
    btn.addEventListener("click", function () {
      var text = btn.getAttribute("data-copy");
      if (!text) return;
      copyText(text).then(function () {
        var original = btn.textContent;
        btn.textContent = "Copied ✓";
        btn.classList.add("copied");
        setTimeout(function () {
          btn.textContent = original;
          btn.classList.remove("copied");
        }, 1600);
      }).catch(function () {
        btn.textContent = "Copy failed";
        setTimeout(function () { btn.textContent = "Copy"; }, 1600);
      });
    });
  });

  /* ---------- Footer year ---------- */
  var year = document.getElementById("year");
  if (year) year.textContent = String(new Date().getFullYear());
})();
