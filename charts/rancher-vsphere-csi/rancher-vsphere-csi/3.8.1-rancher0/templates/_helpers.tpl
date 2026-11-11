{{- define "system_default_registry" -}}
{{- if .Values.global.cattle.systemDefaultRegistry -}}
{{- printf "%s/" .Values.global.cattle.systemDefaultRegistry -}}
{{- else -}}
{{- "" -}}
{{- end -}}
{{- end -}}

{{/*
Render "repository:tag" for an image, selecting the hardened Prime image when
global.prime.enabled is true and a primeRepository is set. If primeTag is set,
it is used as the image tag in Prime mode as well. Pass the image dict
merged with the prime config, e.g.:
  {{ include "vsphere.image" (merge (dict "prime" .Values.global.prime) .Values.csiController.image) }}
*/}}
{{- define "vsphere.image" -}}
{{- $repo := .repository -}}
{{- $tag := .tag -}}
{{- if and .prime .prime.enabled .primeRepository -}}
{{- $repo = .primeRepository -}}
{{- if .primeTag -}}
{{- $tag = .primeTag -}}
{{- end -}}
{{- end -}}
{{- printf "%s:%s" $repo $tag -}}
{{- end -}}

{{- define "applyVersionOverrides" -}}
{{- $overrides := dict -}}
{{- range $override := .Values.versionOverrides -}}
{{- if semverCompare $override.constraint $.Capabilities.KubeVersion.Version -}}
{{- $_ := mergeOverwrite $overrides $override.values -}}
{{- end -}}
{{- end -}}
{{- $_ := mergeOverwrite .Values $overrides -}}
{{- end -}}

{{/*
Windows cluster will add default taint for linux nodes,
add below linux tolerations to workloads could be scheduled to those linux nodes
*/}}
{{- define "linux-node-tolerations" -}}
- key: "cattle.io/os"
  value: "linux"
  effect: "NoSchedule"
  operator: "Equal"
{{- end -}}

{{- define "linux-node-selector" -}}
kubernetes.io/os: linux
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "chartName" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Labels that should be added on each resource
*/}}
{{- define "labels" -}}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ include "chartName" . }}
{{- end -}}
