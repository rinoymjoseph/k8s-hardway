kubectl create ns monitoring
kubectl apply -f clusterRole.yaml
kubectl apply -f config-map.yaml
kubectl apply -f prometheus-deployment.yaml 
kubectl apply -f prometheus-service.yaml