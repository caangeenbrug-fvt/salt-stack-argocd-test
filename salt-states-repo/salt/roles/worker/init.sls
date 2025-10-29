{% set commit = pillar.get('gitops', {}).get('commit', 'unknown') %}
/etc/demo/worker-status.txt:
  file.managed:
    - makedirs: True
    - contents: |
        Worker node {{ grains['id'] }}
        Managed by panel master {{ pillar.get('panel_master', 'panelpc') }}
        Running commit: {{ commit }}
