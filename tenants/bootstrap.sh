#!/usr/bin/env bash
# Bootstrap all tenants — the ONLY manual kubectl step.
# One root per tenant (tenants/<tenant>/<tenant>.yaml) syncs its dev/uat/prod
# Projects + ApplicationSets. Child Applications come ONLY from ApplicationSets.
set -euo pipefail
cd "$(dirname "$0")/.."
find tenants -mindepth 2 -maxdepth 2 -name "*.yaml" | sort | while read -r f; do
  echo "==> applying $f"
  kubectl apply -f "$f"
done
echo "---"
echo "verify: kubectl get applications -n argocd && kubectl get applicationsets -n argocd"
