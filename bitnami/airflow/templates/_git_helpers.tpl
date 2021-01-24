{{/* vim: set filetype=mustache: */}}
{{/*
Returns the name that will identify the repository internally and it will be used to create folders or
volume names
*/}}
{{- define "airflow.git.repository.name" -}}
  {{- $defaultName := regexFind "/.*$" .repository | replace "//" "" | replace "/" "-" | replace "." "-" -}}
  {{- .name | default $defaultName | kebabcase -}}
{{- end -}}

{{/*
Returns the volume mounts that will be used by git containers (clone and sync)
*/}}
{{- define "airflow.git.volumeMounts" -}}
{{- if .Values.git.dags.enabled }}
  {{- range .Values.git.dags.repositories }}
- name: git-cloned-dag-files-{{ include "airflow.git.repository.name" . }}
  mountPath: /dags-{{ include "airflow.git.repository.name" . }}
  {{- end }}
{{- end }}
{{- if .Values.git.plugins.enabled }}
  {{- range .Values.git.plugins.repositories }}
- name: git-cloned-plugins-files-{{ include "airflow.git.repository.name" . }}
  mountPath: /plugins-{{ include "airflow.git.repository.name" . }}
  {{- end }}
{{- end }}
{{- end -}}

{{/*
Returns the volume mounts that will be used by the main container
*/}}
{{- define "airflow.git.maincontainer.volumeMounts" -}}
{{- if .Values.git.dags.enabled }}
  {{- range .Values.git.dags.repositories }}
- name: git-cloned-dag-files-{{ include "airflow.git.repository.name" . }}
  mountPath: /opt/bitnami/airflow/dags/git-{{ include "airflow.git.repository.name" . }}
    {{- if .path }}
  subPath: {{ .path }}
    {{- end }}
  {{- end }}
{{- end }}
{{- if .Values.git.plugins.enabled }}
  {{- range .Values.git.plugins.repositories }}
- name: git-cloned-plugins-files-{{ include "airflow.git.repository.name" . }}
  mountPath: /opt/bitnami/airflow/git-{{ include "airflow.git.repository.name" . }}
    {{- if .path }}
  subPath: {{ .path }}
    {{- end }}
  {{- end }}
{{- end }}
{{- end -}}

{{/*
Returns the volumes that will be attached to the workload resources (deployment, statefulset, etc)
*/}}
{{- define "airflow.git.volumes" -}}
{{- if .Values.git.dags.enabled }}
  {{- range .Values.git.dags.repositories }}
- name: git-cloned-dag-files-{{ include "airflow.git.repository.name" . }}
  emptyDir: {}
  {{- end }}
{{- end }}
{{- if .Values.git.plugins.enabled }}
  {{- range .Values.git.plugins.repositories }}
- name: git-cloned-plugins-files-{{ include "airflow.git.repository.name" . }}
  emptyDir: {}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Returns the init container that will clone repositories files from a given list of git repositories
*/}}
{{- define "airflow.git.containers.clone" -}}
{{- if or .Values.git.dags.enabled .Values.git.plugins.enabled }}
- name: clone-repositories
  image: {{ include "git.image" . | quote }}
  imagePullPolicy: {{ .Values.git.image.pullPolicy | quote }}
{{- if .Values.git.clone.command }}
  command: {{- include "common.tplvalues.render" (dict "value" .Values.git.clone.command "context" $) | nindent 4 }}
{{- else }}
  command:
    - /bin/bash
    - -ec
    - |
    {{- if .Values.git.dags.enabled }}
      {{- range .Values.git.dags.repositories }}
        git clone {{ .repository }} --branch {{ .branch }} /dags-{{ include "airflow.git.repository.name" . }}
      {{- end }}
    {{- end }}
    {{- if .Values.git.plugins.enabled }}
      {{- range .Values.git.plugins.repositories }}
        git clone {{ .repository }} --branch {{ .branch }} /plugins-{{ include "airflow.git.repository.name" . }}
      {{- end }}
    {{- end }}
{{- end }}
{{- if .Values.git.clone.args }}
  args: {{- include "common.tplvalues.render" (dict "value" .Values.git.clone.args "context" $) | nindent 4 }}
{{- end }}
  volumeMounts:
    {{- include "airflow.git.volumeMounts" . | trim | nindent 4 }}
  {{- if .Values.git.clone.extraVolumeMounts }}
    {{- include "common.tplvalues.render" (dict "value" .Values.git.clone.extraVolumeMounts "context" $) | nindent 4 }}
  {{- end }}
{{- if .Values.git.clone.extraEnvVars }}
  env: {{- include "common.tplvalues.render" (dict "value" .Values.git.clone.extraEnvVars "context" $) | nindent 4 }}
{{- end }}
{{- if or .Values.git.clone.extraEnvVarsCM .Values.git.clone.extraEnvVarsSecret }}
  envFrom:
    {{- if .Values.git.clone.extraEnvVarsCM }}
    - configMapRef:
        name: {{ .Values.git.clone.extraEnvVarsCM }}
    {{- end }}
    {{- if .Values.git.clone.extraEnvVarsSecret }}
    - secretRef:
        name: {{ .Values.git.clone.extraEnvVarsSecret }}
    {{- end }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
Returns the a container that will pull and sync repositories files from a given list of git repositories
*/}}
{{- define "airflow.git.containers.sync" -}}
{{- if or .Values.git.dags.enabled .Values.git.plugins.enabled }}
- name: sync-repositories
  image: {{ include "git.image" . | quote }}
  imagePullPolicy: {{ .Values.git.image.pullPolicy | quote }}
{{- if .Values.git.sync.command }}
  command: {{- include "common.tplvalues.render" (dict "value" .Values.git.sync.command "context" $) | nindent 4 }}
{{- else }}
  command:
    - /bin/bash
    - -ec
    - |
      while true; do
      {{- if .Values.git.dags.enabled }}
        {{- range .Values.git.dags.repositories }}
          cd /dags-{{ include "airflow.git.repository.name" . }} && git pull origin {{ .branch }}
        {{- end }}
      {{- end }}
      {{- if .Values.git.plugins.enabled }}
        {{- range .Values.git.plugins.repositories }}
          cd /plugins-{{ include "airflow.git.repository.name" . }} && git pull origin {{ .branch }}
        {{- end }}
      {{- end }}
          sleep {{ default "60" .Values.git.sync.interval }}
      done
{{- end }}
{{- if .Values.git.sync.args }}
  args: {{- include "common.tplvalues.render" (dict "value" .Values.git.sync.args "context" $) | nindent 4 }}
{{- end }}
  volumeMounts:
    {{- include "airflow.git.volumeMounts" . | trim | nindent 4 }}
  {{- if .Values.git.sync.extraVolumeMounts }}
    {{- include "common.tplvalues.render" (dict "value" .Values.git.sync.extraVolumeMounts "context" $) | nindent 4 }}
  {{- end }}
{{- if .Values.git.sync.extraEnvVars }}
  env: {{- include "common.tplvalues.render" (dict "value" .Values.git.sync.extraEnvVars "context" $) | nindent 4 }}
{{- end }}
{{- if or .Values.git.sync.extraEnvVarsCM .Values.git.sync.extraEnvVarsSecret }}
  envFrom:
    {{- if .Values.git.sync.extraEnvVarsCM }}
    - configMapRef:
        name: {{ .Values.git.sync.extraEnvVarsCM }}
    {{- end }}
    {{- if .Values.git.sync.extraEnvVarsSecret }}
    - secretRef:
        name: {{ .Values.git.sync.extraEnvVarsSecret }}
    {{- end }}
{{- end }}
{{- end }}
{{- end -}}
