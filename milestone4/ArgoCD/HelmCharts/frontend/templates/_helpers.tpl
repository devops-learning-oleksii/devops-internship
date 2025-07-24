{{/* Generate a fullname for resources */}}
{{- define "frontend.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/* Generate a name for resources */}}
{{- define "frontend.name" -}}
{{- .Chart.Name -}}
{{- end }}
