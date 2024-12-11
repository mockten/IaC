sudo apt update
sudo apt install -y terraform
go install github.com/go-task/task/v3/cmd/task@latest

curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube