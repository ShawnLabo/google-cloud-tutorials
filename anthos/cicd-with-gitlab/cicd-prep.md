### platform-admin リポジトリの作成

`platform-admin` リポジトリを作成します。
`platform-admin` リポジトリでは、アプリケーションのCI/CDパイプラインで使うための再利用可能なCI/CDの部品が管理されます。
このリポジトリはプラットフォーム運用・セキュリティチームが管理します。

> aside positive
> セキュリティチームやプラットフォーム運用チームが扱うリポジトリと
> 開発者が開発に利用するリポジトリを分割することで
> それぞれが自分たちの役割に集中することが可能になります。

GitLab.comで作成したグループに`platform-admin`というパブリックプロジェクトを作成してください。


ローカルにクローンしてください。

```console
git clone git@gitlab.com:$GROUP_NAME/platform-admin.git ~/$GROUP_NAME/platform-admin
```

### ビルドステージの作成

CI/CD パイプラインの最初のステージとして、Dockerfileからコンテナイメージをビルドするステージを作成します。
[ステージ](https://docs.gitlab.com/ee/ci/yaml/#stages)とはGitLab CI/CDにおけるCI/CDパイプラインの1つのステップのことを表します。
本ラボではステージの単位で再利用可能なCI/CDの部品を作成します。

ビルドステージでは[kaniko](https://github.com/GoogleContainerTools/kaniko#kaniko---build-images-in-kubernetes)を使ってコンテナイメージをビルドして、[Container Registry](https://cloud.google.com/container-registry) (gcr.io) にプッシュします。

`platform-admin`に`build` ディレクトリを作成してください。

```console
cd ~/$GROUP_NAME/platform-admin
mkdir build
```

`build`ディレクトリに `build-container.yaml` ファイルを作成してください。

```console
cat << 'EOF' > build/build-container.yaml
build:
 stage: Build
 tags:
   - prod
 image:
   name: gcr.io/kaniko-project/executor:debug
   entrypoint: [""]
 script:
   - echo "Building container image and pushing to gcr.io in ${PROJECT_ID}"
   - /kaniko/executor --context ${CI_PROJECT_DIR} --dockerfile ${CI_PROJECT_DIR}/Dockerfile --destination ${HOSTNAME}/${PROJECT_ID}/${CONTAINER_NAME}:${CI_COMMIT_SHORT_SHA}
EOF
```

`PROJECT_ID`などの環境変数はアプリケーション側の`.gitlab-ci.yml`で設定します。
`CI_PROJECT_ID`などの環境変数は[あらかじめGitLab CI/CDで定義](https://docs.gitlab.com/ee/ci/variables/predefined_variables.html)されています。

> aside positive
> GitLab CI/CDでは[`image`](https://docs.gitlab.com/ee/ci/yaml/index.html#image)で指定したコンテナイメージを利用して処理をすることができます。

変更をコミットしてプッシュしてください。

```console
git add .
git commit -m "Add Build stage"
git push -u origin main
```

### アプリケーションの準備

このラボではアプリケーションとして [hello-kubernetes](https://github.com/itodotimothy6/hello-kubernetes) を利用します。
hello-kubernetesをCI/CDするためのCI/CDパイプラインを構築します。

`platform-admin`と同じように、GitLab.comで`hello-kubernetes`プロジェクトを作成してください。

hello-kubernetesをダウンロードしてください。

```console
git clone https://github.com/itodotimothy6/hello-kubernetes.git ~/$GROUP_NAME/hello-kubernetes
cd ~/$GROUP_NAME/hello-kubernetes
```

元のリポジトリの情報を削除して、作成したGitLabのリポジトリにプッシュしてください。

```console
rm -rf .git
git init .
git remote add origin git@gitlab.com:$GROUP_NAME/hello-kubernetes
git add .
git commit -m "Initial commit"
git push -u origin main
```


### CI/CD パイプラインの作成

最初のパイプラインを作成します。

