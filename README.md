# mockten-env(IaC & kustomize)
## Precondition
* owner権限ユーザで行うこと(GCP)
* python3がインストールされているマシンで行うこと
* (a)gcloudを用いるのが初めての場合、config設定をいれる
```
  gcloud config configurations create config
  gcloud config set core/project [PROJECT_ID]
  gcloud auth login
```  
* (b)GCPの旧環境設定が入っている場合はproject-ID更新する
```
  gcloud config set core/project [PROJECT_ID]
```

## CreateEnv
### 1.   createEnv.shを実行
```
  cd script
  sh createEnv.sh
```  
### 2.  作成されたmockten.netのNSの4つの値をDNSサービスNSにいれる

## DeestroyEnv
### 1.  該当GCPのProjectを停止
