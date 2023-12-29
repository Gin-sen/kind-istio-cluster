#!/bin/bash

nextip(){
    IP=$1
    IP_HEX=$(printf '%.2X%.2X%.2X%.2X\n' `echo $IP | sed -e 's/\./ /g'`)
    NEXT_IP_HEX=$(printf %.8X `echo $(( 0x$IP_HEX + 1 ))`)
    NEXT_IP=$(printf '%d.%d.%d.%d\n' `echo $NEXT_IP_HEX | sed -r 's/(..)/0x\1 /g'`)
    echo "$NEXT_IP"
}

# Create cluster
echo "Create cluster"
kind create cluster --name istio-testing --config cluster-config/kind.yaml
kind get clusters
kubectl config get-contexts
kubectl config use-context kind-istio-testing

# Install MetalLB
echo "Install MetalLB"
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml
kubectl wait --namespace metallb-system \
                --for=condition=ready pod \
                --selector=app=metallb \
                --timeout=90s

# Setup MetalLB
echo "Setup MetalLB"
# Get metalLB subnet and update yaml
METAL_GATEWAY_PLUS_ONE=$(nextip "$(docker network inspect -f "{{(index .IPAM.Config 0).Gateway}}" kind)")
METAL_RANGE="$METAL_GATEWAY_PLUS_ONE-$(ipcalc $(docker network inspect -f "{{(index .IPAM.Config 0).Subnet}}" kind) -b -n | grep HostMax | cut -d ' ' -f4)" \
  yq eval -i '. | select(.kind == "IPAddressPool").spec.addresses = [env(METAL_RANGE)]' cluster-config/metallb.yaml
kubectl apply -f cluster-config/metallb.yaml

# Setup Istio

kubectl create namespace istio-system
helm install istio-base istio/base -n istio-system --set defaultRevision=default
helm install istiod istio/istiod -n istio-system --wait

# Setup Gateway
kubectl create namespace istio-ingress
helm install istio-ingressgateway istio/gateway -n istio-ingress -f cluster-config/ingress-gateway-values.yaml

# Create test service
kubectl label namespace default istio-injection=enabled --overwrite
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/httpbin/httpbin.yaml
kubectl apply -f test/test-gateway.yaml
kubectl apply -f test/virtualservice.yaml

export INGRESS_NAME=istio-ingressgateway
export INGRESS_NS=istio-ingress

export INGRESS_HOST=$(kubectl -n "$INGRESS_NS" get service "$INGRESS_NAME" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export INGRESS_PORT=$(kubectl -n "$INGRESS_NS" get service "$INGRESS_NAME" -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')
export SECURE_INGRESS_PORT=$(kubectl -n "$INGRESS_NS" get service "$INGRESS_NAME" -o jsonpath='{.spec.ports[?(@.name=="https")].port}')
export TCP_INGRESS_PORT=$(kubectl -n "$INGRESS_NS" get service "$INGRESS_NAME" -o jsonpath='{.spec.ports[?(@.name=="tcp")].port}')

curl -s -I -HHost:httpbin.example.com "http://$INGRESS_HOST:$INGRESS_PORT/status/200"