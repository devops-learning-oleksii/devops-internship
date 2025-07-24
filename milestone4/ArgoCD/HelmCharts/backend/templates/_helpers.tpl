{{/* Generate a fullname for resources */}}
{{- define "backend.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/* Generate a name for resources */}}
{{- define "backend.name" -}}
{{- .Chart.Name -}}
{{- end }}