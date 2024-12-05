#!/bin/bash

function istio() {
    # helm repo add istio https://istio-release.storage.googleapis.com/charts
    echo "TODO"

    kubectl create namespace istio-system
    helm install istio-base istio/base -n istio-system --set defaultRevision=default
    helm install istiod istio/istiod -n istio-system --wait

    kubectl create namespace istio-ingress
    helm install istio-ingressgateway istio/gateway -n istio-ingress

    #TODO

    kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/prometheus.yaml

    curl -L https://istio.io/downloadIstio | sh -
    kubectl apply -f istio-1.20.0/samples/addons/prometheus.yaml
    kubectl apply -f istio-1.20.0/samples/addons/kiali.yaml

}

function couchBase() {
    # https://docs.couchdb.org/en/stable/install/kubernetes.html
    # helm repo add couchdb https://apache.github.io/couchdb-helm
    # helm repo update
    helm upgrade --install cb couchdb/couchdb -f 3rd-party-values/couch-base.yaml
}

function vpa() {
    echo "TODO"
    #TODO
}

function hpa() {
    echo "TODO"
    #TODO
    #TODO - include metrics server
}

function hazelcast() {
    # helm repo add hazelcast https://hazelcast-charts.s3.amazonaws.com/

    helm upgrade --install my-release hazelcast/hazelcast -f 3rd-party-values/hazelcast-values.yaml #--set cluster.memberCount=3
    sleep 2
    sudo sed -i "/setenv HAZELCAST_IP/c\\\tsetenv HAZELCAST_IP $(kubectl get svc my-release-hazelcast -o json | jq -r '.spec.clusterIP')" /etc/haproxy/haproxy.cfg
}

function nginx() {
    kubectl apply -f k8-cluster/nginx.yaml -n litmus
}

function litmus() {
    # docs
    # https://github.com/litmuschaos/litmus-helm
    # https://v1-docs.litmuschaos.io/docs/pod-network-latency

    helm repo add litmuschaos https://litmuschaos.github.io/litmus-helm/
    kubectl create ns litmus

    helm install chaos litmuschaos/litmus --namespace=litmus --set portal.frontend.service.type=NodePort

    # helm install litmus-agent litmuschaos/litmus-agent \
    # --namespace litmus \
    # --set "INFRA_NAME=helm-agent" \
    # --set "INFRA_DESCRIPTION=My first agent deployed with helm !" \
    # --set "LITMUS_URL=http://chaos-litmus-frontend-service.litmus.svc.cluster.local:9091" \
    # --set "LITMUS_BACKEND_URL=http://chaos-litmus-server-service.litmus.svc.cluster.local:9002" \
    # --set "LITMUS_USERNAME=admin" \
    # --set "LITMUS_PASSWORD=litmus" \
    # --set "LITMUS_PROJECT_ID=69395cb3-0231-4262-8990-78056c8adb4c" \
    # --set "LITMUS_ENVIRONMENT_ID=test"

    # helm install litmus-agent ./litmus-helm/charts/litmus-agent \
    # --namespace litmus \
    # --set "INFRA_NAME=helm-agent" \
    # --set "INFRA_DESCRIPTION=My first agent deployed with helm !" \
    # --set "LITMUS_URL=http://chaos-litmus-frontend-service.litmus.svc.cluster.local:9091" \
    # --set "LITMUS_BACKEND_URL=http://chaos-litmus-server-service.litmus.svc.cluster.local:9002" \
    # --set "LITMUS_USERNAME=admin" \
    # --set "LITMUS_PASSWORD=litmus" \
    # --set "LITMUS_PROJECT_ID=69395cb3-0231-4262-8990-78056c8adb4c" \
    # --set "LITMUS_ENVIRONMENT_ID=test" \
    # --set "SA_EXISTS=false" \
    # --set "SKIP_SSL=true"   \
    # --set "global.INFRA_MODE=cluster" 

    helm install -n litmus kube-chaos litmuschaos/kubernetes-chaos

    # helm install litmus-agent litmuschaos/litmus-agent \
    # --namespace litmus --create-namespace \
    # --set "INFRA_NAME=helm-agent" \
    # --set "INFRA_DESCRIPTION=My first agent deployed with helm !" \
    # --set "LITMUS_URL=https://chaos-center.domain.com" \ # FOR REMOTE AGENT (INGRESS)
    # --set "LITMUS_URL=http://litmusportal-frontend-service.litmus.svc.cluster.local:9091" \ # FOR SELF AGENT (SVC)
    # --set "LITMUS_BACKEND_URL=http://litmusportal-server-service.litmus.svc.cluster.local:9002" \ # FOR SELF AGENT (SVC)
    # --set "LITMUS_USERNAME=admin" \
    # --set "LITMUS_PASSWORD=litmus" \
    # --set "LITMUS_PROJECT_ID=<PROJECT_ID>" \
    # --set "global.INFRA_MODE=cluster"


    # for the the service to get an IP
    sleep 3
    sudo sed -i "/setenv LITMUS_UI_IP/c\\\tsetenv LITMUS_UI_IP $(kubectl -n litmus get svc chaos-litmus-frontend-service -o json | jq -r '.spec.clusterIP')" /etc/haproxy/haproxy.cfg

    sudo service haproxy restart

    # kubectl apply -f https://litmuschaos.github.io/litmus/litmus-operator-v2.2.0.yaml
    # kubectl apply -f https://raw.githubusercontent.com/litmuschaos/litmus/master/mkdocs/docs/3.6.1/litmus-portal-crds-3.6.1.yml

    # helm install kchaos litmuschaos/kubernetes-chaos -n litmus
    # helm install kchaos litmuschaos/kubernetes-chaos -n litmus --version 3.9.0

    # kubectl -n litmus apply -f 3rd-party-values/litmus-test-rbca.yaml  
    # kubectl -n litmus apply -f 3rd-party-values/litmus-test-app.yaml
    # kubectl -n litmus apply -f 3rd-party-values/litmus-test.yaml


    #https://github.com/litmuschaos/litmusctl#installation


    # curl -X POST --user 'admin:Litmus1!!'  http://localhost:8185/api/v1/environments name=my-env


    # bash-4.4$ curl -X POST --user admin:litmus http://localhost:8185/auth/login -H 'Content-Type: application/json' -H 'Accept: application/json' -d '{"username": "admin", "password": "litmus"}'
    # {"accessToken":"eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3MzI5Nzc2NTcsInJvbGUiOiJhZG1pbiIsInVpZCI6IjFjZjc4OTg0LTcwYjMtNGIwYi1hZmY0LWM5NTViM2Y5ODBkZCIsInVzZXJuYW1lIjoiYWRtaW4ifQ.9MR0ywdvzl3Pp3QEreuVRwVngRtXOnWqjnVcRONFN_JHXaSQoNiHdv0X2b5O2n6Xg52628uXR2oXixYlMuadHA","expiresIn":86400,"projectID":"","projectRole":"Owner","type":"Bearer"}bash-4.4$ 


    #  kubectl exec -i deployment/chaos-litmus-frontend -n litmus -- /bin/bash -c "curl http://localhost:8185/auth/login -H 'Content-Type: application/json' -H 'Accept: application/json' -d '{\"username\": \"admin\", \"password\": \"litmus\"}'"

    password="Litmus1!"
    ct="Content-Type: application/json"
    a="Accept: application/json"
    
    sleep 60


    litmusServiceIP=$(kubectl -n litmus get svc chaos-litmus-frontend-service -o json | jq -r '.spec.clusterIP') 
    echo "litmusServiceIP is ${litmusServiceIP}"

    # 1.
    # kubectl exec -i deployment/chaos-litmus-server -n litmus -- /bin/bash -c "curl -X POST http://localhost:8080/query -H 'Content-Type: application/json' -H 'Accept: application/json' -d '{\"access_key\": \"eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3MzI5NzgxNjYsInJvbGUiOiJhZG1pbiIsInVpZCI6IjFjZjc4OTg0LTcwYjMtNGIwYi1hZmY0LWM5NTViM2Y5ODBkZCIsInVzZXJuYW1lIjoiYWRtaW4ifQ.5I_nDxVAtQu100\", \"password\": \"litmus\"}'" -H "Authorization: Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3MzI5NzgxNjYsInJvbGUiOiJhZG1pbiIsInVpZCI6IjFjZjc4OTg0LTcwYjMtNGIwYi1hZmY0LWM5NTViM2Y5ODBkZCIsInVzZXJuYW1lIjoiYWRtaW4ifQ.5I_nDxVAtQu100"

    bearerToken=$(curl -s -X POST http://${litmusServiceIP}:9091/auth/login -H "${ct}" -H "${a}" -d '{"username": "admin", "password": "litmus"}' | jq -r '.accessToken')
    echo "initial login done. Bearer: ${bearerToken}"

    # 2.
    curl -s -X POST http://${litmusServiceIP}:9091/auth/update/password -H "${ct}" -H "${a}" -d '{"username": "admin", "oldPassword": "litmus", "newPassword": "'${password}'"}' -H "Authorization: Bearer ${bearerToken}"

    # login again
    # bearerToken=$(curl -X POST http://${litmusServiceIP}:9091/auth/login -H "${ct}" -H "${a}" -d '{"username": "admin", "password": "'${password}'"}' | jq -r '.accessToken')
    # echo "second login done. New Bearer: ${bearerToken}"

    # 3. 
    rm ~/.litmusconfig

    litmusctl config set-account -n --endpoint "http://${litmusServiceIP}:9091" --password "${password}" --username "admin"

    # 4.
    litmusctl create project --name test-project
    projectId=$(litmusctl get projects -o json | jq -r '.projects[] | select(.name=="test-project") | .projectID')

    # 4.
    litmusctl create chaos-environment --project-id="${projectId}" --name="new-chaos-environment"

    # 5.
    litmusctl connect chaos-infra --name="new-chaos-infra" --environment-id="new_chaos_environment" --project-id="${projectId}" --non-interactive

    # 6.
    # https://litmuschaos.github.io/litmus/experiments/concepts/chaos-resources/chaos-engine/runtime-details/


    kubectl apply -f k8-cluster/nginx.yaml -n litmus

    sleep 2
    sudo sed -i "/setenv NGINX_IP/c\\\tsetenv NGINX_IP $(kubectl -n litmus get svc nginx-service -o json | jq -r '.spec.clusterIP')" /etc/haproxy/haproxy.cfg


    kubectl -n litmus apply -f k8-cluster/chaos-engine.yaml

}



