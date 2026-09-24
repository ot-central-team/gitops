# Tenants — ArgoCD configs ONLY (values live in `values/`)

```
tenants/
├── bootstrap.sh                        # applies every <tenant>/<tenant>.yaml (only manual step)
└── <tenant>/
    ├── <tenant>.yaml                   # ONE bootstrap root per tenant (sources: dev+uat+prod)
    └── <env>/                          # dev | uat | prod
        ├── project.yaml                # RBAC: may deploy ONLY to ns <tenant>-<env>
        └── appset.yaml                 # generates child apps (git auto-discover)
```

Live: `negd/negd.yaml` → namespaces `negd-dev|uat|prod`,
`mparivahan/mparivahan.yaml` → namespaces `mparivahan-dev|uat|prod`.

## How it works

1. Tenant root (`<tenant>.yaml`, multi-`sources:`) syncs all 3 env folders →
   Projects (wave 0) + AppSets (wave 1).
2. Project allows ONLY namespace `<tenant>-<env>`. No cross-tenant deploy.
3. AppSet `git files:` on `values/<tenant>/<env>/*-values.yaml` → one child Application
   per values file: `<tenant>-<env>-<app>` (e.g. `negd-dev-api`).
   Adding a file = new app. No `list:` edits, ever.
4. Child renders shared `helm/` chart in 3 layers (later wins):
   `helm/values.yaml` → `values/<tenant>/_tenant-defaults.yaml` → app values file,
   into namespace `<tenant>-<env>` (`CreateNamespace=true`, `prune+selfHeal`).

Note: the parent does NOT deploy apps — it only keeps Projects + AppSets in sync.
New apps come from the AppSets watching `values/` (already in cluster, always watching).

Rule: **child Applications come ONLY from ApplicationSets.** Never hand-write one.

## New tenant — copy one folder

```bash
cp -r tenants/mparivahan tenants/newtenant
mv tenants/newtenant/mparivahan.yaml tenants/newtenant/newtenant.yaml
# sed s/mparivahan/newtenant/ in newtenant.yaml + every env project/appset.yaml
mkdir -p values/newtenant/{dev,uat,prod}   # + _tenant-defaults.yaml + first app values
# push, then once:
kubectl apply -f tenants/newtenant/newtenant.yaml
# or all: ./tenants/bootstrap.sh   (from gitops/ root)
```
