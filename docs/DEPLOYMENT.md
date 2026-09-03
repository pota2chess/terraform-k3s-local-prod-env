**DEPLOYMENT**

1. Get a token for localstack (https://app.localstack.cloud/) and import him to variable of terminal session (see .env.example)
2. Create s3-bucket: import AWS_ACCESS_KEY_ID and AWS_ACCESS_SECRET_KEY and run: aws --endpoint-url http://localhost:4566 s3 mb s3://terraform-state (check aws --endpoint-url http://localhost:4566 s3 ls)
3. Get a token for runner: after the project is launched, go to localhost:3000 and complete registration, go to **Setting -> Action -> Runner -> New runner** and get a token, import him to variable of terminal session (see .env.example). Run: terraform apply -replace=docker_container.gitea -replace=docker_container.runner
4. Add secrets for runner: copy kubernetes config (~/.kube/config) and go to Gitea to **Setting -> Action -> Secrets**. Import this config and change from server: https://127.0.0.1:6443 to server: https://k3s:6443
