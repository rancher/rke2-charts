{{/*
Expand the name of the chart.
*/}}
{{- define "rke2-security-responder.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "rke2-security-responder.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "rke2-security-responder.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "rke2-security-responder.labels" -}}
helm.sh/chart: {{ include "rke2-security-responder.chart" . }}
{{ include "rke2-security-responder.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "rke2-security-responder.selectorLabels" -}}
app.kubernetes.io/name: {{ include "rke2-security-responder.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "rke2-security-responder.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "rke2-security-responder.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Return the proper image name with registry
*/}}
{{- define "rke2-security-responder.image" -}}
{{- if .Values.global.systemDefaultRegistry -}}
{{- printf "%s/%s:%s" .Values.global.systemDefaultRegistry .Values.image.repository .Values.image.tag -}}
{{- else -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}
{{- end }}

{{/*
Return the CronJob schedule. Without an explicit schedule, the minute and the
first hour derive from the kube-system namespace UID, so that clusters do not
all report at the same time. Each cluster still reports once per 8-hour
bucket, and before minute 55, so that a slow run stays in its bucket.
*/}}
{{- define "rke2-security-responder.schedule" -}}
{{- $uid := dig "metadata" "uid" "" (lookup "v1" "Namespace" "" "kube-system") -}}
{{- $seed := regexReplaceAll "[^0-9]" $uid "" | trunc 9 | atoi -}}
{{- .Values.schedule | default (printf "%d %d-23/8 * * *" (mod $seed 55) (mod (div $seed 55) 8)) -}}
{{- end }}
