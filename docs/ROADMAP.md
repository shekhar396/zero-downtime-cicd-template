# Roadmap

## v1.0.0

The v1 release focuses on blue/green application deployment to Linux VMs with:

- systemd-managed blue and green processes
- Apache or NGINX traffic switching
- candidate health validation
- immutable release directories and retention
- active-color state and release history
- rollback to a retained release
- first-time onboarding and Jenkins-compatible deployment commands

Release readiness requires a clean installation from [Quick Start](QUICK_START.md), successful deployment and rollback on representative VMs, accurate documentation, and no private or obsolete example data.

## v1.x hardening

Potential improvements that preserve the VM deployment model include:

- broader Linux distribution compatibility testing
- stronger configuration validation
- richer deployment event reporting
- additional automated tests for proxy and rollback failures
- security and least-privilege guidance

Items are not commitments until implemented and released.

## Future scope

Docker, Kubernetes, Helm, service mesh, autoscaling, cloud infrastructure, and database migration automation are outside v1. They may be evaluated in a future major release without changing the v1 Linux VM focus.
