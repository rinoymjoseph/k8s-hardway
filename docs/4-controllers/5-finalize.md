# Start the services and be happy!
sudo systemctl daemon-reload
sudo systemctl enable kube-apiserver kube-controller-manager kube-scheduler
sudo systemctl start kube-apiserver kube-controller-manager kube-scheduler


# Setup the HTTP health checks
# Since the /healthz check sits on port 6443, and you’re not exposing that, you need to get nginx installed as a proxy (or any other proxy service you wish of course).

sudo apt install -y nginx
cat > kubernetes.default.svc.cluster.local <<EOF
server {
  listen      80;
  server_name kubernetes.default.svc.cluster.local;
location /healthz {
     proxy_pass                    https://127.0.0.1:6443/healthz;
     proxy_ssl_trusted_certificate /var/lib/kubernetes/ca.pem;
  }
}
EOF
sudo rm /etc/nginx/sites-enabled/default
sudo mv kubernetes.default.svc.cluster.local /etc/nginx/sites-available/kubernetes.default.svc.cluster.local
sudo ln -s /etc/nginx/sites-available/kubernetes.default.svc.cluster.local /etc/nginx/sites-enabled/
sudo systemctl restart nginx

# Verify all is healthy
kubectl get componentstatuses --kubeconfig admin.kubeconfig

# You should get a response with no errors from controller-manager, scheduler and etcd-x as shown below.

## Results

Warning: v1 ComponentStatus is deprecated in v1.19+
NAME                 STATUS    MESSAGE                         ERROR
scheduler            Healthy   ok                              
controller-manager   Healthy   ok                              
etcd-0               Healthy   {"health":"true","reason":""} 

# Test the nginx proxy is working

curl -H "Host: kubernetes.default.svc.cluster.local" -i http://127.0.0.1/healthz

## Results

HTTP/1.1 200 OK
Server: nginx/1.18.0 (Ubuntu)
Date: Tue, 21 Mar 2023 13:05:12 GMT
Content-Type: text/plain; charset=utf-8
Content-Length: 2
Connection: keep-alive
Audit-Id: 3e6af70b-80b2-4c32-86d2-c67328ceb772
Cache-Control: no-cache, private
X-Content-Type-Options: nosniff

# RBAC for the win!
# Create the ClusterRole and ClusterRoleBinding on one of the controllers.
# This allows the kube-apiserver to “talk” to the kubelet. Without this requests would fail.

cat <<EOF | kubectl apply --kubeconfig admin.kubeconfig -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:kube-apiserver-to-kubelet
rules:
  - apiGroups:
      - ""
    resources:
      - nodes/proxy
      - nodes/stats
      - nodes/log
      - nodes/spec
      - nodes/metrics
    verbs:
      - "*"
EOF

cat <<EOF | kubectl apply --kubeconfig admin.kubeconfig -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: system:kube-apiserver
  namespace: ""
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kube-apiserver-to-kubelet
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: kubernetes
EOF