{{/*
Expand the name of the chart.
*/}}
{{- define "metabase-backup.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels applied to every resource.
*/}}
{{- define "metabase-backup.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/name: {{ include "metabase-backup.name" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Name of the Secret that holds AWS credentials.
Returns the existingSecret name when provided, otherwise the chart-managed one.
*/}}
{{- define "metabase-backup.secretName" -}}
{{- if .Values.aws.existingSecret }}
{{- .Values.aws.existingSecret }}
{{- else }}
{{- include "metabase-backup.name" . }}-secret
{{- end }}
{{- end }}
