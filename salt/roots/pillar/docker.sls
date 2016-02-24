docker:
  lookup:
    engine:
      version: 1.9.1
      opts:
        insecure-registry:
          - registry.marathon.mesos:31111
        storage-driver:
          - aufs
      users:
        - vagrant

    compose:
      version: 1.6.1
      completion: true

