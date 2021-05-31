---
id: doc
{{if .Meta.Status}}status: {{.Meta.Status}}{{end}}
{{if .Meta.Summary}}summary: {{.Meta.Summary}}{{end}}
{{if .Meta.Author}}author: {{.Meta.Author}}{{end}}
{{if .Meta.Categories}}categories: {{commaSep .Meta.Categories}}{{end}}
{{if .Meta.Tags}}tags: {{commaSep .Meta.Tags}}{{end}}
{{if .Meta.Feedback}}feedback link: {{.Meta.Feedback}}{{end}}
{{if .Meta.GA}}analytics account: {{.Meta.GA}}{{end}}

---

# Anthos Config Management Tutorial

## 準備

gcloudの準備

```bash
gcloud components install kubectl alpha
```

GKE APIの有効化

```bash
gcloud services enable container.googleapis.com
```

Anthos Config Managementの有効化

```bash
gcloud alpha container hub config-management enable
```

## GitLabのデプロイ

```bash
gcloud container clusters create gitlab --region asia-northeast1
gcloud container clusters get-credentials gitlab --region asia-northeast1

```

## Not yet

```bash
cluster=acm-cluster-1
gcloud container clusters create $cluster --region asia-northeast1
gcloud container clusters get-credentials $cluster --region asia-northeast1
kubectl create clusterrolebinding cluster-admin-binding \
  --clusterrole cluster-admin \
  --user $(gcloud config get-value account)
```
