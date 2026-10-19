// English panel dictionary. Keys mirror ru.js (the fallback dictionary).

export const en = {
  'header.subtitle': 'DN1Sup · settings apply instantly',
  'header.helpTitle': 'Help',
  'header.checkUpdateTitle': 'Check for updates (GitHub Releases)',

  'theme.toLight': 'Switch to light theme',
  'theme.toDark': 'Switch to dark theme',
  'lang.toEn': 'Switch to English',
  'lang.toRu': 'Switch to Russian',

  'apply.button': 'Apply',
  'apply.running': 'Working…',
  'apply.hintNoTargets': 'Select a component or group',
  'apply.hintBoth': 'Will run: rotation plus top and side views',
  'apply.hintRotate': 'Will run: rotation',
  'apply.hintViews': 'Will run: top and side views',
  'apply.hintNone': 'Tick at least one operation',

  'selection.targets': 'Selected objects: {targets} — preview and operations available',
  'selection.noTargets': 'Selected: {total}, but no components or groups among them — select a component or group',
  'selection.empty': 'Select a component or group in the model',

  'busy.applying': 'Applying…',

  'toast.notSaved': 'Not saved: {message}',
  'toast.notDone': 'Not done: select a component or group',
  'toast.appliedBoth': 'Rotation and projections applied (Ctrl+Z undoes step by step)',
  'toast.appliedRotate': 'Rotation applied (Ctrl+Z to undo)',
  'toast.appliedViews': 'Projections created (Ctrl+Z to undo)',
  'toast.error': 'Error: {message}',
  'toast.updateDone': 'Update installed — restart SketchUp',

  'section.rotate.title': 'Rotation',
  'section.rotate.desc':
    'The copy shifts left by the object width plus offset (or rotates in place), then rotates around the insertion point: first Z (30–70°, +180° toggle), then X (30–70°).',
  'section.views.title': 'Top and side view',
  'section.views.desc':
    'The “top view” copy goes above the object, the “side view” copy goes to the right; offset is a percentage. The switch picks the view direction: right view (Z −90°) or left view (Z +90°).',

  'rotate.copyLeft': 'Copy on the left',
  'rotate.rot180': '+180° to Z',
  'rotate.angleZ': 'Z angle',
  'rotate.angleX': 'X angle',

  'views.sideLabel': 'Side view',
  'views.sideRight': 'Right',
  'views.sideLeft': 'Left',
  'views.offset': 'Offset',

  'scheme.topPlan': 'top view (plan)',
  'scheme.thenX': 'then ↻ X',
  'scheme.topView': 'top view',
  'scheme.source': 'source',
  'scheme.sideView': 'side view',
  'scheme.sideLeft': 'left view',
  'scheme.sideRight': 'right view',
  'scheme.shiftWidth': 'shift by width + {offset}%',
  'scheme.copyLeft': 'copy on the left',
  'scheme.inPlace': 'rotate in place',
  'scheme.sidePrefix': 'side: {side} view',
  'scheme.offsetPrefix': 'offset: {offset}%',

  'status.checking': 'Checking for updates…',
  'status.found': 'Version {latest} available (you have {current}) — confirm install in the dialog',
  'status.downloading': 'Downloading update… {percent}%',
  'status.installing': 'Installing update…',
  'status.done': 'Update installed — restart SketchUp',
  'status.current': 'You have the latest version {current}',
  'status.dismissed': 'Update postponed',
  'status.error': 'Update error: {message}',
  'status.githubUnreachable': 'GitHub is unreachable — check for updates later',
  'status.devCopy':
    'Dev-folder working copy: updates come from the working folder, GitHub check is disabled',

  'help.title': 'Help · Comp Add View',
  'help.close': 'Close',
  'help.closeAria': 'Close help',
  'help.whatTitle': 'What it does',
  'help.whatText':
    'Duplicates the selected components and groups. “Rotation” — the copy shifts left by the object width plus offset (or rotates in place) and rotates around the insertion point: first around Z (30–70°, +180° toggle), then around X (30–70°). “Top and side view” — creates projection copies: above the object and to its right (or left) with the given percentage offset.',
  'help.workflowTitle': 'Workflow',
  'help.step1': 'Select a component or group in the model.',
  'help.step2': 'Tune the parameters — the panel scheme and the 3D preview update instantly.',
  'help.step3':
    'Tick the operations in the section headers and press “Apply”. Undo is Ctrl+Z; the preview clears itself when selection or tool changes.',
  'help.settingsTitle': 'Settings',
  'help.settingsText': 'Saved automatically and applied instantly — there is no separate settings dialog.',
  'help.updatesTitle': 'Updates',
  'help.updatesText':
    'The round button in the header checks GitHub releases; check and install status shows in the status bar at the panel bottom. Restart SketchUp after installing an update.',
  'help.releasesPage': 'GitHub releases page'
}
