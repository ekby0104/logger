/* HaruLog wireframe — vanilla JS implementation of 하루로그-wireframe.dc.html */
(function () {
  'use strict';

  var INK = '#131826', BLUE = '#0967F5', PURPLE = '#A855F7', MUTED = '#9FA5B2';
  var MOODS = ['Fresh', 'Calm', 'Happy', 'Peaceful', 'Moved', 'Proud'];

  var state = {
    tab: 'today',
    overlay: null,
    recording: false,
    elapsed: 0,
    segments: [],
    facing: 0,
    draftMood: 'Calm',
    draftCaption: '',
    selectedDay: 18,
    viewerId: null,
    toast: null,
    moments: [
      { id: 'a', time: '07:20', title: 'Morning Run', place: 'Ttukseom, Han River', mood: 'Fresh', dur: '0:18', caption: 'Opened the day with a run by the sunrise river.' },
      { id: 'b', time: '09:05', title: 'Morning Coffee', place: 'Onion Seongsu', mood: 'Calm', dur: '0:12', caption: 'A warm latte to get things started.' },
      { id: 'c', time: '12:40', title: 'Lunch Pasta', place: 'Euljiro Alley', mood: 'Happy', dur: '0:25', caption: 'Vongole with coworkers — best meal today.' },
      { id: 'd', time: '15:30', title: 'Afternoon Walk', place: 'Seoul Forest', mood: 'Peaceful', dur: '0:20', caption: 'Afternoon light seeping through the trees.' },
      { id: 'e', time: '19:15', title: 'Evening Glow', place: 'Namsan Deck', mood: 'Moved', dur: '0:30', caption: 'A red sky spreading over the city.' },
      { id: 'f', time: '22:00', title: 'Winding Down', place: 'Home', mood: 'Proud', dur: '0:15', caption: 'Made it through today. Goodnight.' }
    ]
  };

  var timerId = null, toastId = null;

  /* ---------- icons ---------- */
  function icon(paths, size, sw, fill) {
    return '<svg width="' + size + '" height="' + size + '" viewBox="0 0 24 24" fill="' + (fill || 'none') +
      '" stroke="currentColor" stroke-width="' + (sw || 2) + '" stroke-linecap="round" stroke-linejoin="round">' + paths + '</svg>';
  }
  var IC = {
    camera: function (s) { return icon('<rect x="2" y="6" width="14" height="12" rx="3"/><path d="M16 10l6-3v10l-6-3z"/>', s); },
    flame: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="' + PURPLE + '" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3c1 3 3 4 3 8a3 3 0 0 1-6 0c0-1 .5-2 .5-2 .5 1.5 1.5 1.5 1.5 1.5 0-3-1-4.5-2.5-6.5"/><path d="M12 3c0 2-3 3-3 8a3 3 0 0 0 6 0"/></svg>',
    sparkle: function (s) { return icon('<path d="M12 3l2 6 6 2-6 2-2 6-2-6-6-2 6-2z"/>', s); },
    pin: function (s) { return icon('<path d="M12 21s7-6 7-11a7 7 0 0 0-14 0c0 5 7 11 7 11z"/><circle cx="12" cy="10" r="2.5"/>', s); },
    chevron: icon('<path d="M9 5l7 7-7 7"/>', 18, 2.4),
    play: '<svg width="15" height="15" viewBox="0 0 24 24" fill="currentColor" stroke="currentColor" stroke-width="1" stroke-linejoin="round"><path d="M7 5l12 7-12 7z"/></svg>',
    home: icon('<path d="M4 11l8-7 8 7"/><path d="M6 10v9h12v-9"/>', 23),
    list: icon('<path d="M8 6h12M8 12h12M8 18h12"/><circle cx="4" cy="6" r="1"/><circle cx="4" cy="12" r="1"/><circle cx="4" cy="18" r="1"/>', 23),
    calendar: icon('<rect x="3" y="5" width="18" height="16" rx="3"/><path d="M3 9h18M8 3v4M16 3v4"/>', 23),
    user: function (s, sw) { return icon('<circle cx="12" cy="8" r="4"/><path d="M4 20c0-4 4-6 8-6s8 2 8 6"/>', s, sw); },
    close: icon('<path d="M6 6l12 12M18 6L6 18"/>', 20, 2.4),
    flip: icon('<path d="M4 9a8 8 0 0 1 14-3l2 2M20 15a8 8 0 0 1-14 3l-2-2"/><path d="M18 4v4h-4M6 20v-4h4"/>', 20),
    gallery: icon('<rect x="3" y="4" width="18" height="16" rx="3"/><path d="M3 16l5-5 4 4 3-3 6 6"/><circle cx="8.5" cy="9" r="1.5"/>', 22),
    arrowRight: icon('<path d="M4 12h16M14 6l6 6-6 6"/>', 24, 2.4),
    arrowLeft: icon('<path d="M20 12H4M10 6l-6 6 6 6"/>', 24, 2.4),
    check: icon('<path d="M5 13l4 4L19 7"/>', 20, 2.4),
    checkCircle: icon('<circle cx="12" cy="12" r="9"/><path d="M8 12l3 3 5-6"/>', 19, 2.2),
    clock: icon('<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 3"/>', 18),
    pencil: icon('<path d="M4 20l4-1L20 7l-3-3L5 16z"/>', 16),
    settings: icon('<circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3M5 5l2 2M17 17l2 2M19 5l-2 2M7 17l-2 2"/>', 20)
  };

  function esc(str) {
    return String(str).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }

  function fmt(s) {
    return Math.floor(s / 60) + ':' + String(s % 60).padStart(2, '0');
  }

  function setState(patch) {
    Object.assign(state, patch);
    render();
  }

  /* ---------- actions (exposed for inline handlers) ---------- */
  var App = window.App = {
    setTab: function (t) { setState({ tab: t }); },
    openCamera: function () { setState({ overlay: 'camera', recording: false, elapsed: 0, segments: [] }); },
    closeOverlay: function () {
      clearInterval(timerId);
      setState({ overlay: null, recording: false, elapsed: 0, segments: [] });
    },
    flipCam: function () { setState({ facing: state.facing ? 0 : 1 }); },

    toggleRecord: function () {
      if (state.recording) {
        clearInterval(timerId);
        setState({ recording: false, segments: state.segments.concat([state.elapsed || 1]), elapsed: 0 });
      } else {
        setState({ recording: true });
        timerId = setInterval(function () { setState({ elapsed: state.elapsed + 1 }); }, 1000);
      }
    },

    toNext: function () {
      var total = state.segments.reduce(function (a, b) { return a + b; }, 0) + state.elapsed;
      if (total <= 0) { App.flashToast('Record a moment first'); return; }
      clearInterval(timerId);
      setState({ overlay: 'edit', recording: false });
    },

    setCaption: function (value) { state.draftCaption = value; }, // no re-render: keep textarea focus
    setMood: function (m) { setState({ draftMood: m }); },

    saveMoment: function () {
      var total = state.segments.reduce(function (a, b) { return a + b; }, 0) + state.elapsed || 14;
      var nm = {
        id: 'n' + Date.now(),
        time: '20:12',
        title: state.draftCaption ? state.draftCaption.slice(0, 14) : 'New moment',
        place: 'Seongsu-dong, Seoul',
        mood: state.draftMood,
        dur: '0:' + String(Math.max(total, 5)).padStart(2, '0'),
        caption: state.draftCaption || 'A moment just captured.'
      };
      clearInterval(timerId);
      setState({
        moments: state.moments.concat([nm]),
        overlay: null, tab: 'today', draftCaption: '', recording: false, elapsed: 0, segments: []
      });
      App.flashToast('Saved to your timeline');
    },

    makeBlog: function () { App.flashToast('Your daily blog is ready'); },

    openViewer: function (id) { setState({ viewerId: id, overlay: 'viewer' }); },
    closeViewer: function () { setState({ overlay: null, viewerId: null }); },
    editFromViewer: function () {
      var m = state.moments.find(function (x) { return x.id === state.viewerId; });
      setState({ overlay: 'edit', draftCaption: m ? m.caption : '', draftMood: m ? m.mood : 'Calm' });
    },
    selectDay: function (d) { setState({ selectedDay: d }); },

    flashToast: function (msg) {
      clearTimeout(toastId);
      setState({ toast: msg });
      toastId = setTimeout(function () { setState({ toast: null }); }, 2400);
    }
  };

  /* ---------- views ---------- */
  function moodPill(mood) {
    return '<span class="mood-pill">' + esc(mood) + '</span>';
  }

  function todayView() {
    var reel = state.moments.slice(0, 6).map(function () {
      return '<div class="hero-reel-thumb"></div>';
    }).join('');

    var cards = state.moments.map(function (m) {
      return '' +
        '<div class="moment-card" onclick="App.openViewer(\'' + m.id + '\')">' +
          '<div class="moment-thumb"><div class="dur-badge">' + esc(m.dur) + '</div></div>' +
          '<div class="moment-body">' +
            '<div class="moment-meta"><span class="moment-time">' + esc(m.time) + '</span>' + moodPill(m.mood) + '</div>' +
            '<div class="moment-title">' + esc(m.title) + '</div>' +
            '<div class="moment-place">' + IC.pin(13) + esc(m.place) + '</div>' +
          '</div>' +
          '<div class="moment-chevron">' + IC.chevron + '</div>' +
        '</div>';
    }).join('');

    return '' +
      '<div class="tab-view hl-scroll">' +
        '<div class="view-header">' +
          '<div><div class="eyebrow">Sat, Jul 18</div><div class="h1">Today</div></div>' +
          '<div class="streak-pill">' + IC.flame + '12 days</div>' +
        '</div>' +
        '<div class="hero-card">' +
          '<div class="hero-label">Moments today</div>' +
          '<div class="hero-count">' +
            '<span class="hero-count-num">' + state.moments.length + '</span>' +
            '<span class="hero-count-meta">clips · 2m 15s</span>' +
          '</div>' +
          '<div class="hero-reel">' + reel + '</div>' +
          '<button class="btn-primary" onclick="App.makeBlog()">' + IC.sparkle(18) + 'Create daily blog</button>' +
        '</div>' +
        '<div class="section-title">Moments</div>' +
        '<div class="moment-list">' + cards + '</div>' +
      '</div>';
  }

  function timelineView() {
    var entries = state.moments.map(function (m) {
      return '' +
        '<div class="tl-entry">' +
          '<div class="tl-time">' + esc(m.time) + '</div>' +
          '<div class="tl-dot"></div>' +
          '<div class="tl-card" onclick="App.openViewer(\'' + m.id + '\')">' +
            '<div class="tl-media">' +
              '<div class="tl-media-badges">' +
                '<div class="tl-play">' + IC.play + '</div>' +
                '<span class="tl-dur">' + esc(m.dur) + '</span>' +
              '</div>' +
            '</div>' +
            '<div class="tl-body">' +
              '<div class="tl-head"><div class="tl-title">' + esc(m.title) + '</div>' + moodPill(m.mood) + '</div>' +
              '<div class="tl-caption">' + esc(m.caption) + '</div>' +
            '</div>' +
          '</div>' +
        '</div>';
    }).join('');

    return '' +
      '<div class="tab-view hl-scroll">' +
        '<div class="h1" style="margin-bottom:3px;">Timeline</div>' +
        '<div class="sub" style="margin-bottom:22px;">Sat, Jul 18 · ' + state.moments.length + ' moments</div>' +
        '<div class="tl-wrap"><div class="tl-line"></div><div class="tl-list">' + entries + '</div></div>' +
      '</div>';
  }

  var BLOG_DAYS = [1, 2, 3, 5, 6, 8, 9, 10, 12, 13, 15, 16, 17, 18];

  function calendarView() {
    var blogSet = {};
    BLOG_DAYS.forEach(function (d) { blogSet[d] = true; });

    var weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map(function (w) {
      return '<div class="cal-weekday">' + w + '</div>';
    }).join('');

    var cells = [];
    var firstDow = new Date(2026, 6, 1).getDay();
    for (var i = 0; i < firstDow; i++) {
      cells.push('<div class="cal-cell" style="background:transparent;border:2px solid transparent;"></div>');
    }
    for (var d = 1; d <= 31; d++) {
      var has = !!blogSet[d];
      var today = d === 18;
      var sel = d === state.selectedDay;
      var bg = sel ? BLUE : has ? '#fff' : '#F1F3F7';
      var border = sel ? '2px solid ' + INK : today ? '2px solid ' + BLUE : '2px solid ' + INK;
      var fg = sel ? '#fff' : has ? INK : MUTED;
      var dot = sel ? '#fff' : PURPLE;
      cells.push('' +
        '<div class="cal-cell" style="background:' + bg + ';border:' + border + ';cursor:' + (has ? 'pointer' : 'default') + ';"' +
          (has ? ' onclick="App.selectDay(' + d + ')"' : '') + '>' +
          '<span class="cal-day" style="color:' + fg + ';">' + d + '</span>' +
          (has ? '<div class="cal-dot" style="background:' + dot + ';"></div>' : '') +
        '</div>');
    }

    var selHasBlog = !!blogSet[state.selectedDay];
    var selectedMeta = selHasBlog
      ? (3 + state.selectedDay % 4) + ' moments · blog ready'
      : 'No records';
    var reel = [0, 1, 2, 3].map(function () { return '<div class="cal-reel-thumb"></div>'; }).join('');

    return '' +
      '<div class="tab-view hl-scroll">' +
        '<div class="h1" style="margin-bottom:3px;">July 2026</div>' +
        '<div class="sub" style="margin-bottom:20px;">You logged ' + BLOG_DAYS.length + ' days this month</div>' +
        '<div class="cal-weekdays">' + weekdays + '</div>' +
        '<div class="cal-grid">' + cells.join('') + '</div>' +
        '<div class="cal-detail">' +
          '<div class="cal-detail-head">' +
            '<div class="cal-detail-title">July ' + state.selectedDay + '</div>' +
            '<span class="cal-detail-meta">' + selectedMeta + '</span>' +
          '</div>' +
          '<div class="cal-reel">' + reel + '</div>' +
        '</div>' +
      '</div>';
  }

  function meView() {
    var stats = [
      { value: '12', label: 'Streak' },
      { value: '48', label: 'Blogs' },
      { value: '312', label: 'Moments' }
    ].map(function (s) {
      return '<div class="me-stat"><div class="me-stat-value">' + s.value + '</div><div class="me-stat-label">' + s.label + '</div></div>';
    }).join('');

    var archive = [17, 16, 15, 13, 12, 10, 9, 8, 6].map(function (d) {
      return '' +
        '<div class="archive-cell">' +
          '<div class="archive-day">7/' + d + '</div>' +
          '<div class="archive-count">' + (2 + (d % 5)) + ' clips</div>' +
        '</div>';
    }).join('');

    return '' +
      '<div class="tab-view hl-scroll">' +
        '<div class="me-header">' +
          '<div class="me-avatar">' + IC.user(34, 1.8) + '</div>' +
          '<div class="me-id">' +
            '<div class="me-name">Jiwoo’s Days</div>' +
            '<div class="me-handle">@jiwoo.daily</div>' +
          '</div>' +
          '<div class="me-settings">' + IC.settings + '</div>' +
        '</div>' +
        '<div class="me-stats">' + stats + '</div>' +
        '<div class="me-archive-head">' +
          '<div class="section-title">Past daily blogs</div>' +
          '<span class="me-archive-total">48 total</span>' +
        '</div>' +
        '<div class="archive-grid">' + archive + '</div>' +
      '</div>';
  }

  function bottomNav() {
    function navBtn(tab, iconHtml, label) {
      var active = state.tab === tab && !state.overlay;
      return '' +
        '<button class="nav-btn" style="color:' + (active ? BLUE : MUTED) + ';" onclick="App.setTab(\'' + tab + '\')">' +
          iconHtml + '<span>' + label + '</span>' +
        '</button>';
    }
    return '' +
      '<div class="bottomnav">' +
        navBtn('today', IC.home, 'Today') +
        navBtn('timeline', IC.list, 'Timeline') +
        '<div class="nav-fab-wrap"><button class="nav-fab" onclick="App.openCamera()">' + IC.camera(26) + '</button></div>' +
        navBtn('calendar', IC.calendar, 'Calendar') +
        navBtn('my', IC.user(23, 2), 'Me') +
      '</div>';
  }

  function cameraOverlay() {
    var recording = state.recording;
    var hasRec = state.segments.length > 0 || state.elapsed > 0;

    var segs = state.segments.map(function (sec) {
      return '<div class="cam-seg" style="width:' + Math.min(sec * 7, 60) + 'px;"></div>';
    }).join('');

    var moods = MOODS.map(function (mo) {
      var on = mo === state.draftMood;
      return '<button class="cam-mood" style="border:2px solid #fff;background:' +
        (on ? PURPLE : 'rgba(19,24,38,.45)') + ';color:#fff;" onclick="App.setMood(\'' + mo + '\')">' + mo + '</button>';
    }).join('');

    return '' +
      '<div class="overlay-camera">' +
        '<div class="cam-gradient"></div>' +
        '<div class="cam-top">' +
          '<button class="cam-icon-btn" onclick="App.closeOverlay()">' + IC.close + '</button>' +
          '<div class="cam-center">' +
            '<div class="cam-timer">' +
              '<span class="cam-timer-dot" style="background:' + (recording ? '#DC0A0A' : 'rgba(255,255,255,.6)') +
                ';animation:' + (recording ? 'hlpulse 1s infinite' : 'none') + ';"></span>' +
              '<span class="cam-timer-label">' + fmt(state.elapsed) + '</span>' +
            '</div>' +
            '<div class="cam-location">' + IC.pin(13) + 'Seongsu, Seoul · 8:12 PM</div>' +
          '</div>' +
          '<button class="cam-icon-btn" onclick="App.flipCam()">' + IC.flip + '</button>' +
        '</div>' +
        '<div class="cam-segbar">' + segs + '<div class="cam-seg-rest"></div></div>' +
        '<div class="cam-bottom">' +
          '<div class="cam-moods hl-scroll">' + moods + '</div>' +
          '<div class="cam-controls">' +
            '<div class="cam-gallery">' + IC.gallery + '</div>' +
            '<button class="cam-record" onclick="App.toggleRecord()">' +
              '<span class="cam-record-inner" style="width:' + (recording ? '26px' : '60px') + ';height:' + (recording ? '26px' : '60px') +
                ';border-radius:' + (recording ? '7px' : '999px') + ';"></span>' +
            '</button>' +
            '<button class="cam-next" style="border:2px solid ' + (hasRec ? '#fff' : 'rgba(255,255,255,.6)') +
              ';background:' + (hasRec ? '#fff' : 'rgba(19,24,38,.35)') +
              ';color:' + (hasRec ? INK : 'rgba(255,255,255,.5)') +
              ';cursor:' + (hasRec ? 'pointer' : 'default') + ';" onclick="App.toNext()">' + IC.arrowRight + '</button>' +
          '</div>' +
        '</div>' +
      '</div>';
  }

  function editOverlay() {
    var total = state.segments.reduce(function (a, b) { return a + b; }, 0) + state.elapsed;
    var draftDur = '0:' + String(Math.max(total, 5)).padStart(2, '0');

    var moods = MOODS.map(function (mo) {
      var on = mo === state.draftMood;
      return '<button class="edit-mood" style="background:' + (on ? PURPLE : '#fff') +
        ';color:' + (on ? '#fff' : INK) +
        ';box-shadow:' + (on ? '3px 3px 0 ' + INK : 'none') + ';" onclick="App.setMood(\'' + mo + '\')">' + mo + '</button>';
    }).join('');

    return '' +
      '<div class="overlay-edit hl-scroll">' +
        '<div class="edit-header">' +
          '<button class="edit-back" onclick="App.closeOverlay()">' + IC.arrowLeft + '</button>' +
          '<span class="edit-title">Edit moment</span>' +
          '<span class="edit-header-spacer"></span>' +
        '</div>' +
        '<div class="edit-body">' +
          '<div class="edit-preview">' +
            '<div class="edit-preview-badges"><span class="edit-dur">' + draftDur + '</span></div>' +
          '</div>' +
          '<div class="edit-label">Caption</div>' +
          '<textarea class="edit-caption" placeholder="Write a line about this moment" oninput="App.setCaption(this.value)">' + esc(state.draftCaption) + '</textarea>' +
          '<div class="edit-label edit-label--gap">Mood</div>' +
          '<div class="edit-moods">' + moods + '</div>' +
          '<div class="edit-label edit-label--gap">Location · Time</div>' +
          '<div class="edit-rows">' +
            '<div class="edit-row">' + IC.pin(18) + 'Seongsu-dong, Seoul</div>' +
            '<div class="edit-row">' + IC.clock + 'Today 8:12 PM</div>' +
          '</div>' +
          '<button class="edit-save" onclick="App.saveMoment()">' + IC.check + 'Save to timeline</button>' +
        '</div>' +
      '</div>';
  }

  function viewerOverlay() {
    var vm = state.moments.find(function (x) { return x.id === state.viewerId; }) || state.moments[0];
    var vIdx = state.moments.findIndex(function (x) { return x.id === state.viewerId; });

    var bars = state.moments.map(function (_, i) {
      return '<div class="viewer-bar" style="background:' + (i <= vIdx ? '#fff' : 'rgba(255,255,255,.3)') + ';"></div>';
    }).join('');

    return '' +
      '<div class="overlay-viewer">' +
        '<div class="viewer-gradient"></div>' +
        '<div class="viewer-bars">' + bars + '</div>' +
        '<button class="viewer-close" onclick="App.closeViewer()">' + IC.close + '</button>' +
        '<div class="viewer-info">' +
          '<div class="viewer-meta">' +
            '<span class="viewer-time">' + esc(vm.time) + '</span>' +
            '<span class="viewer-mood">' + esc(vm.mood) + '</span>' +
          '</div>' +
          '<div class="viewer-title">' + esc(vm.title) + '</div>' +
          '<div class="viewer-caption">' + esc(vm.caption) + '</div>' +
          '<div class="viewer-footer">' +
            '<div class="viewer-place">' + IC.pin(15) + esc(vm.place) + '</div>' +
            '<span class="viewer-spacer"></span>' +
            '<button class="viewer-edit" onclick="App.editFromViewer()">' + IC.pencil + 'Edit</button>' +
          '</div>' +
        '</div>' +
      '</div>';
  }

  function toastEl() {
    if (!state.toast) return '';
    return '<div class="toast">' + IC.checkCircle + esc(state.toast) + '</div>';
  }

  /* ---------- render ---------- */
  function render() {
    var tab = '';
    if (state.tab === 'today') tab = todayView();
    else if (state.tab === 'timeline') tab = timelineView();
    else if (state.tab === 'calendar') tab = calendarView();
    else if (state.tab === 'my') tab = meView();

    var overlay = '';
    if (state.overlay === 'camera') overlay = cameraOverlay();
    else if (state.overlay === 'edit') overlay = editOverlay();
    else if (state.overlay === 'viewer') overlay = viewerOverlay();

    document.getElementById('app').innerHTML = tab + bottomNav() + overlay + toastEl();
  }

  render();
})();
