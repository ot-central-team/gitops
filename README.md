# GitOps Repo — ArgoCD Deployments

This repository is what **ArgoCD watches** to deploy applications. Everything
under it is declarative: the cluster is always an exact render of what's here,
and a `git push` triggers an ArgoCD auto-sync (GitOps).

> Set up through the parent walkthrough: `../README.md`. This file documents the
> repo itself — how it's organized and how to add a new app/strategy.

---

## How it fits together (app-of-apps)

```
gitops/
├── argocd/                      ← BOOTSTRAP (one-time, applied by an admin)
│   ├── parents/                 ← root Applications (the "app of apps")
│   │   ├── dev-environment.yaml
│   │   └── prod-environment.yaml
│   ├── dev/
│   │   ├── dev-project.yaml     ← AppProject: what this project may touch
│   │   └── dev-appset.yaml      ← ApplicationSet: generates child apps
│   └── prod/
│       ├── prod-project.yaml
│       └── prod-appset.yaml
├── helm/                        ← SHARED chart (generic-microservice)
│   ├── Chart.yaml
│   ├── values.yaml              ← base defaults for every app
│   └── templates/               ← Deployment / Rollout / Service / HTTPRoute …
└── applications/                ← PER‑APP overrides
    ├── dev/<app>-values.yaml
    └── prod/<app>-values.yaml
```

1. **Parent** (`argocd/parents/*.yaml`) points at `argocd/<env>/` → creates the
   `AppProject` + `ApplicationSet`.
2. **ApplicationSet** generates **one child Application per app** (from its
   `list` of app names) using the shared `helm/` chart.
3. Each child Application feeds the chart **`helm/values.yaml` + the app's own
   `applications/<env>/<app>-values.yaml`**, merges them (app wins), and syncs
   the rendered manifests into its namespace.

```
push to gitops → ArgoCD (child app) → helm render (base + app values)
             → apply Deployment/Rollout + Service + HTTPRoute → pods
```

---

## Onboarding a new app (e.g. `my-app`)

Add it to **both** ApplicationSets, then push:

```yaml
# argocd/dev/dev-appset.yaml   (and prod/prod-appset.yaml)
generators:
  - list:
      elements:
        - app: python-demo-for-dashboard   # existing
        - app: my-app                      # ← add this
```

Create its per-env values files:

```yaml
# applications/dev/my-app-values.yaml
image:
  repository: <ECR repo URL>
  tag: <git-sha>
replicaCount: 2
route:
  enabled: true
  host: my-app-dev.tyagi.fun
probes:
  enabled: true
  liveness: { path: /health }
  readiness: { path: /health }
```

**Commit → push → ArgoCD auto-syncs.** Then expose it: add a Kong route +
DNS CNAME (see parent `README.md` §"Adding a new app").

---

## Choosing a rollout strategy

`helm/values.yaml` ships a flag that switches how pods are updated:

| `strategy`        | What happens                                         |
|-------------------|------------------------------------------------------|
| `""` (default)    | plain Kubernetes `Deployment` (in-place, rolling)    |
| `bluegreen`       | Argo Rollouts — active + preview ReplicaSets, flip on promote |
| `canary`          | (future) Argo Rollouts + Kong weighted traffic split |

Set it in an app's values file:

```yaml
# applications/dev/my-app-values.yaml
strategy: bluegreen
blueGreen:
  autoPromotionEnabled: true
  scaleDownDelaySeconds: 60
```

When a `strategy` is set, the chart renders `kind: Rollout`
(`argoproj.io/v1alpha1`) instead of a Deployment, plus a `-preview-service`
for smoke-testing the new version. The **Argo Rollouts controller** (installed
in the cluster) owns the rollout; Kong is untouched.

- Verify: `kubectl get rollout -n <ns>` → `kubectl argo rollouts get rollout <name> -n <ns>`
- During a blue‑green update you temporarily run `2× replicas` (active + preview);
  the old set scales down after `scaleDownDelaySeconds`.

---

## Key files map

| Path | Purpose |
|------|---------|
| `argocd/parents/dev-environment.yaml` | Root app: syncs `argocd/dev` into the cluster |
| `argocd/dev/dev-project.yaml` | RBAC project (which namespaces/sources are allowed) |
| `argocd/dev/dev-appset.yaml` | Generates one child app per listed app name |
| `helm/values.yaml` | Base chart defaults (image, probes, route, strategy …) |
| `helm/templates/rollout.yaml` | Blue‑green Rollout (only rendered when `strategy: bluegreen`) |
| `helm/templates/preview-service.yaml` | Preview Service for smoke-testing new pods |
| `helm/templates/hpa.yaml` | Scales the Deployment **or** the Rollout (conditional) |
| `applications/dev/python-demo-for-dashboard-values.yaml` | Worked example of a real app's values |