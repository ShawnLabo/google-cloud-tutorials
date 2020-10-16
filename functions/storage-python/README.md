# Cloud Functions から Cloud Storage を利用する (Python)

## チュートリアルの概要

このチュートリアルは Cloud Functions にデプロイしたアプリケーションで Cloud Storage のファイルを操作することが目標です。
Cloud Functions の Python ランタイムを利用します。

以下を順に行います。

* Cloud Storage の準備
* サービスアカウントの作成とロールの付与
* Cloud Functions アプリケーションの確認
* Cloud Functions アプリケーションのデプロイ
* Cloud Functions アプリケーションの実行
* Cloud Functions アプリケーションのログ確認


## アプリケーションの概要

このチュートリアルでは Cloud Functions にアプリケーションをデプロイして実行します。

アプリケーションは実行されるたびに、Cloud Storage にあるテキストファイルを読み込み、そこに書かれている数値に1を足して、新しい値で読み込んだファイルを置き換えます。

アプリケーションは HTTP 関数として実行されます。


## プロジェクトを設定する

チュートリアルを開始する前に、このチュートリアルで使用するプロジェクトを設定してください。

プロジェクト一覧の確認:

```
gcloud projects list
```

利用するプロジェクトを環境変数に設定 (`YOUR-PROJECT-ID` は実際のプロジェクトIDに置き換えてください):

```
export PROJECT_ID="YOUR-PROJECT-ID"
```


## API の有効化

チュートリアルに必要な API を有効化します。

```
gcloud services enable \
  --project $PROJECT_ID \
  cloudbuild.googleapis.com
```


## Cloud Storage の準備

チュートリアルで使用する Cloud Storage のバケットを作成して、そのバケット内にカウンターファイルをアップロードします。

まず、バケットの名前を環境変数に設定してください。

```
export BUCKET_NAME="${PROJECT_ID}-functions-tutorial"
```

そのバケット名でバケットを作成します。

```
gsutil mb -p $PROJECT_ID -l ASIA-NORTHEAST1 gs://$BUCKET_NAME
```

カウンターファイルを作成し、バケットにアップロードします。

```
echo 0 > counter.txt
gsutil cp counter.txt gs://$BUCKET_NAME/counter.txt
```

## サービスアカウントの作成とロールの付与

Cloud Functions で使用するサービスアカウントを作成して、Cloud Storage を操作するためのロールを付与します。

まず、サービスアカウントを作成します。

```
gcloud iam service-accounts create functions-storage-python --project $PROJECT_ID
```

このサービスアカウントを環境変数に設定しておきます。

```
export SERVICE_ACCOUNT="functions-storage-python@$PROJECT_ID.iam.gserviceaccount.com"
```

このサービスアカウントに `$BUCKET_NAME` バケットに対するオブジェクト管理者ロールを付与します。
これにより、このサービスアカウントで `$BUCKET_NAME` バケットのオブジェクトの閲覧や作成、削除ができるようになります。

```
gsutil iam ch \
  serviceAccount:${SERVICE_ACCOUNT}:roles/storage.legacyObjectReader \
  gs://$BUCKET_NAME
gsutil iam ch \
  serviceAccount:${SERVICE_ACCOUNT}:roles/storage.legacyBucketWriter \
  gs://$BUCKET_NAME
```

参考: [Cloud Storage に適用される IAM のロール](https://cloud.google.com/storage/docs/access-control/iam-roles?hl=ja)

## Cloud Functions アプリケーションの確認

このチュートリアルでは予め完成されたソースコード (`main.py`) を使用します。
次のコマンドによりエディタで `main.py` を開き、ソースコードを確認してください。

```
cloudshell edit main.py
```


## Cloud Functions アプリケーションのデプロイ

アプリケーションを Cloud Functions にデプロイします。

デプロイは `gcloud functions deploy` コマンドをラップしたデプロイスクリプト (`deploy.sh`) を使用します。
エディタで `deploy.sh` を開き、コマンドを確認してください。

```
cloudshell edit deploy.sh
```

コマンドを理解したら、`deploy.sh` を実行してデプロイしてください。

```
bash deploy.sh
```


## Cloud Functions アプリケーションの実行

アプリケーションを実行して、Cloud Storage オブジェクトの内容を確認します。

まず、実行前のカウントを確認します。

```
gsutil cat gs://$BUCKET_NAME/counter.txt
```

アプリケーションを実行します。
gcloudコマンドを使うことで簡単に実行することができます。

```
gcloud functions call functions-storage-python \
  --project $PROJECT_ID \
  --region asia-northeast1
```

再度、カウントを確認します。
アプリケーションが正しく実行されていれば、先程確認したカウントに 1 足された値が表示されます。

```
gsutil cat gs://$BUCKET_NAME/counter.txt
```

また、`curl` コマンドを使って Cloud Functions で発行された URL に対してリクエストを送り、アプリケーションを実行してみます。

Cloud Functions の URL は次のコマンドで確認できます。

```
gcloud functions describe functions-storage-python \
  --project $PROJECT_ID \
  --region asia-northeast1 \
  --format='value(httpsTrigger.url)'
```

URL に `curl` でリクエストします。

```
curl -i "$(gcloud functions describe functions-storage-python  --project $PROJECT_ID --region asia-northeast1 --format='value(httpsTrigger.url)')"
```

もう一度カウントを確認してみましょう。

```
gsutil cat gs://$BUCKET_NAME/counter.txt
```


## Cloud Functions アプリケーションのログ確認

アプリケーションのログを確認します。
Cloud Functions では stdout または stderr に出力された内容がログとして記録されます。

次のコマンドで Cloud Functions にデプロイされたアプリケーションのログを表示できます。

```
gcloud functions logs read functions-storage-python \
  --project $PROJECT_ID \
  --region asia-northeast1
```

参考: [ログの作成、表示、処理](https://cloud.google.com/functions/docs/monitoring/logging?hl=ja)

## クリーンアップ

チュートリアルで作成したリソースを削除します。
プロジェクトを削除する場合はここの手順は不要です。
このパートはスキップしてプロジェクトを削除してください。

プロジェクトを残す場合は次の手順を実行して Cloud Storage のバケットと Cloud Functions の関数とサービスアカウントを削除します。


```
gsutil rm gs://$BUCKET_NAME/counter.txt
gsutil rb gs://$BUCKET_NAME
gcloud functions delete functions-storage-python \
  --project $PROJECT_ID \
  --region asia-northeast1
gcloud iam service-accounts delete $SERVICE_ACCOUNT \
  --project $PROJECT_ID
```

## まとめ

以上でチュートリアルは完了です。

