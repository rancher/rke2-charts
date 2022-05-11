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
