# ============================================================================
# Generic chart helpers — naming + labels used by every template below.
# Keeps all objects consistent so ArgoCD diffs stay clean and Kong can
# reach each app by a predictable Service name (`<app>-service`).
# ============================================================================

{{/*
Base name for deployment/service/sa/hpa/ingress.
Defaults to the RELEASE name (which ArgoCD sets = the Application name,
e.g. `python-app-prod`). Use fullnameOverride only to rename an app.
*/}}
{{- define "generic.fullname" -}}
{{- default .Release.Name .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Selector labels — the app instance that Deployments select and Services target.
*/}}
{{- define "generic.selectorLabels" -}}
app.kubernetes.io/name: {{ include "generic.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Full label set — selector labels + ownership bookkeeping.
*/}}
{{- define "generic.labels" -}}
{{ include "generic.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
ServiceAccount name to use, honoring create vs. reuse.
*/}}
{{- define "generic.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "generic.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}