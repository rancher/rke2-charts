{{- define "system_default_registry" -}}
{{- if .Values.global.systemDefaultRegistry -}}
{{- printf "%s/" .Values.global.systemDefaultRegistry -}}
{{- else -}}
{{- "" -}}
{{- end -}}
{{- end -}}

{{- define "enableIPv6?" -}}
{{- $cidrv6 := coalesce .Values.global.clusterCIDRv6 .Values.podCidrv6 -}}
{{- ternary "false" "true" (empty .Values.global.clusterCIDRv6) -}}
{{- end -}}

