---
id: quick-start-config-sync
status: [draft]
summary: はじめての Config Sync
author: nownabe
categories: Cloud,Anthos
tags: cloud,anthos,acm,anthos-config-management,config-sync,kubernetes
analytics account: UA-191798031-4
feedback link: https://github.com/ShawnLabo/google-cloud-tutorials/issues

---

# はじめての Config Sync

## はじめに
Duration: 5

> aside negative
> このラボは非公式であり、Google Cloud の公式のチュートリアルではありません。

### 前提条件

* Google Cloud アカウント
* 有効な Billing Account と紐付いている Google Cloud プロジェクト
  * クリーンアップしやすいようにこのラボ用の新規プロジェクトの利用をおすすめします
* 有効な Billing Account と紐付いている Google Cloud プロジェクト
* [Cloud SDK](https://cloud.google.com/sdk) (gcloud)

### Cloud SDK コンポーネントのインストール

> aside positive
> Cloud Shell の場合は必要ありません。

必要な gcloud コンポーネントをインストールしてください。

```console
gcloud components install kubectl alpha
```

## このラボについて
Duration: 1

このラボでは [Config Sync](https://cloud.google.com/kubernetes-engine/docs/add-on/config-sync/config-sync-overview) について学びます。

Config Sync は [Anthos Config Management](https://cloud.google.com/anthos/config-management) のコンポーネントのひとつであり、GitOps の機能を Kubernetes に提供します。
Config Sync を使うと、Git リポジトリの変更を検知してリポジトリにある最新の Kubernetes のマニフェストを自動で Kubernetes クラスタに反映できます。

このラボでは Config Sync を使って GitHub のサンプルリポジトリにある Kubernetes のマニフェストを GKE クラスタに自動反映するための設定をします。

## 準備
Duration: 3

### プロジェクトの設定

使用するプロジェクトを設定してください。

```console
gcloud config set project YOUR-PROJECT
```

### API の有効化

利用するサービスの API を有効化します。

```console
gcloud services enable \
  anthos.googleapis.com \
  container.googleapis.com
```

### Anthos Config Management の有効化

Anthos Config Management を有効化します。

```console
gcloud alpha container hub config-management enable
```


## GKE クラスタの準備
Duration: 10

Config Sync を適用する GKE クラスタを作成します。

```console
gcloud container clusters create acm-cluster \
  --zone asia-northeast1-a \
  --machine-type e2-standard-4 \
  --workload-pool $(gcloud config get-value project).svc.id.goog
```

操作しているユーザーに [`cluster-admin`](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#user-facing-roles) のロールを付与してクラスタを管理できるように [ClusterRoleBinding](https://kubernetes.io/docs/reference/access-authn-authz/rbac/) を作成します。

```console
kubectl create clusterrolebinding cluster-admin-binding \
  --clusterrole cluster-admin \
  --user $(gcloud config get-value account)
```

> aside positive
> Google Kubernetes Engine における RBAC については[こちらのドキュメント](https://cloud.google.com/kubernetes-engine/docs/how-to/role-based-access-control)を参照してください。

作成した GKE クラスタを Anthos に登録します。

```console
gcloud beta container hub memberships register acm-cluster \
  --gke-cluster asia-northeast1-a/acm-cluster \
  --enable-workload-identity
```


## Cofig Sync の設定
duration: 5

gcloud コマンドを使って作成したクラスタに Config Sync を設定します。

```console
cat <<EOF > config-management.yaml
apiVersion: configmanagement.gke.io/v1
kind: ConfigManagement
metadata:
  name: config-management
  namespace: config-management-system
spec:
  sourceFormat: unstructured
  git:
    syncRepo: https://github.com/GoogleCloudPlatform/anthos-config-management-samples
    syncBranch: init
    secretType: none
    policyDir: quickstart/multirepo/root
EOF
gcloud alpha container hub config-management apply \
  --membership acm-cluster \
  --config config-management.yaml
```

重要な項目についてそれぞれ次のような意味があります。

* `spec.git.syncRepo` - 同期する Git リポジトリ
* `spec.git.syncBranch` - 同期する Git ブランチ
* `spec.git.secretType` - Git リポジトリにアクセスするための認証方法
  * このラボではパブリック リポジトリが対象なので `none`
* `spec.git.policyDir` - 同期するマニフェストが格納されているディレクトリ

このラボの設定では [https://github.com/GoogleCloudPlatform/anthos-config-management-sample](https://github.com/GoogleCloudPlatform/anthos-config-management-sample) リポジトリの `init` ブランチの `quickstart/multirepo/root` ディレクトリの構成をクラスタに同期します。

> aside positive
> 設定の詳細は[ドキュメント](https://cloud.google.com/anthos-config-management/docs/how-to/installing-config-sync#configuring-config-sync)を参照してください。

実際に [GitHub](https://github.com/GoogleCloudPlatform/anthos-config-management-samples/tree/init/quickstart/multirepo/root) へアクセスして、どのようなマニフェストがあるか確認してみましょう。
例えば、[namespace-gamestore.yaml](https://github.com/GoogleCloudPlatform/anthos-config-management-samples/blob/init/quickstart/multirepo/root/namespace-gamestore.yaml)というファイルでは `gamestore` という Namespace が定義されています。

## 同期の確認
duration: 10

Config Sync によって GitHub 上のマニフェストがクラスタに反映されているか確認します。

まず、Config Sync のステータスを確認します。

```console
gcloud alpha container hub config-management status
```

Status の列に `SYNCED` と表示されていれば同期が完了しています。

> aside negative
> 正常に処理できていても同期の初期段階でエラーが表示されることがあります。
> 同期が完了するとエラー表示は消えるので、しばらく待ってもう一度確認してください。

次に、実際にクラスタに反映されているかどうかを確認します。
`gamestore` という Namespace が存在していることを `kubectl` コマンドで確認します。

```console
kubectl get ns
```

次のように `gamestore` Namespace が表示されたら反映が成功しています。

```console
$ kubectl get ns
NAME                           STATUS   AGE
config-management-monitoring   Active   5d2h
config-management-system       Active   5d2h
default                        Active   5d2h
gamestore                      Active   5d2h
gke-connect                    Active   5d2h
kube-node-lease                Active   5d2h
kube-public                    Active   5d2h
kube-system                    Active   5d2h
monitoring                     Active   5d2h
resource-group-system          Active   5d2h
```

Config Sync で同期されたリソースには専用のラベルが付与されます。
ラベルによる絞り込みで Config Sync に管理されているオブジェクトのみを表示できます。

```console
$ kubectl get clusterroles -l app.kubernetes.io/managed-by=configmanagement.gke.io
NAME                  CREATED AT
namespace-reader      2021-06-02T04:36:23Z
prometheus-acm        2021-06-02T04:36:32Z
prometheus-operator   2021-06-02T04:36:23Z
webstore-admin        2021-06-02T04:36:33Z
```

## 管理オブジェクトの変更
duration: 1

Config Sync により管理されているオブジェクトは手動で変更できないようになっています。
試しに、`gamestore` Namespace を削除してみます。

```console
kubectl delete namespace gamestore
```

以下のようにエラーが表示されます。

```console
$ kubectl delete namespace gamestore
error: You must be logged in to the server (admission webhook "v1.admission-webhook.configsync.gke.io" denied the request: requester is not authorized to delete managed resources)
```

`kubectl` コマンドで `gamestore` Namespace が削除されていないことを確認できます。

```console
$ kubectl get ns gamestore
NAME        STATUS   AGE
gamestore   Active   5d2h
```

## おわりに
duration: 3

以上でこのラボは終了です。

クリーンアップする場合はプロジェクトごと削除するか、次のコマンドを実行してください。

```console
gcloud container clusters delete acm-cluster --zone asia-northeast1-a
gcloud beta container hub memberships delete acm-cluster
```
