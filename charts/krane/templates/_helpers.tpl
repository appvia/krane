{{/*
Expand the name of the chart.
*/}}
{{- define "krane.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "krane.fullname" -}}
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
{{- define "krane.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "krane.labels" -}}
helm.sh/chart: {{ include "krane.chart" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "krane.selectorLabels" -}}
app.kubernetes.io/name: {{ include "krane.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: {{ include "krane.name" . }}
app.kubernetes.io/part-of: {{ include "krane.name" . }}
network/krane: "true"
{{- end }}

{{/*
RedisGraph Selector labels
*/}}
{{- define "krane.redisgraphSelectorLabels" -}}
app.kubernetes.io/name: redisgraph
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: redisgraph
app.kubernetes.io/part-of: {{ include "krane.name" . }}
network/krane: "true"
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "krane.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "krane.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Config labels
*/}}
{{- define "krane.configLabels" -}}
app.kubernetes.io/name: {{ include "krane.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: {{ include "krane.name" . }}
app.kubernetes.io/part-of: {{ include "krane.name" . }}
network/krane: "true"
{{- end }}
