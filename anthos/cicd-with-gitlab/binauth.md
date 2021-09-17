### 環境変数の設定

次の環境変数を設定してください。
このセクションで共通して利用します。

```console
project_id=$(gcloud config get-value project)
project_number=$(gcloud projects describe $project_id --format='value(projectNumber)')
build_sa_email="${project_number}@cloudbuild.gserviceaccount.com"
```

### 共通の準備

クラスタのBinary Authorizationを有効化してください。

```console
gcloud container clusters update dev --enable-binauthz --zone asia-northeast1-c
gcloud container clusters update prod --enable-binauthz --zone asia-northeast1-c
```

Cloud Buildのサービスアカウントに[Kubernetes Engine デベロッパー](https://cloud.google.com/kubernetes-engine/docs/how-to/iam#predefined)のロールを付与してください。

```console
gcloud projects add-iam-policy-binding \
  $(gcloud config get-value project) \
  --member serviceAccount:${cloud_build_sa_email} \
  --role roles/container.developer
```

脆弱性スキャンとQAテストでの署名に利用する鍵ペアを管理する [Google Cloud Key Management Service (KMS)](https://cloud.google.com/kms) の [keyring](https://cloud.google.com/kms/docs/resource-hierarchy#key_rings) を作成してください。

```console
gcloud kms keyrings create binauthz \
  --project $project_id \
  --location asia-northeast1
```

### 脆弱性スキャンに関する準備

コンテナのメタデータを管理する単位である[Note](https://cloud.google.com/container-analysis/docs/metadata-storage#note)を[作成](https://cloud.google.com/container-analysis/docs/reference/rest/v1/projects.notes/create)してください。

```console
curl "https://containeranalysis.googleapis.com/v1/projects/${project_id}/notes/?noteId=vulnz-note" \
  --request "POST" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer $(gcloud auth print-access-token)" \
  --header "X-Goog-User-Project: ${project_id}" \
  --data-binary @- <<EOF
{
  "name": "projects/${project_id}/notes/vulnz-note",
  "attestation": {
    "hint": {
      "human_readable_name": "Vulnerability scan note"
    }
  }
}
EOF
```

作成したNoteをCloud Buildから操作できるように[必要な権限](https://cloud.google.com/container-analysis/docs/ca-access-control)を[付与](https://cloud.google.com/container-analysis/docs/reference/rest/v1/projects.notes/setIamPolicy)します。

```console
curl "https://containeranalysis.googleapis.com/v1/projects/${project_id}/notes/vulnz-note:setIamPolicy" \
  --request POST \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer $(gcloud auth print-access-token)" \
  --header "X-Goog-User-Project: ${PROJECT_ID}" \
  --data-binary @- <<EOF
{
  "resource": "projects/${project_id}/notes/vulnz-note",
  "policy": {
    "bindings": [
      {
        "role": "roles/containeranalysis.notes.occurrences.viewer",
        "members": [
          "serviceAccount:${build_sa_email}"
        ]
      },
      {
        "role": "roles/containeranalysis.notes.attacher",
        "members": [
          "serviceAccount:${build_sa_email}"
        ]
      }
    ]
  }
}
EOF
```

署名のための鍵ペアを作成してください。

```console
gcloud kms keys create vulnz-signer \
  --project $project_id \
  --location asia-northeast1 \
  --keyring binauthz \
  --purpose asymmetric-signing \
  --default-algorithm rsa-sign-pkcs1-4096-sha512
```

署名を検証するための Binary Authorization の [Attestor](https://cloud.google.com/binary-authorization/docs/key-concepts#attestors) を作成してください。
Attestorはイメージをデプロイするときにそのイメージの署名が有効かどうかを検証します。

```console
gcloud container binauthz attestors create vulnz-attestor \
  --project $project_id \
  --attestation-authority-note-project $project_id \
  --attestation-authority-note vulns-note \
  --description "Vulnerability scan attestor"
```

作成したAttestorに検証用の公開鍵を追加してください。

```console
gcloud beta container binauthz attestors public-keys add \
  --project $project_id \
  --attestor vulnz-attestor \
  --keyversion 1 \
  --keyversion-keyring binauthz \
  --keyversion-key vulnz-signer \
  --keyversion-location asia-northeast1 \
  --keyversion-project $project_id
```

TODO:

```console
gcloud container binauthz attestors add-iam-policy-binding vulnz-attestor \
  --project $project_id \
  --member serviceAccount:$build_sa_email \
  --role roles/binaryauthorization.attestorsViewer
```

TODO:

```console
gcloud kms keys add-iam-policy-binding vulnz-signer \
  --project project_id \
  --location asia-northeast1 \
  --keyring binauthz \
  --member serviceAccount:$build_sa_email \
  --role roles/cloudkms.signerVerifier
```

### QAテストに関する準備

同じようにしてQAテストの署名をBinary Authorizationで検証するためのリソースを作成します。

Noteを作成してください。

```console
curl "https://containeranalysis.googleapis.com/v1/projects/${project_id}/notes/?noteId=qa-note" \
  --request "POST" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer $(gcloud auth print-access-token)" \
  --header "X-Goog-User-Project: ${project_id}" \
  --data-binary @- <<EOF
{
  "name": "projects/${project_id}/notes/qa-note",
  "attestation": {
    "hint": {
      "human_readable_name": "QA note"
    }
  }
}
EOF
```

Noteを操作するために必要な権限をCloud Buildのサービスアカウントに付与してください。

```console
curl "https://containeranalysis.googleapis.com/v1/projects/${project_id}/notes/qa-note:setIamPolicy" \
  --request POST \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer $(gcloud auth print-access-token)" \
  --header "X-Goog-User-Project: ${project_id}" \
  --data-binary @- <<EOF
{
  "resource": "projects/${project_id}/notes/qa-note",
  "policy": {
    "bindings": [
      {
        "role": "roles/containeranalysis.notes.occurrences.viewer",
        "members": [
          "serviceAccount:${build_sa_email}"
        ]
      },
      {
        "role": "roles/containeranalysis.notes.attacher",
        "members": [
          "serviceAccount:${build_sa_email}"
        ]
      }
    ]
  }
}
EOF
```

署名のための鍵ペアを作成してください。

```console
gcloud kms keys create qa-signer \
  --project $project_id \
  --location asia-northeast1 \
  --keyring binauthz \
  --purpose asymmetric-signing \
  --default-algorithm rsa-sign-pkcs1-4096-sha512
```

Attestorを作成してください。

```console
gcloud container binauthz attestors create qa-attestor \
 --project $project_id \
 --attestation-authority-note-project $project_id \
 --attestation-authority-note qa-note \
 --description "QA attestor"
```

Attestorに検証用の公開鍵を追加してください。

```console
gcloud beta container binauthz attestors public-keys add \
 --project $project_id \
 --attestor qa-attestor \
 --keyversion 1 \
 --keyversion-key qa-signer \
 --keyversion-keyring binauthz \
 --keyversion-location asia-northeast1 \
 --keyversion-project $project_id
```

TODO:

```console
gcloud container binauthz attestors add-iam-policy-binding qa-attestor \
 --project $project_id \
 --member serviceAccount:$build_sa_email \
 --role roles/binaryauthorization.attestorsViewer
```

TODO:

```console

```

### Binary Authorization ポリシーの設定

Binary Authorization の[ポリシー](https://cloud.google.com/binary-authorization/docs/key-concepts)はGKEクラスタへのコンテナイメージのデプロイを制御するルールです。
各Google Cloudプロジェクトに1つのポリシーを設定できます。

ポリシー YAML ファイルを作成してください。

```console
mkdir ~/$GROUP_NAME/platform-admin/binauth
cd ~/$GROUP_NAME/platform-admin/binauth
cat <<EOF > binauth.yaml
defaultAdmissionRule:
  enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG
  evaluationMode: ALWAYS_DENY
globalPolicyEvaluationMode: ENABLE
admissionWhitelistPatterns:
  - namePattern: gitlab/gitlab-runner-helper:x86_64-8fa89735
  - namePattern: gitlab/gitlab-runner-helper:x86_64-ece86343
  - namePattern: gitlab/gitlab-runner:alpine-v13.6.0
  - namePattern: gcr.io/abm-test-bed/gitlab-runner@sha256:8f623d3c55ffc783752d0b34097c5625a32a910a8c1427308f5c39fd9a23a3c0
  - namePattern: google/cloud-sdk
  - namePattern: gcr.io/cloud-builders/gke-deploy:latest
  - namePattern: gcr.io/kaniko-project/*
  - namePattern: gcr.io/cloud-solutions-images/kustomize:3.7
  - namePattern: gcr.io/kpt-functions/gatekeeper-validate
  - namePattern: gcr.io/kpt-functions/read-yaml
  - namePattern: gcr.io/stackdriver-prometheus/*
  - namePattern: gcr.io/$PROJECT_ID/cloudbuild-attestor
  - namePattern: gcr.io/config-management-release/*
clusterAdmissionRules:
  asia-northeast1-c.dev:
    evaluationMode: REQUIRE_ATTESTATION
    enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG
    requireAttestationsBy:
      - projects/$project_id/attestors/vulnz-attestor
  asia-northeast1-c.prod:
    evaluationMode: REQUIRE_ATTESTATION
    enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG
    requireAttestationsBy:
      - projects/$project_id/attestors/vulnz-attestor
      - projects/$project_id/attestors/qa-attestor
EOF
```

このポリシーでは、`clusterAdmissionRules`で各クラスタ固有のルールを設定しています。
`dev`クラスタ、`prod`クラスタともに、デプロイにイメージの署名を必須としています。
`dev`クラスタでは脆弱性検査の署名のみを必要として、`prod`クラスタでは脆弱性検査の署名とQAテストの署名を必須としています。

> aside positive
> ポリシーの詳細は[ドキュメント](https://cloud.google.com/binary-authorization/docs/configuring-policy-cli)を参照してください。
> クラスタ単位以外でも、Kubernetes Service Account単位やNamespace単位で制御することができます。

作成したポリシーを Binary Authorization にインポートしてください。

```console
gcloud container binauthz policy import ./binauth.yaml
```
