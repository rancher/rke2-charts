{{- define "system_default_registry" -}}
{{- if .Values.global.systemDefaultRegistry -}}
{{- printf "%s/" .Values.global.systemDefaultRegistry -}}
{{- else -}}
{{- "" -}}
{{- end -}}
{{- end -}}
{{- define "rke2_data_dir" -}}
{{- if .Values.global.rke2DataDir -}}
{{- printf "%s" .Values.global.rke2DataDir -}}
{{- else -}}
{{- "/var/lib/rancher/rke2" -}}
{{- end -}}
{{- end -}}
