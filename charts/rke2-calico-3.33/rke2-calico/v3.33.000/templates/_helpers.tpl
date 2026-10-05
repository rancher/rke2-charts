{{/* generate the image name for a component*/}}
{{- define "installation.imagePrefix" -}}
{{- $values := .Values | toYaml | fromYaml -}}
{{- if dig "global" "prime" "enabled" false $values -}}
{{- "hardened-calico-" -}}
{{- else -}}
{{- .Values.installation.imagePrefix -}}
{{- end -}}
{{- end -}}

{{- define "tigera-operator.operatorImage" -}}
{{- $values := .Values | toYaml | fromYaml -}}
{{- if dig "global" "prime" "enabled" false $values -}}
{{- "rancher/hardened-calico-operator" -}}
{{- else -}}
{{- .Values.tigeraOperator.image -}}
{{- end -}}
{{- end -}}

{{- define "tigera-operator.image" -}}
{{- if .Values.global.systemDefaultRegistry -}}
{{- $_ := set .Values.tigeraOperator "registry" .Values.global.systemDefaultRegistry -}}
{{- end -}}
{{- if .Values.tigeraOperator.registry -}}
    {{- .Values.tigeraOperator.registry | trimSuffix "/" -}}/
{{- end -}}
{{- include "tigera-operator.operatorImage" . -}}:{{- .Values.tigeraOperator.version -}}
{{- end -}}

{{/*
generate imagePullSecrets for installation and deployments
by combining installation.imagePullSecrets with toplevel imagePullSecrets.
*/}}

{{- define "tigera-operator.imagePullSecrets" -}}
{{- $secrets := default list .Values.installation.imagePullSecrets -}}
{{- range $key, $val := .Values.imagePullSecrets -}}
  {{- $secrets = append $secrets (dict "name" $key) -}}
{{- end -}}
{{ $secrets | toYaml }}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "tigera-operator.labels" -}}
k8s-app: tigera-operator
{{- with .context.Values.additionalLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}