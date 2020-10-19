# Cloud Functions から Cloud Storage を利用する (Python)

## さあ始めましょう

このチュートリアルでは Cloud Storage のファイルを操作する Cloud Functions アプリケーションの構築を学びます。
Cloud Functions の Python ランタイムを使用します。

このガイドでは、以下の内容を説明します。

* gsutil コマンドを使った Cloud Storage に対する操作
* gcloud コマンドを使った Cloud Functions に対する操作
* gcloud コマンドを使ったサービスアカウントの作成と IAM ロールの付与
* [Python Client for Google Cloud Storage](https://googleapis.dev/python/storage/latest/index.html)の使い方


**所要時間**: 約15分

**前提条件**: Google Cloud アカウントとプロジェクト

右下のボタンをクリックしてチュートリアルを開始しましょう！


## チュートリアルの進め方

このチュートリアルではコマンドやコードのスニペットが次のようなコードボックスに表示されます。
このようなコマンドは Cloud Shell のターミナルで実行することができます。
今すぐ次のコマンドを実行してみてください。

```bash
gcloud version
```

**ヒント**: コードボックスの横にあるコピーボタンをクリックして、コマンドを Cloud Shell ターミナルに貼り付けて実行します。

ステップを前後に移動するには、[戻る] と [続行] / [進む] の各ボタンを使用します。


## アプリケーションの概要

このチュートリアルでは Cloud Functions にアプリケーションをデプロイして実行します。

アプリケーションは実行されるたびに、Cloud Storage にあるテキストファイルを読み込み、そこに書かれている数値に1を足して、新しい値で読み込んだファイルを置き換えます。

アプリケーションは HTTP 関数として実行されます。

次のステップに進み、チュートリアルの設定を開始します。


## プロジェクトを設定する

チュートリアルを開始する前に、このチュートリアルで使用するプロジェクトを設定します。
まだプロジェクトを作成していない場合は作成してください。


プロジェクト一覧の確認するために次のコマンドを実行します。

```bash
gcloud projects list
```

利用するプロジェクトを選択して環境変数に設定します。
`YOUR-PROJECT-ID` は実際のプロジェクトIDに置き換えてください。

```bash
export PROJECT_ID="YOUR-PROJECT-ID"
```


## API の有効化

チュートリアルに必要な API を有効化します。

```bash
gcloud services enable \
  --project $PROJECT_ID \
  cloudbuild.googleapis.com \
  cloudfunctions.googleapis.com
```


## Cloud Storage の準備

チュートリアルで使用する Cloud Storage のバケットを作成して、そのバケット内にカウンターファイルをアップロードします。

まず、今後何度も利用するバケット名を環境変数に設定します。

```bash
export BUCKET_NAME="${PROJECT_ID}-functions-tutorial"
```

そのバケット名でバケットを作成します。

```bash
gsutil mb \
  -p $PROJECT_ID \
  -l ASIA-NORTHEAST1 gs://$BUCKET_NAME
```

Cloud Storage にアップロードするためのカウンターファイルを作成します。
初期値は `0` にします。

```bash
echo 0 > counter.txt
```

`gsutil cp` コマンドで作成したカウンターファイルを Cloud Storage にアップロードします。

```bash
gsutil cp \
  counter.txt \
  gs://$BUCKET_NAME/counter.txt
```

## サービスアカウントの作成とロールの付与

Cloud Functions のアプリケーション (関数) で使用するサービスアカウントを作成して、Cloud Storage を操作するためのロールを付与します。

Cloud Functions のアプリケーションで使用するサービスアカウントを作成します。

```bash
gcloud iam service-accounts create \
  functions-storage-python \
  --project $PROJECT_ID
```

このサービスアカウントを環境変数に設定しておきます。

```bash
export SERVICE_ACCOUNT="functions-storage-python@$PROJECT_ID.iam.gserviceaccount.com"
```

このサービスアカウントに `$BUCKET_NAME` バケットに対するロールを付与します。
これにより、このサービスアカウントで `$BUCKET_NAME` バケットのオブジェクトの閲覧や作成、削除ができるようになります。

Storage レガシーオブジェクト読み取りロール (`roles/storage.legacyObjectReader`) でオブジェクトとそのメタデータを閲覧するための権限を付与します。

```bash
gsutil iam ch \
  serviceAccount:${SERVICE_ACCOUNT}:roles/storage.legacyObjectReader \
  gs://$BUCKET_NAME
```

Storage レガシーバケット書き込みロール (`roles/storage.legacyBucketWriter`) でバケット内にオブジェクトを作成、置き換え、削除するための権限を付与します。

```bash
gsutil iam ch \
  serviceAccount:${SERVICE_ACCOUNT}:roles/storage.legacyBucketWriter \
  gs://$BUCKET_NAME
```

**参考**: [Cloud Storage に適用される IAM のロール](https://cloud.google.com/storage/docs/access-control/iam-roles?hl=ja)


## Cloud Functions アプリケーションの確認

Cloud Functions アプリケーションとしてあらかじめ完成されたソースコード (`main.py`) を使用します。
次のコマンドによりエディタで `main.py` を開いてソースコードを確認します。

```bash
cloudshell edit main.py
```

**確認項目**:

* バケット名はどうやって指定していますか？
* ログはどうやって出力していますか？
* Cloud Storage からどうやってデータを取得していますか？
* Cloud Storage にどうやってデータをアップロードしていますか？

ソースコードを理解したら次に進みます。


## Cloud Functions アプリケーションのデプロイ

アプリケーションを Cloud Functions にデプロイします。

デプロイは `gcloud functions deploy` コマンドをラップしたスクリプト (`deploy.sh`) を使用します。
デプロイする前にエディタで `deploy.sh` を開いてコマンドの詳細を確認します。

```bash
cloudshell edit deploy.sh
```

**確認項目**:

* どのプロジェクトにデプロイしていますか？
* どのリージョンにデプロイしていますか？
* ランタイムは何ですか？
* 関数を実行するトリガーは何ですか？
* エントリーポイントは何ですか？
* 関数のサービスアカウントは何ですか？
* どのような環境変数を設定していますか？

コマンドを理解したら `deploy.sh` を実行してアプリケーションをデプロイします。

```bash
bash deploy.sh
```


## Cloud Functions アプリケーションの実行

アプリケーションを実行して Cloud Storage オブジェクトの内容が変化したか確認します。

まず実行前のカウントを確認します。

```bash
gsutil cat gs://$BUCKET_NAME/counter.txt
```

`gcloud functions call` コマンドで簡単にアプリケーションを実行できます。

```bash
gcloud functions call \
  functions-storage-python \
  --project $PROJECT_ID \
  --region asia-northeast1
```

カウントを確認します。
アプリケーションが正しく実行されていれば、先程確認したカウントに 1 足された値が表示されます。

```bash
gsutil cat gs://$BUCKET_NAME/counter.txt
```

次に、Cloud Functions 関数に発行された URL に対して `curl` コマンドでリクエストしてアプリケーションを実行します。

Cloud Functions の URL を次のコマンドで確認します。

```bash
gcloud functions describe \
  functions-storage-python \
  --project $PROJECT_ID \
  --region asia-northeast1 \
  --format='value(httpsTrigger.url)'
```

確認した URL に `curl` でリクエストします。

```bash
curl -i "$(gcloud functions describe functions-storage-python  --project $PROJECT_ID --region asia-northeast1 --format='value(httpsTrigger.url)')"
```

もう一度カウントを確認します。

```bash
gsutil cat gs://$BUCKET_NAME/counter.txt
```

URL をブラウザで開いてもカウントが変化します。
試してみましょう。


## Cloud Functions アプリケーションのログ確認

アプリケーションのログを確認します。
Cloud Functions では stdout または stderr に出力された内容がログとして記録されます。

次のコマンドで Cloud Functions にデプロイされたアプリケーションのログを表示します。

```bash
gcloud functions logs read \
  functions-storage-python \
  --project $PROJECT_ID \
  --region asia-northeast1
```

参考: [ログの作成、表示、処理](https://cloud.google.com/functions/docs/monitoring/logging?hl=ja)


## クリーンアップ

チュートリアルで作成したリソースを削除します。

Cloud Storage のバケットと Cloud Functions の関数とサービスアカウントを削除するために次のコマンドを実行します。

```bash
gsutil rm gs://$BUCKET_NAME/counter.txt
gsutil rb gs://$BUCKET_NAME
gcloud functions delete functions-storage-python \
  --project $PROJECT_ID \
  --region asia-northeast1
gcloud iam service-accounts delete $SERVICE_ACCOUNT \
  --project $PROJECT_ID
```

**ヒント**: 確認プロンプトが表示された場合は `Y` を入力します。


## まとめ

以上でチュートリアルは完了です。
チュートリアルでは次の内容を説明しました。

* gsutil コマンドを使った Cloud Storage に対する操作
* gcloud コマンドを使った Cloud Functions に対する操作
* gcloud コマンドを使ったサービスアカウントの作成と IAM ロールの付与
* [Python Client for Google Cloud Storage](https://googleapis.dev/python/storage/latest/index.html)の使い方
