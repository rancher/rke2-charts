{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "coredns.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "coredns.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "coredns.labels" -}}
app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
app.kubernetes.io/instance: {{ .Release.Name | quote }}
helm.sh/chart: "{{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}"
{{- if .Values.isClusterService }}
k8s-app: {{ template "coredns.k8sapplabel" . }}
kubernetes.io/cluster-service: "true"
kubernetes.io/name: "CoreDNS"
{{- end }}
app.kubernetes.io/name: {{ template "coredns.name" . }}
{{- end -}}

{{/*
Common labels with autoscaler
*/}}
{{- define "coredns.labels.autoscaler" -}}
app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
app.kubernetes.io/instance: {{ .Release.Name | quote }}
helm.sh/chart: "{{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}"
{{- if .Values.isClusterService }}
k8s-app: {{ template "coredns.k8sapplabel" . }}-autoscaler
kubernetes.io/cluster-service: "true"
kubernetes.io/name: "CoreDNS"
{{- end }}
app.kubernetes.io/name: {{ template "coredns.name" . }}-autoscaler
{{- end -}}

{{/*
Allow k8s-app label to be overridden
*/}}
{{- define "coredns.k8sapplabel" -}}
{{- coalesce .Values.k8sApp .Values.k8sAppLabelOverride .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Generate the list of ports automatically from the server definitions
*/}}
{{- define "coredns.servicePorts" -}}
    {{/* Set ports to be an empty dict */}}
    {{- $ports := dict -}}
    {{/* Iterate through each of the server blocks */}}
    {{- range .Values.servers -}}
        {{/* Capture port to avoid scoping awkwardness */}}
        {{- $port := toString .port -}}
        {{- $serviceport := default .port .servicePort -}}

        {{/* If none of the server blocks has mentioned this port yet take note of it */}}
        {{- if not (hasKey $ports $port) -}}
            {{- $ports := set $ports $port (dict "istcp" false "isudp" false "serviceport" $serviceport) -}}
        {{- end -}}
        {{/* Retrieve the inner dict that holds the protocols for a given port */}}
        {{- $innerdict := index $ports $port -}}

        {{/*
        Look at each of the zones and check which protocol they serve
        At the moment the following are supported by CoreDNS:
        UDP: dns://
        TCP: tls://, grpc://, https://
        */}}
        {{- range .zones -}}
            {{- if has (default "" .scheme) (list "dns://" "") -}}
                {{/* Optionally enable tcp for this service as well */}}
                {{- if eq (default false .use_tcp) true }}
                    {{- $innerdict := set $innerdict "istcp" true -}}
                {{- end }}
                {{- $innerdict := set $innerdict "isudp" true -}}
            {{- end -}}

            {{- if has (default "" .scheme) (list "tls://" "grpc://" "https://") -}}
                {{- $innerdict := set $innerdict "istcp" true -}}
            {{- end -}}
        {{- end -}}

        {{/* If none of the zones specify scheme, default to dns:// on both tcp & udp */}}
        {{- if and (not (index $innerdict "istcp")) (not (index $innerdict "isudp")) -}}
            {{- $innerdict := set $innerdict "isudp" true -}}
            {{- $innerdict := set $innerdict "istcp" true -}}
        {{- end -}}

        {{- if .nodePort -}}
            {{- $innerdict := set $innerdict "nodePort" .nodePort -}}
        {{- end -}}

        {{/* Write the dict back into the outer dict */}}
        {{- $ports := set $ports $port $innerdict -}}
    {{- end -}}

    {{/* Write out the ports according to the info collected above */}}
    {{- range $port, $innerdict := $ports -}}
        {{- $portList := list -}}
        {{- if index $innerdict "isudp" -}}
            {{- $portList = append $portList (dict "port" (get $innerdict "serviceport") "protocol" "UDP" "name" (printf "udp-%s" $port) "targetPort" ($port | int)) -}}
        {{- end -}}
        {{- if index $innerdict "istcp" -}}
            {{- $portList = append $portList (dict "port" (get $innerdict "serviceport") "protocol" "TCP" "name" (printf "tcp-%s" $port) "targetPort" ($port | int)) -}}
        {{- end -}}

        {{- range $portDict := $portList -}}
            {{- if index $innerdict "nodePort" -}}
                {{- $portDict := set $portDict "nodePort" (get $innerdict "nodePort" | int) -}}
            {{- end -}}

            {{- printf "- %s\n" (toJson $portDict) -}}
        {{- end -}}
    {{- end -}}
{{- end -}}

{{/*
Generate the list of ports automatically from the server definitions
*/}}
{{- define "coredns.containerPorts" -}}
    {{/* Set ports to be an empty dict */}}
    {{- $ports := dict -}}
    {{/* Iterate through each of the server blocks */}}
    {{- range .Values.servers -}}
        {{/* Capture port to avoid scoping awkwardness */}}
        {{- $port := toString .port -}}

        {{/* If none of the server blocks has mentioned this port yet take note of it */}}
        {{- if not (hasKey $ports $port) -}}
            {{- $ports := set $ports $port (dict "istcp" false "isudp" false) -}}
        {{- end -}}
        {{/* Retrieve the inner dict that holds the protocols for a given port */}}
        {{- $innerdict := index $ports $port -}}

        {{/*
        Look at each of the zones and check which protocol they serve
        At the moment the following are supported by CoreDNS:
        UDP: dns://
        TCP: tls://, grpc://, https://
        */}}
        {{- range .zones -}}
            {{- if has (default "" .scheme) (list "dns://" "") -}}
                {{/* Optionally enable tcp for this service as well */}}
                {{- if eq (default false .use_tcp) true }}
                    {{- $innerdict := set $innerdict "istcp" true -}}
                {{- end }}
                {{- $innerdict := set $innerdict "isudp" true -}}
            {{- end -}}

            {{- if has (default "" .scheme) (list "tls://" "grpc://" "https://") -}}
                {{- $innerdict := set $innerdict "istcp" true -}}
            {{- end -}}
        {{- end -}}

        {{/* If none of the zones specify scheme, default to dns:// on both tcp & udp */}}
        {{- if and (not (index $innerdict "istcp")) (not (index $innerdict "isudp")) -}}
            {{- $innerdict := set $innerdict "isudp" true -}}
            {{- $innerdict := set $innerdict "istcp" true -}}
        {{- end -}}

        {{- if .hostPort -}}
            {{- $innerdict := set $innerdict "hostPort" .hostPort -}}
        {{- end -}}

        {{/* Write the dict back into the outer dict */}}
        {{- $ports := set $ports $port $innerdict -}}

        {{/* Fetch port from the configuration if the prometheus section exists */}}
        {{- range .plugins -}}
            {{- if eq .name "prometheus" -}}
                {{- $prometheus_addr := toString .parameters -}}
                {{- $prometheus_addr_list := regexSplit ":" $prometheus_addr -1 -}}
                {{- $prometheus_port := last $prometheus_addr_list }}
                {{- $ports := set $ports $prometheus_port (dict "istcp" true "isudp" false) -}}
            {{- end -}}
        {{- end -}}
    {{- end -}}

    {{/* Write out the ports according to the info collected above */}}
    {{- range $port, $innerdict := $ports -}}
        {{- $portList := list -}}
        {{- if index $innerdict "isudp" -}}
            {{- $portList = append $portList (dict "containerPort" ($port | int) "protocol" "UDP" "name" (printf "udp-%s" $port)) -}}
        {{- end -}}
        {{- if index $innerdict "istcp" -}}
            {{- $portList = append $portList (dict "containerPort" ($port | int) "protocol" "TCP" "name" (printf "tcp-%s" $port)) -}}
        {{- end -}}

        {{- range $portDict := $portList -}}
            {{- if index $innerdict "hostPort" -}}
                {{- $portDict := set $portDict "hostPort" (get $innerdict "hostPort" | int) -}}
            {{- end -}}

            {{- printf "- %s\n" (toJson $portDict) -}}
        {{- end -}}
    {{- end -}}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "coredns.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{ default (include "coredns.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "coredns.clusterRoleName" -}}
{{- if and .Values.clusterRole .Values.clusterRole.nameOverride -}}
    {{ .Values.clusterRole.nameOverride }}
{{- else -}}
    {{ template "coredns.fullname" . }}
{{- end -}}
{{- end -}}

{{- define "system_default_registry" -}}
{{- if .Values.global.systemDefaultRegistry -}}
{{- printf "%s/" .Values.global.systemDefaultRegistry -}}
{{- else -}}
{{- "" -}}
{{- end -}}
{{- end -}}

{{/*
Set the clusterDNS service IP
*/}}
{{- define "clusterDNSServerIP" -}}
{{- if .Values.service.clusterIP }}
    {{- .Values.service.clusterIP }}
{{ else }}
    {{- $dnsIPs := split "," .Values.global.clusterDNS }}
    {{- $dnsCount := len $dnsIPs }}
    {{- if eq $dnsCount 1 }}
        {{- .Values.global.clusterDNS -}}
    {{- else }}
        {{- if gt $dnsCount 1 }}
            {{- $dnsIPs._0 -}}
        {{ else }}
            {{- "10.43.0.10" }}
        {{- end }}
    {{- end }}
{{- end }}
{{- end }}

{{/*
Pass the clusterDNS service IP for the nodelocal config
*/}}
{{- define "nodelocalUpstreamDNSServerIP" -}}
{{- if .Values.nodelocal.ipvs }}
{{- "" -}}
{{ else }}
{{- (include "clusterDNSServerIP" .) -}}
{{- end }}
{{- end }}

{{/*
Fill the localip flag in the nodelocal CLI
*/}}
{{- define "nodelocalLocalIPFlag" -}}
{{- if .Values.nodelocal.ipvs }}
{{- "" -}}
{{ else }}
{{- printf ",%s" (include "clusterDNSServerIP" .) -}}
{{- end }}
{{- end }}

{{/*
Fill the ipFamily correctly
*/}}
{{- define "ipFamilyPolicy" -}}
{{- if .Values.service.ipFamilyPolicy }}
    {{- .Values.service.ipFamilyPolicy }}
{{ else }}
    {{- $dnsIPs := split "," .Values.global.clusterDNS }}
    {{- $dnsCount := len $dnsIPs }}
    {{- if gt $dnsCount 1 }}
        {{- "PreferDualStack" }}
    {{ else }}
        {{- "SingleStack" }}
    {{- end }}
{{- end }}
{{- end }}

{{/*
nodelocal.corefile — entry point.
If corefile.override is set, emit it verbatim. Otherwise generate from structure.
*/}}
{{- define "nodelocal.corefile" -}}
{{- if .Values.nodelocal.corefile.override }}
{{- .Values.nodelocal.corefile.override }}
{{- else }}
{{- template "nodelocal.corefile.generated" . }}
{{- end }}
{{- end }}

{{/*
nodelocal.corefile.generated — builds the default four-zone Corefile.
*/}}
{{- define "nodelocal.corefile.generated" -}}
{{ coalesce .Values.global.clusterDomain "cluster.local" }}:53{{ range .Values.nodelocal.extraClusterDomains }} {{ . }}:53{{ end }} {
    errors
{{- template "nodelocal.cachePlugin" (dict "zone" "cluster" "root" .) }}
    reload
    loop
{{- template "nodelocal.bindPlugin" . }}
{{- template "nodelocal.forwardPlugin" (dict "zone" "cluster" "root" .) }}
{{- range .Values.nodelocal.corefile.customPlugins.cluster }}
    {{ .name }}{{ with .parameters }} {{ . }}{{ end }}{{ with .configBlock }} {
{{ . | indent 8 }}
    }{{ end }}
{{- end }}
    prometheus :9253
{{- template "nodelocal.healthPlugin" . }}
    }
in-addr.arpa:53 {
    errors
{{- template "nodelocal.cachePlugin" (dict "zone" "reverse" "root" .) }}
    reload
    loop
{{- template "nodelocal.bindPlugin" . }}
{{- template "nodelocal.forwardPlugin" (dict "zone" "reverse" "root" .) }}
{{- range .Values.nodelocal.corefile.customPlugins.reverse }}
    {{ .name }}{{ with .parameters }} {{ . }}{{ end }}{{ with .configBlock }} {
{{ . | indent 8 }}
    }{{ end }}
{{- end }}
    prometheus :9253
    }
ip6.arpa:53 {
    errors
{{- template "nodelocal.cachePlugin" (dict "zone" "ipv6Reverse" "root" .) }}
    reload
    loop
{{- template "nodelocal.bindPlugin" . }}
{{- template "nodelocal.forwardPlugin" (dict "zone" "ipv6Reverse" "root" .) }}
{{- range .Values.nodelocal.corefile.customPlugins.ipv6Reverse }}
    {{ .name }}{{ with .parameters }} {{ . }}{{ end }}{{ with .configBlock }} {
{{ . | indent 8 }}
    }{{ end }}
{{- end }}
    prometheus :9253
    }
.:53 {
    errors
{{- template "nodelocal.cachePlugin" (dict "zone" "catchAll" "root" .) }}
    reload
    loop
{{- template "nodelocal.bindPlugin" . }}
{{- template "nodelocal.forwardPlugin" (dict "zone" "catchAll" "root" .) }}
{{- range .Values.nodelocal.corefile.customPlugins.catchAll }}
    {{ .name }}{{ with .parameters }} {{ . }}{{ end }}{{ with .configBlock }} {
{{ . | indent 8 }}
    }{{ end }}
{{- end }}
    prometheus :9253
    }
{{- end }}

{{/*
nodelocal.cachePlugin — renders cache directive, respecting pluginOverrides.cache.<zone>.
Falls back to defaults: cluster zone gets success/denial block; others get simple TTL.
Uses dig to safely navigate potentially-nil pluginOverrides map.
*/}}
{{- define "nodelocal.cachePlugin" -}}
{{- $zone := .zone }}
{{- $root := .root }}
{{- $overrides := $root.Values.nodelocal.corefile.pluginOverrides | default dict }}
{{- $zoneOverride := dig "cache" $zone dict $overrides }}
{{- if $zoneOverride }}
    cache{{ with $zoneOverride.parameters }} {{ . }}{{ end }}{{ with $zoneOverride.configBlock }} {
{{ . | indent 8 }}
    }{{ end }}
{{- else }}
{{- template "nodelocal.cachePluginDefault" $zone }}
{{- end }}
{{- end }}

{{- define "nodelocal.cachePluginDefault" -}}
{{- if eq . "cluster" }}
    cache {
            success 9984 30
            denial 9984 5
    }
{{- else }}
    cache 30
{{- end }}
{{- end }}

{{/*
nodelocal.bindPlugin — LRP-aware bind directive.
use_cilium_lrp=true → bind 0.0.0.0 (pod network, no host iptables needed)
use_cilium_lrp=false → bind to ip_address + upstream DNS IP for iptables intercept
Not overridable via pluginOverrides — changing bind breaks LRP or iptables modes.
*/}}
{{- define "nodelocal.bindPlugin" -}}
{{- if .Values.nodelocal.use_cilium_lrp }}
    bind 0.0.0.0
{{- else }}
    bind {{ .Values.nodelocal.ip_address }} {{ template "nodelocalUpstreamDNSServerIP" . }}
{{- end }}
{{- end }}

{{/*
nodelocal.healthPlugin — LRP-aware health directive (cluster zone only).
use_cilium_lrp=true → health (no host IP; pod listens on 0.0.0.0)
use_cilium_lrp=false → health <ip>:8080 (bound to link-local address)
*/}}
{{- define "nodelocal.healthPlugin" -}}
{{- if .Values.nodelocal.use_cilium_lrp }}
    health
{{- else }}
    health {{ .Values.nodelocal.ip_address }}:8080
{{- end }}
{{- end }}

{{/*
nodelocal.forwardPlugin — renders forward directive, respecting pluginOverrides.forward.<zone>.
catchAll zone forwards to upstream servers placeholder; others forward to cluster DNS.
*/}}
{{- define "nodelocal.forwardPlugin" -}}
{{- $zone := .zone }}
{{- $root := .root }}
{{- $overrides := $root.Values.nodelocal.corefile.pluginOverrides | default dict }}
{{- $zoneOverride := dig "forward" $zone dict $overrides }}
{{- if $zoneOverride }}
    forward{{ with $zoneOverride.parameters }} {{ . }}{{ end }}{{ with $zoneOverride.configBlock }} {
{{ . | indent 4 }}
    }{{ end }}
{{- else }}
{{- template "nodelocal.forwardPluginDefault" (dict "zone" $zone "root" $root) }}
{{- end }}
{{- end }}

{{- define "nodelocal.forwardPluginDefault" -}}
{{- $zone := .zone }}
{{- $root := .root }}
{{- if eq $zone "catchAll" }}
    forward . __PILLAR__UPSTREAM__SERVERS__
{{- else }}
    forward . {{ ternary (include "clusterDNSServerIP" $root) "__PILLAR__CLUSTER__DNS__" $root.Values.nodelocal.ipvs  }} {
            force_tcp
    }
{{- end }}
{{- end }}
