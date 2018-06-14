# This simple script creates a bunch of OpenShift pvs backed by a NFS server
size=5Gi
mode=ReadWriteOnce
policy=Recycle
GUID=1234
nfsServer=support1.${GUID}.internal
nfsExportDir=/srv/nfs

for i in {001..050}; do
  if [ $i -gt 025 ]; then
    size=10Gi
    mode=ReadWriteMany
    policy=Retain
  fi
  cat <<EOF | oc create -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv${i}
spec:
  capacity:
    storage: $size
  accessModes:
  - $mode
  nfs: 
    path: ${nfsExportDir}/pv${i}
    server: $nfsServer
  persistentVolumeReclaimPolicy: $policy
EOF
done
