# Architecture

The framework deploys an application artifact to one of two systemd-managed instances and directs proxy traffic to the healthy instance.

```text
config/services.yml
        |
        v
artifact -> releases/<release_id>/artifact
                       |
                       v
             current symlink
                       |
             +---------+---------+
             |                   |
        blue systemd        green systemd
         blue_port           green_port
             \                   /
              +--- health check-+
                       |
                       v
              Apache or NGINX
                  public_port
```

## Service configuration

`config/services.yml` defines the runtime, ports, health path, deploy path, proxy, retention policy, and service commands. Scripts resolve a service by `service_name` and validate the registry before changing deployment state.

## Artifact and release directory

`deploy.sh` passes an artifact file or directory to `create-release.sh`. Each deployment receives an immutable release directory:

```text
<deploy_path>/
├── current -> releases/<release_id>
├── releases/
│   └── <release_id>/
│       ├── artifact/
│       └── release.json
├── shared/
│   └── .env
├── logs/
└── state/
    ├── active_color
    └── release-history.log
```

The `current` symlink points to the release selected for start-up. Retention removes older release directories while preserving the configured number of recent releases.

## Blue and green systemd units

Onboarding generates one unit per color. Both units use the release selected by `current` and the shared environment file, but each receives a distinct `PORT` and `ACTIVE_COLOR` from its generated unit. At start-up, the unit derives `RELEASE_ID` from the resolved release directory for application metadata.

Only one color receives public traffic. Keeping separate processes and ports allows the inactive color to start and become healthy before promotion.

## Health validation and proxy switch

`deploy.sh` determines the inactive color, starts it with the new release, and checks `http://127.0.0.1:<color_port><health_path>`. A failed health check stops the flow before proxy configuration or active-color state changes.

After validation, `switch-traffic.sh` renders and validates the Apache or NGINX configuration, installs it, reloads the proxy, and records the new active color.

## State, history, and rollback

The state directory records the active color and an append-only release history. `show-state.sh` exposes the active color, inactive color, current symlink, latest history entry, and lock status.

`rollback.sh` selects the previous successful retained release unless a release ID is supplied. It points `current` to that release, starts it on the inactive color, validates health, switches traffic, and records the rollback. If start-up, health validation, or switching fails, it restores the previous `current` target. It does not delete release history or automatically stop the old color.

## Safety boundaries

- Build artifacts are created outside privileged steps.
- Candidate health is checked before traffic changes.
- Managed system files are replaced only when they match or `onboard.sh --force` is explicit.
- Deployment locks prevent concurrent release creation for one service.
- Shared runtime configuration remains outside immutable release directories.
