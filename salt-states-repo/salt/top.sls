base:
  'panelpc*':
    - match: glob
    - roles.panel
  'worker*':
    - match: glob
    - roles.worker
