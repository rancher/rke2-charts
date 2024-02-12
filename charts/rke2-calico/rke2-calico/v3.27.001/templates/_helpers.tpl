{{/* generate the image name for a component*/}}
{{- define "tigera-operator.image" -}}
{{- if .Values.global.systemDefaultRegistry -}}
{{- $_ := set .Values.tigeraOperator "registry" .Values.global.systemDefaultRegistry -}}
{{- end -}}
{{- if .Values.tigeraOperator.registry -}}
    {{- .Values.tigeraOperator.registry | trimSuffix "/" -}}/
{{- end -}}
{{- .Values.tigeraOperator.image -}}:{{- .Values.tigeraOperator.version -}}
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
