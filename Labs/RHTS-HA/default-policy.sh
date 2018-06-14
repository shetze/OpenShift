# This script creates some useful default OpenShift NetworkPolicy objects suitable as a starter for any namespace
namespace=myproject

cat <<EOF | oc create -n $namespace -f -
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: deny-by-default
spec:
  podSelector:
  ingress: []
EOF

cat <<EOF | oc create -n $namespace -f -
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: allow-from-same-namespace
spec:
  podSelector:
  ingress:
  - from:
    - podSelector: {}
EOF

cat <<EOF | oc create -n $namespace -f -
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: allow-from-default-namespace
spec:
  podSelector:
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: default
EOF


