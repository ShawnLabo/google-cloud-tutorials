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

# Anthos Config Management with GitLab

## はじめに

注意: 本チュートリアルは非公式です。

複数の GKE クラスタを Anthos Config Management によりGitLabのリポジトリで管理するチュートリアルです。

### 前提条件

* Google Cloud アカウント
* 有効な Billing Account と紐付いている Google Cloud プロジェクト
  * プロジェクトごとクリーンアップできるように、本チュートリアル用の新規プロジェクトを用意することをおすすめします
* 有効な Billing Account と紐付いている Google Cloud プロジェクト
* Cloud SDK (gcloud)

### 準備

必要な gcloud コンポーネントをインストールしてください。

```console
gcloud components install kubectl alpha
```

使用するプロジェクトを設定してください。

```console
gcloud config set project YOUR-PROJECT
```

## 本チュートリアルの構成

本チュートリアルでは2つの GKE クラスタを1つの GitLab リポジトリで管理します。
また、チュートリアル用に GitLab を構築します。

## GitLab の構築

スクリプトを使って GitLab を構築します。

```console
curl -sL https://raw.githubusercontent.com/ShawnLabo/google-cloud-tutorials/main/anthos/config-management-with-gitlab/deploy_gitlab.sh | bash -
```

[Ingress 一覧](https://console.cloud.google.com/kubernetes/ingresses)から、**gitlab-webservice** Ingressをクリックしてください。
バックエンドサービスのヘルスチェックが上手く成功しない場合は以下の手順でヘルスチェックを修正してください。

* [ヘルスチェック一覧](https://console.cloud.google.com/compute/healthChecks)にアクセスする
* パスが `/-/readiness` になっていないヘルスチェックがあればパスを `/-/readiness` に修正する

ヘルスチェックやSSL証明書の作成が成功すれば GitLab にアクセスできるようになります。
スクリプトの最後に表示された URL にアクセスし、 ユーザー名 `root` と表示されたパスワードでログインしてください。

## GKE クラスタの作成

ACMで管理する2つのクラスタを作成します。

### クラスタ1 (asia-northeast1)

1つ目のクラスタを asia-northeast1 (Tokyo) に作成します。

```console
gcloud container clusters create acm-cluster-1 \
  --region asia-northeast1 \
  --workload-pool $(gcloud config get-value project).svc.id.goog
```

操作しているユーザーに`cluster-admin`のロールを付与してクラスタを管理できるようにClusterRoleBindingを作成します。

```console
gcloud container clusters get-credentials acm-cluster-1 --region asia-northeast1
kubectl create clusterrolebinding cluster-admin-binding \
  --clusterrole cluster-admin \
  --user $(gcloud config get-value account)
```

### クラスタ2 (us-centarl1)

2つ目のクラスタを us-central1 (Iowa) に作成します。
1つ目のクラスタと同様にClusterRoleBindingも作成します。

```console
gcloud container clusters create acm-cluster-2 \
  --region us-central1 \
  --workload-pool $(gcloud config get-value project).svc.id.goog
gcloud container clusters get-credentials acm-cluster-2 --region us-central1
kubectl create clusterrolebinding cluster-admin-binding \
  --clusterrole cluster-admin \
  --user $(gcloud config get-value account)
```

## GKE クラスタ を Anthos に登録

各 GKE クラスタを Anthos に登録します。

登録する前に Anthos と Anthos Config Management を有効化します。

```console
gcloud services enable anthos.googleapis.com
gcloud alpha container hub config-management enable
```

1つ目のクラスタを登録します。

```console
gcloud beta container hub memberships register acm-cluster-1 \
  --gke-cluster asia-northeast1/acm-cluster-1 \
  --enable-workload-identity
```

同様に2つ目のクラスタを登録します。

```console
gcloud beta container hub memberships register acm-cluster-2 \
  --gke-cluster us-central1/acm-cluster-2 \
  --enable-workload-identity
```
