{% set commit = pillar.get('gitops', {}).get('commit', 'unknown') %}
/etc/demo/panel-config.txt:
  file.managed:
    - makedirs: True
    - contents: |
        Panel node {{ grains['id'] }}
        Synced commit: {{ commit }}
        Syndic master: {{ pillar.get('syndic_master', 'cloud-master') }}
