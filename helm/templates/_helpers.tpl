# DVO-L4-3C8B52
{{/*
Expand the name of the chart.
*/}}
{{- define "devops-task-manager.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "devops-task-manager.fullname" -}}
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
{{- define "devops-task-manager.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels with mandatory mascot: гарбуз
*/}}
{{- define "devops-task-manager.labels" -}}
helm.sh/chart: {{ include "devops-task-manager.chart" . }}
{{ include "devops-task-manager.selectorLabels" . }}
app.kubernetes.io/version: {{ .Values.backend.image.tag | default .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
mascot: {{ .Values.mascot | default "гарбуз" | quote }}
{{- end }}

{{/*
Common annotations with mandatory devops-lab/mascot-approved
*/}}
{{- define "devops-task-manager.annotations" -}}
devops-lab/mascot-approved: "true"
{{- end }}

{{/*
Selector labels
*/}}
{{- define "devops-task-manager.selectorLabels" -}}
app.kubernetes.io/name: {{ include "devops-task-manager.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
