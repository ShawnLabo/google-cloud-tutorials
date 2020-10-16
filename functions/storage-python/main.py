import os
from google.cloud import storage

# 環境変数からバケット名を取得
bucket_name = os.environ['BUCKET_NAME']

object_path = 'counter.txt'

client = storage.Client()

def main(_):
    print('Function が開始されました')

    bucket = client.get_bucket(bucket_name)
    print(f'バケットのメタデータを取得しました: {bucket.name}, {bucket.location}, {bucket.storage_class}')

    blob = bucket.get_blob(object_path)
    print(f'オブジェクト {object_path} のメタデータを取得しました: {blob.name}, {blob.size} bytes, {blob.updated}')

    counter_as_string = blob.download_as_string()
    print(f'オブジェクト {object_path} を取得しました: {counter_as_string}')

    counter = int(counter_as_string)
    print(f'現在のカウントは {counter} です')

    counter += 1
    print(f'次のカウントは {counter} です')

    blob = bucket.get_blob(object_path)
    blob.upload_from_string(str(counter))
    print(f'オブジェクト {object_path} のカウントを {counter} に更新しました')

    print('Function を終了します')
    return 'ok'

