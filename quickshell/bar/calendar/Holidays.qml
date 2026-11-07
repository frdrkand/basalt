pragma Singleton

import Quickshell

// Swedish holidays ("röda dagar") for the calendar. Pure JS, no data file — same
// pragma-Singleton pattern as PowerActions.qml, usable as `Holidays.<fn>` anywhere.
//
// Fixed-date holidays are trivial; the movable ones hang off Easter Sunday, which
// is computed with the Anonymous Gregorian algorithm (the "Computus"). Midsummer
// and All Saints' Day float to a specific weekday within a fixed week.
//
// Two tiers:
//   official  — statutory public holidays (helgdagar), rendered full red.
//   de-facto  — days that are effectively off but not statutory (the "aftnar" +
//               Maundy Thursday), rendered a lighter red.
//
// Months are 0-based everywhere (m0) to match CalendarPopup's viewMonth / JS Date.
Singleton {
  id: root

  // Swedish month abbreviations (for the calendar's holiday name line).
  readonly property var monthsShort: [
    "jan", "feb", "mars", "apr", "maj", "juni",
    "juli", "aug", "sep", "okt", "nov", "dec"
  ]

  // ---- Easter Sunday (Gregorian Computus), returns a local Date ----
  function easterSunday(y) {
    var a = y % 19;
    var b = Math.floor(y / 100);
    var c = y % 100;
    var d = Math.floor(b / 4);
    var e = b % 4;
    var f = Math.floor((b + 8) / 25);
    var g = Math.floor((b - f + 1) / 3);
    var h = (19 * a + b - d - g + 15) % 30;
    var i = Math.floor(c / 4);
    var k = c % 4;
    var l = (32 + 2 * e + 2 * i - h - k) % 7;
    var m = Math.floor((a + 11 * h + 22 * l) / 451);
    var month = Math.floor((h + l - 7 * m + 114) / 31);   // 3 = March, 4 = April
    var day = ((h + l - 7 * m + 114) % 31) + 1;
    return new Date(y, month - 1, day);
  }

  // Date offset by n days from Easter Sunday.
  function fromEaster(y, n) {
    var e = easterSunday(y);
    return new Date(y, e.getMonth(), e.getDate() + n);
  }

  // The single day with the given weekday (0=Sun..6=Sat) inside a 7-day window
  // that starts at (m0, startDay). The window is exactly a week, so it hits once;
  // startDay+offset may roll into the next month (All Saints' Oct 31 -> Nov).
  function weekdayInWeek(y, m0, startDay, weekday) {
    var base = new Date(y, m0, startDay);
    var offset = (weekday - base.getDay() + 7) % 7;
    return new Date(y, m0, startDay + offset);
  }

  // ---- per-year holiday map, cached: { "m0-d": { name, official } } ----
  property var _cache: ({})

  function _key(m0, d) { return m0 + "-" + d; }

  function _build(y) {
    var map = {};
    function put(dt, name, official) {
      map[_key(dt.getMonth(), dt.getDate())] = { name: name, official: official };
    }

    // fixed official
    put(new Date(y, 0, 1),  "Nyårsdagen",              true);
    put(new Date(y, 0, 6),  "Trettondedag jul",        true);
    put(new Date(y, 4, 1),  "Första maj",              true);
    put(new Date(y, 5, 6),  "Sveriges nationaldag",    true);
    put(new Date(y, 11, 25), "Juldagen",               true);
    put(new Date(y, 11, 26), "Annandag jul",           true);

    // Easter-derived official
    put(fromEaster(y, -2), "Långfredagen",             true);
    put(fromEaster(y, 0),  "Påskdagen",                true);
    put(fromEaster(y, 1),  "Annandag påsk",            true);
    put(fromEaster(y, 39), "Kristi himmelsfärds dag",  true);
    put(fromEaster(y, 49), "Pingstdagen",              true);

    // floating official
    put(weekdayInWeek(y, 5, 20, 6),  "Midsommardagen", true);   // Sat 20–26 Jun
    put(weekdayInWeek(y, 9, 31, 6),  "Alla helgons dag", true); // Sat 31 Oct–6 Nov

    // de-facto days off (don't overwrite an official on the same key)
    function putSoft(dt, name) {
      var k = _key(dt.getMonth(), dt.getDate());
      if (!map[k]) map[k] = { name: name, official: false };
    }
    putSoft(fromEaster(y, -3), "Skärtorsdagen");
    putSoft(fromEaster(y, -1), "Påskafton");
    putSoft(weekdayInWeek(y, 5, 19, 5), "Midsommarafton"); // Fri 19–25 Jun
    putSoft(new Date(y, 11, 24), "Julafton");
    putSoft(new Date(y, 11, 31), "Nyårsafton");

    return map;
  }

  function _map(y) {
    if (!_cache[y]) {
      const c = _cache;
      c[y] = _build(y);
      _cache = c;   // reassign so the change is seen
    }
    return _cache[y];
  }

  // ---- public API (m0 is 0-based month) ----
  function entry(y, m0, d) { return _map(y)[_key(m0, d)] || null; }
  function isRedDay(y, m0, d)   { return entry(y, m0, d) !== null; }
  function isOfficial(y, m0, d) { var e = entry(y, m0, d); return e ? e.official : false; }
  function nameFor(y, m0, d)    { var e = entry(y, m0, d); return e ? e.name : ""; }
  function labelFor(y, m0, d) {
    var e = entry(y, m0, d);
    if (!e) return "";
    return d + " " + monthsShort[m0] + " · " + e.name;
  }
}
