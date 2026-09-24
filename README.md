# GitOps Repo — ArgoCD Deployments (multi-tenant)

This repo is what **ArgoCD watches**. `git push` = deploy. No manual `kubectl` for apps.

> Rule: **child Applications come ONLY from ApplicationSets.** Never hand-write one.
> The only hand-applied Applications are the per-tenant bootstrap roots at
> `tenants/<tenant>/<tenant>.yaml` (applied once via `tenants/bootstrap.sh`).

## Layout — tenants vs values, strictly separate

```
gitops/
├── tenants/                                        # ArgoCD configs ONLY
│   ├── bootstrap.sh                                # applies every <tenant>/<tenant>.yaml
│   └── <tenant>/
│       ├── <tenant>.yaml                           # ONE root per tenant (sources: dev+uat+prod)
│       └── <env>/                                  # dev | uat | prod
│           ├── project.yaml                        # RBAC: ONLY ns <tenant>-<env>
│           └── appset.yaml                         # generates child apps (git auto-discover)
├── values/                                         # Helm values ONLY (Backstage + CD write here)
│   ├── <tenant>/_tenant-defaults.yaml              # tenant-wide middle layer
│   └── <tenant>/<env>/<app>-values.yaml            # per-app overrides (app wins)
└── helm/                                           # ONE shared chart (generic-microservice)
    ├── values.yaml                                 # global defaults (base layer)
    └── templates/                                  # Deployment/Rollout/Service/HTTPRoute…
```

Live: `tenants/negd/dev|uat|prod` + `values/negd/...`,
`tenants/mparivahan/dev|uat|prod` + `values/mparivahan/...`.
Details: `tenants/README.md`.

## How it fits together

1. **Parent** (`tenants/<t>/<t>.yaml`, multi-`sources:`) syncs all 3 env folders →
   Projects (wave 0) + AppSets (wave 1). It keeps ArgoCD objects in sync only —
   apps themselves come from the AppSets watching `values/`.
2. **ApplicationSet** `git files:` on `values/<t>/<env>/*-values.yaml` → one child
   Application per values file (`<t>-<env>-<app>`, e.g. `negd-dev-api`).
3. Child renders `helm/` in 3 layers (later wins): `helm/values.yaml` →
   `values/<t>/_tenant-defaults.yaml` → app values file,
   into namespace `<t>-<env>` (`CreateNamespace=true`, `prune+selfHeal`).

```
push values/.../api-values.yaml → AppSet → child app → helm render → pods + Service + HTTPRoute
```

## Onboard / update (Backstage + CI via git only)

```bash
# new app in existing env — add values file, push, done:
# values/mparivahan/dev/worker-values.yaml  (route.host: worker-dev.mparivahan.tyagi.fun)
git add values/mparivahan/dev/worker-values.yaml
git commit -m "mparivahan/dev: add worker" && git push
# → AppSet auto-creates mparivahan-dev-worker in ns mparivahan-dev

# image update (CD job):
# yq -i '.image.tag = "abc1234"' values/negd/dev/api-values.yaml
# git commit -m "negd/dev api: abc1234" && git push  → auto-syncs
```

Naming: namespace = `<tenant>-<env>`, values file = `<app>-values.yaml`,
host = `<app>-<env>.<tenant>.tyagi.fun`, tag = immutable SHA (never `latest`).

## Bootstrap / verify

```bash
./tenants/bootstrap.sh                                # from gitops/ repo root
kubectl get applications -n argocd                    # 6 roots
kubectl get applicationsets -n argocd                 # 6 sets
```

All sets use single `repoURL: https://github.com/ot-central-team/gitops.git` + `HEAD`.

## Strategies (chart flags)

| `strategy` | Renders |
|---|---|
| `""` | plain `Deployment` |
| `bluegreen` | Argo Rollouts `Rollout` + `-candidate-service` preview |
| `canary` | Rollout + Kong HTTPRoute weighted split (needs Gateway API plugin) |

Set per app in its `values/.../<app>-values.yaml`. See `helm/values.yaml` for knobs.
