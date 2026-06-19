# Configuration Directory

This directory is reserved for deployment template configuration.

For `v1.0.0`, the intended configuration model is:

```text
config/
├── environments/
│   ├── development.yml
│   ├── staging.yml
│   └── production.yml
├── services.yml
└── nginx/
    ├── nginx.conf.tpl
    └── upstream.conf.tpl
```

The final design is documented in [../docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md) and summarized in [../docs/CONFIGURATION.md](../docs/CONFIGURATION.md).

Any current single-service `.env` files are early scaffold examples only. They should not be treated as the final v1 service registration model.
