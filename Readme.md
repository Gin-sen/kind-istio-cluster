# kind with istio setup

Prérequis:
- [docker](https://docs.docker.com/get-docker/)
- [Augmenter la mémoire limite de Docker](https://istio.io/latest/docs/setup/platform-setup/docker/)
- [kind](https://kind.sigs.k8s.io/docs/user/quick-start/)
- [kubectl](https://kubernetes.io/fr/docs/tasks/tools/install-kubectl/)
- [istioctl](https://istio.io/latest/docs/setup/install/istioctl/)
- ipcalc (sudo apt install ipcalc)

`helm repo add istio https://istio-release.storage.googleapis.com/charts` 
`helm repo update`

# create cluster
