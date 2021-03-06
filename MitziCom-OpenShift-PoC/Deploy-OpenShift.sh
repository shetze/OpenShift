DOMAIN=example.opentlc.com
read -p "
This script will perform a completely automated OpenShift deployment into the OpenShift HA Deployment lab environment.
In order to get things going you need to provide some details about your current lab environment.

What is the GUID of your lab? " GUID

read -p "
For user authentication in your new OpenShift cluster you have the option
to use simple htaccess security and/or an LDAP backend. You must provide
the information for at least one of the two options and you may use both.

If you want to use htaccess, you must provide a username and password you want
to use as your admin login for the OpenShift UI. If you want to go for LDAP
only, you can simply provide an empty username here.

What is the user name for for your htaccess user? " htuser
if [ -n "$htuser" ]; then 
    read -p "What is the password for your htaccess user? " htpasswd
    if [ -z "$htpasswd" ]; then 
        htpasswd=$(pwmake 64)
        echo "You did not provide a password for your htaccess user $htuser, generating one for you: $htpasswd"
        echo "Write down and remember your new password $htpasswd."
    fi
fi
read -p "What is the password for your LDAP bind-user? " ldappasswd

mkdir Workdir
cd Workdir
cat > hosts <<EOF
[OSEv3:vars]

###########################################################################
### Ansible Vars
###########################################################################
timeout=60
ansible_become=yes
ansible_ssh_user=ec2-user

# disable memory check, as we are not a production environment
openshift_disable_check="memory_availability"

# Set this line to enable NFS
openshift_enable_unsupported_configurations=True


openshift_deployment_type=openshift-enterprise

openshift_master_cluster_hostname=loadbalancer1.${GUID}.internal
openshift_master_cluster_public_hostname=loadbalancer.${GUID}.${DOMAIN}
openshift_master_default_subdomain=apps.${GUID}.${DOMAIN}
openshift_hosted_infra_selector='env=infra'
osm_default_node_selector='env=app'
# os_sdn_network_plugin_name='redhat/openshift-ovs-subnet'
os_sdn_network_plugin_name='redhat/openshift-ovs-networkpolicy'

openshift_hosted_manage_router=true
openshift_router_selector='env=infra'

EOF

if [ -n "$htuser" -a -z $ldappasswd ]; then 
cat >> hosts <<EOF
openshift_master_identity_providers=[{'name': 'htpasswd_auth', 'login': 'true', 'challenge': 'true', 'kind': 'HTPasswdPasswordIdentityProvider', 'filename': '/etc/origin/master/htpasswd'}]
openshift_master_htpasswd_file=$(pwd)/htpasswd.openshift
EOF

htpasswd -bc htpasswd.openshift $htuser $htpasswd
htpasswd -b htpasswd.openshift Karla $htpasswd
htpasswd -b htpasswd.openshift Amy $htpasswd
htpasswd -b htpasswd.openshift Andrew $htpasswd
htpasswd -b htpasswd.openshift Brian $htpasswd
htpasswd -b htpasswd.openshift Betty $htpasswd
# cat >htpasswd.openshift <<EOF
# Karla:$apr1$DpRgUyzo$PJi80BGYnG4LwQYtcxSKS/
# Amy:$apr1$bP0BZrra$iSHQdktQVugmU89gDUMIr/
# Andrew:$apr1$rjBVf1t0$IADZkyw96wRsXA5mkk/zf1
# Brian:$apr1$z1igPmSV$QlIZDKWe2c3FB2mkogU1g1
# Betty:$apr1$4M2reEts$WiAMyak5aqHNEkoZIS2iq0
# EOF

fi

if [ -z "$htuser" -a -n $ldappasswd ]; then 
cat >> hosts <<EOF
openshift_master_identity_providers=[{'name': 'ldap', 'challenge': 'true', 'login': 'true', 'kind': 'LDAPPasswordIdentityProvider','attributes': {'id': ['dn'], 'email': ['mail'], 'name': ['cn'], 'preferredUsername': ['uid']}, 'bindDN': 'uid=admin,cn=users,cn=accounts,dc=shared,dc=example,dc=opentlc,dc=com', 'bindPassword': '${ldappasswd}', 'ca': '/etc/origin/master/ipa-ca.crt','insecure': 'false', 'url': 'ldaps://ipa.shared.${DOMAIN}:636/cn=users,cn=accounts,dc=shared,dc=example,dc=opentlc,dc=com?uid?sub?(memberOf=cn=ocp-users,cn=groups,cn=accounts,dc=shared,dc=example,dc=opentlc,dc=com)'}]
openshift_master_ldap_ca_file=$(pwd)/ipa-ca.crt
EOF
wget http://ipa.shared.${DOMAIN}/ipa/config/ca.crt -O ipa-ca.crt
fi

if [ -n "$htuser" -a -n $ldappasswd ]; then 
cat >> hosts <<EOF
openshift_master_identity_providers=[{'name': 'htpasswd_auth', 'login': 'true', 'challenge': 'true', 'kind': 'HTPasswdPasswordIdentityProvider', 'filename': '/etc/origin/master/htpasswd'},{'name': 'ldap', 'challenge': 'true', 'login': 'true', 'kind': 'LDAPPasswordIdentityProvider','attributes': {'id': ['dn'], 'email': ['mail'], 'name': ['cn'], 'preferredUsername': ['uid']}, 'bindDN': 'uid=admin,cn=users,cn=accounts,dc=shared,dc=example,dc=opentlc,dc=com', 'bindPassword': '${ldappasswd}', 'ca': '/etc/origin/master/ipa-ca.crt','insecure': 'false', 'url': 'ldaps://ipa.shared.${DOMAIN}:636/cn=users,cn=accounts,dc=shared,dc=example,dc=opentlc,dc=com?uid?sub?(memberOf=cn=ocp-users,cn=groups,cn=accounts,dc=shared,dc=example,dc=opentlc,dc=com)'}]
openshift_master_ldap_ca_file=$(pwd)/ipa-ca.crt
openshift_master_htpasswd_file=$(pwd)/htpasswd.openshift
EOF
wget http://ipa.shared.${DOMAIN}/ipa/config/ca.crt -O ipa-ca.crt
htpasswd -bc htpasswd.openshift $htuser $htpasswd
htpasswd -b htpasswd.openshift Karla $htpasswd
htpasswd -b htpasswd.openshift Amy $htpasswd
htpasswd -b htpasswd.openshift Andrew $htpasswd
htpasswd -b htpasswd.openshift Brian $htpasswd
htpasswd -b htpasswd.openshift Betty $htpasswd
fi

cat >> hosts <<EOF


# openshift_hosted_registry_replicas=1
openshift_hosted_registry_storage_kind=nfs
openshift_hosted_registry_storage_access_modes=['ReadWriteMany']
openshift_hosted_registry_storage_host=support1.${GUID}.internal
openshift_hosted_registry_storage_nfs_directory=/srv/nfs
openshift_hosted_registry_storage_volume_name=registry
openshift_hosted_registry_storage_volume_size=10Gi

openshift_metrics_install_metrics=true
openshift_metrics_storage_kind=nfs
openshift_metrics_storage_access_modes=['ReadWriteOnce']
openshift_metrics_storage_nfs_options='*(rw,root_squash)'
openshift_metrics_storage_nfs_directory=/srv/nfs
openshift_metrics_storage_volume_name=metrics
openshift_metrics_storage_volume_size=10Gi
openshift_metrics_cassandra_nodeselector={"env":"infra"}
openshift_metrics_hawkular_nodeselector={"env":"infra"}
openshift_metrics_heapster_nodeselector={"env":"infra"}

openshift_logging_install_logging=true
openshift_logging_storage_kind=nfs
openshift_logging_storage_access_modes=['ReadWriteOnce']
openshift_logging_storage_nfs_options='*(rw,root_squash)'
openshift_logging_storage_nfs_directory=/srv/nfs
openshift_logging_storage_volume_name=logging
openshift_logging_storage_volume_size=10Gi
openshift_logging_es_nodeselector={"env":"infra"}
openshift_logging_kibana_nodeselector={"env":"infra"}
openshift_logging_curator_nodeselector={"env":"infra"}

openshift_enable_service_catalog=true
openshift_hosted_etcd_storage_kind=nfs
openshift_hosted_etcd_storage_nfs_options="*(rw,root_squash,sync,no_wdelay)"
openshift_hosted_etcd_storage_nfs_directory=/srv/nfs
openshift_hosted_etcd_storage_volume_name=etcd-vol2 
openshift_hosted_etcd_storage_access_modes=["ReadWriteOnce"]
openshift_hosted_etcd_storage_volume_size=1G
openshift_hosted_etcd_storage_labels={'storage': 'etcd'}

# Add Prometheus Metrics:
openshift_hosted_prometheus_deploy=true
openshift_prometheus_node_selector={"env":"infra"}
openshift_prometheus_namespace=openshift-metrics

# Prometheus
openshift_prometheus_storage_kind=nfs
openshift_prometheus_storage_access_modes=['ReadWriteOnce']
openshift_prometheus_storage_nfs_directory=/srv/nfs
openshift_prometheus_storage_nfs_options='*(rw,root_squash)'
openshift_prometheus_storage_volume_name=prometheus
openshift_prometheus_storage_volume_size=10Gi
openshift_prometheus_storage_labels={'storage': 'prometheus'}
openshift_prometheus_storage_type='pvc'
# For prometheus-alertmanager
openshift_prometheus_alertmanager_storage_kind=nfs
openshift_prometheus_alertmanager_storage_access_modes=['ReadWriteOnce']
openshift_prometheus_alertmanager_storage_nfs_directory=/srv/nfs
openshift_prometheus_alertmanager_storage_nfs_options='*(rw,root_squash)'
openshift_prometheus_alertmanager_storage_volume_name=prometheus-alertmanager
openshift_prometheus_alertmanager_storage_volume_size=10Gi
openshift_prometheus_alertmanager_storage_labels={'storage': 'prometheus-alertmanager'}
openshift_prometheus_alertmanager_storage_type='pvc'
# For prometheus-alertbuffer
openshift_prometheus_alertbuffer_storage_kind=nfs
openshift_prometheus_alertbuffer_storage_access_modes=['ReadWriteOnce']
openshift_prometheus_alertbuffer_storage_nfs_directory=/srv/nfs
openshift_prometheus_alertbuffer_storage_nfs_options='*(rw,root_squash)'
openshift_prometheus_alertbuffer_storage_volume_name=prometheus-alertbuffer
openshift_prometheus_alertbuffer_storage_volume_size=10Gi
openshift_prometheus_alertbuffer_storage_labels={'storage': 'prometheus-alertbuffer'}
openshift_prometheus_alertbuffer_storage_type='pvc'

# Necessary because of a bug in the installer on 3.9
openshift_prometheus_node_exporter_image_version=v3.9

###########################################################################
### OpenShift Hosts
###########################################################################
[OSEv3:children]
lb
masters
etcd
nodes
nfs
#glusterfs

[lb]
loadbalancer1.${GUID}.internal

[masters]
master1.${GUID}.internal
master2.${GUID}.internal
master3.${GUID}.internal

[etcd]
master1.${GUID}.internal
master2.${GUID}.internal
master3.${GUID}.internal

[nodes]
## These are the masters
master1.${GUID}.internal openshift_hostname=master1.${GUID}.internal  openshift_node_labels="{'env': 'master', 'cluster': '$GUID'}"
master2.${GUID}.internal openshift_hostname=master2.${GUID}.internal  openshift_node_labels="{'env': 'master', 'cluster': '$GUID'}"
master3.${GUID}.internal openshift_hostname=master3.${GUID}.internal  openshift_node_labels="{'env': 'master', 'cluster': '$GUID'}"

## These are infranodes
infranode1.${GUID}.internal openshift_hostname=infranode1.${GUID}.internal  openshift_node_labels="{'env':'infra', 'cluster': '$GUID'}"
infranode2.${GUID}.internal openshift_hostname=infranode2.${GUID}.internal  openshift_node_labels="{'env':'infra', 'cluster': '$GUID'}"

## These are regular nodes
node1.${GUID}.internal openshift_hostname=node1.${GUID}.internal  openshift_node_labels="{'env':'app', 'cluster': '$GUID'}"
node2.${GUID}.internal openshift_hostname=node2.${GUID}.internal  openshift_node_labels="{'env':'app', 'cluster': '$GUID'}"
node3.${GUID}.internal openshift_hostname=node3.${GUID}.internal  openshift_node_labels="{'env':'app', 'cluster': '$GUID'}"

## These are CNS nodes
# support1.${GUID}.internal openshift_hostname=support1.${GUID}.internal  openshift_node_labels="{'env':'glusterfs', 'cluster': '$GUID'}"
# support2.${GUID}.internal openshift_hostname=support2.${GUID}.internal  openshift_node_labels="{'env':'glusterfs', 'cluster': '$GUID'}"
# support3.${GUID}.internal openshift_hostname=support3.${GUID}.internal  openshift_node_labels="{'env':'glusterfs', 'cluster': '$GUID'}"

[nfs]
support1.${GUID}.internal openshift_hostname=support1.${GUID}.internal

#[glusterfs]
# support1.${GUID}.internal glusterfs_devices='[ "/dev/xvdd" ]'
# support2.${GUID}.internal glusterfs_devices='[ "/dev/xvdd" ]'
# support3.${GUID}.internal glusterfs_devices='[ "/dev/xvdd" ]'
EOF


read -p "Ansible Inventory file created and ready to go. Type Y to proceed with the deployment? " answer

if [ "$answer" != "Y" ]; then
  echo "Thank you for trying the OpenShift PoC Deployment Script."
  echo "Keeping the Workdir for further investigation, please delete manually if you are done."
  exit 0
fi

echo
echo "Starting the MitziCom OpenShift Instant PoC Deployment."
echo "Be patient, this will take at least 30 minutes to finish."
echo "You may follow the results log in Workdir/PoC-Results.adoc"
exec > PoC-Results.adoc
exec 2>&1


echo
echo "=== Basic and HA Requirements"
echo

echo
echo
echo "* PoC Use Case: Set up storage, networking, and other environment configurations"
echo
echo "----"
echo ansible nfs -m shell -a 'for i in {001..050}; do mkdir /srv/nfs/pv$i; chown nfsnobody:nfsnobody /srv/nfs/pv$i; chmod 777 /srv/nfs/pv$i; done'
echo
ansible nfs -m shell -a 'for i in {001..050}; do mkdir /srv/nfs/pv$i; chown nfsnobody:nfsnobody /srv/nfs/pv$i; chmod 777 /srv/nfs/pv$i; done'
echo "----"


echo
echo
echo "* PoC Use Case: Provide instructions for the MitziCom administrator to deploy all the above in a single command"
echo
echo "----"
echo "ansible-playbook -i ./hosts -f 20 //usr/share/ansible/openshift-ansible/playbooks/prerequisites.yml"
echo
ansible-playbook -i ./hosts -f 20  /usr/share/ansible/openshift-ansible/playbooks/prerequisites.yml | tail -n 40
echo "----"
echo
echo "----"
echo "ansible-playbook -i ./hosts -f 20 /usr/share/ansible/openshift-ansible/playbooks/deploy_cluster.yml"
echo
ansible-playbook -i ./hosts -f 20 /usr/share/ansible/openshift-ansible/playbooks/deploy_cluster.yml | tail -n 40
echo "----"

echo "----"
echo ansible masters[0] -b -m fetch -a \"src=/root/.kube/config dest=/root/.kube/config flat=yes\"
echo
ansible masters[0] -b -m fetch -a "src=/root/.kube/config dest=/root/.kube/config flat=yes"
echo "----"

echo
echo
echo "* PoC Use Case: Ability to authenticate at the master console"
if [ -n "$htuser" ]; then 
  echo "----"
  echo oc adm policy add-cluster-role-to-user cluster-admin $htuser
  echo
  oc adm policy add-cluster-role-to-user cluster-admin $htuser
  echo
  echo
  echo oc adm policy add-cluster-role-to-user cluster-admin Karla
  echo
  oc adm policy add-cluster-role-to-user cluster-admin Karla
  echo "----"
fi
if [ -n "$ldappasswd" ]; then 
echo "----"
cat << EOF > groupsync.yaml
kind: LDAPSyncConfig
apiVersion: v1
url: "ldap://ipa.shared.${DOMAIN}"
insecure: false
ca: "$(pwd)/ipa-ca.crt"
bindDN: "uid=admin,cn=users,cn=accounts,dc=shared,dc=example,dc=opentlc,dc=com"
bindPassword: "r3dh4t1!"
rfc2307:
    groupsQuery:
        baseDN: "cn=groups,cn=accounts,dc=shared,dc=example,dc=opentlc,dc=com"
        scope: sub
        derefAliases: never
        filter: (&(!(objectClass=mepManagedEntry))(!(cn=trust admins))(!(cn=groups))(!(cn=admins))(!(cn=ipausers))(!(cn=editors))(!(cn=ocp-users))(!(cn=evmgroup*))(!(cn=ipac*)))
    groupUIDAttribute: dn
    groupNameAttributes: [ cn ]
    groupMembershipAttributes: [ member ]
    usersQuery:
        baseDN: "cn=users,cn=accounts,dc=shared,dc=example,dc=opentlc,dc=com"
        scope: sub
        derefAliases: never
    userUIDAttribute: dn
    userNameAttributes: [ uid ]
EOF

cat << EOF > whitelist.yaml
cn=portalapp,cn=groups,cn=accounts,dc=shared,dc=example,dc=opentlc,dc=com
cn=paymentapp,cn=groups,cn=accounts,dc=shared,dc=example,dc=opentlc,dc=com
cn=ocp-platform,cn=groups,cn=accounts,dc=shared,dc=example,dc=opentlc,dc=com
cn=ocp-production,cn=groups,cn=accounts,dc=shared,dc=example,dc=opentlc,dc=com
EOF
echo "oc adm groups sync --sync-config=$(pwd)/groupsync.yaml --whitelist=$(pwd)/whitelist.yaml --confirm"
oc adm groups sync --sync-config=$(pwd)/groupsync.yaml --whitelist=$(pwd)/whitelist.yaml --confirm
echo "oc adm policy add-cluster-role-to-group cluster-admin ocp-platform"
echo
oc adm policy add-cluster-role-to-group cluster-admin ocp-platform
echo "----"
fi

echo
echo
echo "* PoC Use Case: Registry has storage attached and working"
registryPod=$(oc get pods -n default|grep docker-registry|cut -d' ' -f1)
echo
echo "----"
echo "oc describe pod ${registryPod} -n default"
echo
oc describe pod ${registryPod} -n default
echo "----"


echo
echo
echo "* PoC Use Case: Router is configured on each infranode"
echo
echo "----"
echo "oc get pods -o wide -n default |grep router"
echo
oc get pods -o wide -n default |grep router
echo "----"

echo
echo
echo "* PoC Use Case: PVs of different types are available for users to consume"
echo
echo "----"
size=5Gi
mode=ReadWriteOnce
policy=Recycle
for i in {001..050}; do
  if [ $i -gt 010 ]; then
    size=10Gi
    mode=ReadWriteOnce
    policy=Recycle
  fi
  if [ $i -gt 025 ]; then
    size=10Gi
    mode=ReadWriteMany
    policy=Recycle
  fi
  if [ $i -gt 040 ]; then
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
    path: /srv/nfs/pv${i}
    server: support1.${GUID}.internal
  persistentVolumeReclaimPolicy: $policy
EOF
done
echo "oc get pv|grep Available"
echo
oc get pv|grep Available
echo "----"

echo
echo
echo "* PoC Use Case: Ability to deploy a simple app (nodejs-mongo-persistent)"
echo
echo "----"
oc new-project smoke-test
oc new-app nodejs-mongo-persistent
oc get pod
oc get route
echo "----"


echo
echo
echo "* PoC Use Case:  There are three masters working"
echo "oc get nodes|grep master"
echo
echo "----"
oc get nodes|grep master
echo "----"


echo
echo
echo "* PoC Use Case: There are three etcd instances working"
echo
echo "----"
echo "ansible masters[0] -m shell -a '/usr/bin/etcdctl --cert-file /etc/etcd/peer.crt --key-file /etc/etcd/peer.key --ca-file /etc/etcd/ca.crt -C https://`hostname`:2379 cluster-health'"
echo
ansible masters[0] -m shell -a '/usr/bin/etcdctl --cert-file /etc/etcd/peer.crt --key-file /etc/etcd/peer.key --ca-file /etc/etcd/ca.crt -C https://`hostname`:2379 cluster-health'
echo "----"

echo
echo
echo "* PoC Use Case: There is a load balancer to access the masters called loadbalancer.$GUID.$DOMAIN"
echo
echo "----"
echo curl http://loadbalancer.$GUID.${DOMAIN}:9000/
echo
curl http://loadbalancer.$GUID.${DOMAIN}:9000/ | grep master
echo "----"

echo
echo
echo "* PoC Use Case: There is a load balancer/DNS for both infranodes called *.apps.$GUID.$DOMAIN"
echo
echo "----"
echo "host *.apps.${GUID}.${DOMAIN}"
echo
host *.apps.${GUID}.${DOMAIN}
echo "----"

echo
echo
echo "* PoC Use Case: There are at least two infranodes, labeled env=infra"
echo
echo "----"
echo "oc get nodes -l env=infra"
echo
oc get nodes -l env=infra
echo "----"

echo
echo "=== Environment Configuration"
echo

echo
echo
echo "* PoC Use Case: NetworkPolicy is configured and working with projects isolated by default (simulate Multitenancy)"
echo
echo "----"
echo "oc label namespace default name=default"
oc label namespace default name=default
cat <<EOF > project-request-template.yaml
apiVersion: v1
kind: Template
metadata:
  creationTimestamp: null
  name: project-request
objects:
- apiVersion: project.openshift.io/v1
  kind: Project
  metadata:
    annotations:
      openshift.io/description: \${PROJECT_DESCRIPTION}
      openshift.io/display-name: \${PROJECT_DISPLAYNAME}
      openshift.io/requester: \${PROJECT_REQUESTING_USER}
    creationTimestamp: null
    name: \${PROJECT_NAME}
  spec: {}
  status: {}
- apiVersion: rbac.authorization.k8s.io/v1beta1
  kind: RoleBinding
  metadata:
    creationTimestamp: null
    name: system:image-pullers
    namespace: \${PROJECT_NAME}
  roleRef:
    apiGroup: rbac.authorization.k8s.io
    kind: ClusterRole
    name: system:image-puller
  subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: Group
    name: system:serviceaccounts:\${PROJECT_NAME}
- apiVersion: rbac.authorization.k8s.io/v1beta1
  kind: RoleBinding
  metadata:
    creationTimestamp: null
    name: system:image-builders
    namespace: \${PROJECT_NAME}
  roleRef:
    apiGroup: rbac.authorization.k8s.io
    kind: ClusterRole
    name: system:image-builder
  subjects:
  - kind: ServiceAccount
    name: builder
    namespace: \${PROJECT_NAME}
- apiVersion: rbac.authorization.k8s.io/v1beta1
  kind: RoleBinding
  metadata:
    creationTimestamp: null
    name: system:deployers
    namespace: \${PROJECT_NAME}
  roleRef:
    apiGroup: rbac.authorization.k8s.io
    kind: ClusterRole
    name: system:deployer
  subjects:
  - kind: ServiceAccount
    name: deployer
    namespace: \${PROJECT_NAME}
- apiVersion: rbac.authorization.k8s.io/v1beta1
  kind: RoleBinding
  metadata:
    creationTimestamp: null
    name: admin
    namespace: \${PROJECT_NAME}
  roleRef:
    apiGroup: rbac.authorization.k8s.io
    kind: ClusterRole
    name: admin
  subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: \${PROJECT_ADMIN_USER}
- apiVersion: networking.k8s.io/v1
  kind: NetworkPolicy
  metadata:
    name: allow-from-same-namespace
  spec:
    podSelector:
    ingress:
    - from:
      - podSelector: {}
- apiVersion: networking.k8s.io/v1
  kind: NetworkPolicy
  metadata:
    name: allow-from-default-namespace
  spec:
    podSelector:
    ingress:
    - from:
      - namespaceSelector:
          matchLabels:
            name: default
- apiVersion: v1
  kind: LimitRange
  metadata:
    creationTimestamp: null
    name: core-resource-limits
  spec:
    limits:
    - type: Pod
      max:
        cpu: "10"
        memory: 8Gi
      min:
        cpu: 50m
        memory: 100Mi
    - type: Container
      min:
        cpu: 50m
        memory: 100Mi
      max:
        cpu: "10"
        memory: 8Gi
      default:
        cpu: 50m
        memory: 100Mi
      defaultRequest:
        cpu: 50m
        memory: 100Mi
      maxLimitRequestRatio:
        cpu: "200"
parameters:
- name: PROJECT_NAME
- name: PROJECT_DISPLAYNAME
- name: PROJECT_DESCRIPTION
- name: PROJECT_ADMIN_USER
- name: PROJECT_REQUESTING_USER
EOF
echo oc create -n default -f project-request-template.yaml
echo
oc create -n default -f project-request-template.yaml
echo
echo "ansible masters -i hosts -m lineinfile -a \"path=/etc/origin/master/master-config.yaml regexp='^(.*)projectRequestTemplate:(.*)' line='  projectRequestTemplate: \'default/project-request\''\""
ansible masters -i hosts -m lineinfile -a "path=/etc/origin/master/master-config.yaml regexp='^(.*)projectRequestTemplate:(.*)' line='  projectRequestTemplate: \'default/project-request\''"
ansible masters -i hosts -m service -a "name=atomic-openshift-master-api state=restarted" >/dev/null
ansible masters -i hosts -m service -a "name=atomic-openshift-master-controllers state=restarted" >/dev/null
echo "----"

echo
echo
echo "* PoC Use Case: Aggregated logging is configured and working"
echo
echo "----"
echo "oc get pods -n logging"
echo
oc get pods -n logging
echo "----"

echo
echo
echo "* PoC Use Case: Metrics collection is configured and working"
echo
echo "----"
echo "oc get pods -n openshift-infra"
echo
oc get pods -n openshift-infra
oc get pods -n openshift-metrics
echo "----"

echo
echo
echo "* PoC Use Case: Router and Registry Pods run on Infranodes"
echo
echo "----"
echo "oc get pods -n default -o wide"
echo
oc get pods -n default -o wide
echo "----"

echo
echo
echo "* PoC Use Case: Metrics and Logging components run on Infranodes"
echo
echo "----"
echo "oc get pods -n logging -o wide"
echo
oc get pods -n logging -o wide
oc get pods -n openshift-infra -o wide
oc get pods -n openshift-metrics -o wide
echo "----"

echo
echo
echo "* PoC Use Case: Service Catalog, Template Service Broker, and Ansible Service Broker are all work"
echo
echo "----"
echo "oc get pods --all-namespaces|grep 'broker\|catalog'"
echo
oc get pods --all-namespaces|grep 'broker\|catalog'
echo "----"

echo
echo "=== CICD Workflow"
echo

echo
echo
echo "* PoC Use Case: Jenkins pod is running with a persistent volume"
echo
echo "----"
echo oc new-project tasks --display-name='OpenShift Tasks'
echo oc new-app jenkins-persistent
echo
oc new-project tasks --display-name="OpenShift Tasks"
oc new-app jenkins-persistent
oc set resources dc jenkins --limits=memory=2Gi,cpu=1 --requests=memory=1Gi,cpu=500m
echo "Wait for jenkins to be deployed"
sleep 60
oc new-app eap70-basic-s2i \
--param SOURCE_REPOSITORY_REF=master \
--param CONTEXT_DIR= --param APPLICATION_NAME=tasks \
--param SOURCE_REPOSITORY_URL=https://github.com/OpenShiftDemos/openshift-tasks.git
# --param SOURCE_REPOSITORY_URL=https://github.com/wkulhanek/openshift-tasks.git
echo "Wait for JBoss to be deployed"
sleep 60
echo "----"

echo
echo
echo "* PoC Use Case: Jenkins OpenShift plugin is used to create a CICD workflow"
echo
echo "----"
cat <<EOF | oc create -n tasks -f -
kind: "BuildConfig"
apiVersion: "v1"
metadata:
  name: "openshift-tasks-pipeline"
spec:
  strategy:
    jenkinsPipelineStrategy:
      jenkinsfile: |-
        node('maven') {
            stage 'build'
            openshiftBuild(buildConfig: 'tasks', showBuildLogs: 'true')
            stage 'deploy'
            openshiftDeploy(deploymentConfig: 'tasks')
        }
    type: JenkinsPipeline
EOF
oc get buildconfig openshift-tasks-pipeline
echo "----"

echo
echo
echo "* PoC Use Case: Jenkins deploys openshift-tasks app"
echo
echo "----"
echo oc start-build openshift-tasks-pipeline
echo
oc start-build openshift-tasks-pipeline
echo "Wait pipeline to build"
sleep 60
echo "----"

echo
echo
echo "* PoC Use Case: HPA is configured and working on production deployment of openshift-tasks"
echo
echo "----"
echo oc autoscale tasks/tasks --min 1 --max 5 --cpu-percent=80
echo
oc autoscale tasks/tasks --min 1 --max 5 --cpu-percent=80
echo "----"

echo
echo "=== Multitenancy"
echo

echo
echo
echo "* PoC Use Case: Multiple Clients (customers) created"
echo
echo "----"
echo 
echo
oc whoami
oc login --username=Amy --password=$htpasswd
oc login --username=Andrew --password=$htpasswd
oc login --username=Brian --password=$htpasswd
oc login --username=Betty --password=$htpasswd
oc login --username=admin --password=$htpasswd
oc get users
echo "----"

echo
echo
echo "** PoC Use Case: Clients will be named Alpha Corp and Beta Corp (client=alpha, client=beta), and a "client=common" for unspecified customers."
echo
echo "----"
echo 
echo
echo "----"

echo
echo
echo "** PoC Use Case: Alpha Corp will have two users, Amy and Andrew"
echo
echo "----"
echo 
echo
oc label user/admin client=admin
oc label user/Amy client=alpha
oc label user/Andrew client=alpha
echo "----"

echo
echo
echo "** PoC Use Case: Beta Corp will have two users, Brian and Betty"
echo
echo "----"
echo 
echo
oc label user/Brian client=beta
oc label user/Betty client=beta
echo "----"

echo
echo
echo "* PoC Use Case: Dedicated node for each Client"
echo
echo "----"
echo 
echo
oc label node node1.${GUID}.internal client=alpha
oc label node node2.${GUID}.internal client=beta
oc label node node3.${GUID}.internal client=common
oc adm new-project "Alpha Corp" --node-selector='client=alpha'
oc adm new-project "Beta Corp" --node-selector='client=beta'
echo "----"

echo
echo
echo "* PoC Use Case: admissionControl plugin sets specific limits per label (client/customer)"
echo
echo "----"
echo 
echo
cat <<EOF | oc create -f -
admissionConfig:
  pluginConfig:
    ProjectRequestLimit:
      configuration:
        apiVersion: v1
        kind: ProjectRequestLimitConfig
        limits:
        - selector:
            client: admin 
        - selector:
            client: alpha
          maxProjects: 10
        - selector:
            client: beta
          maxProjects: 5
        - maxProjects: 2 
EOF
echo "----"

echo
echo
echo "* PoC Use Case: The new project template is modified so that it includes a LimitRange"
echo
echo "----"
echo 
echo
oc describe template/project-request -n default
echo "----"

echo
echo
echo "* PoC Use Case: The new user template is used to create a user object with the specific label value"
echo
echo "----"
echo 
echo NOP
echo "----"

echo
echo
echo "* PoC Use Case: On-boarding new client documentation explains how to create a new client/customer"
echo
echo "----"
echo 
echo NOP
echo "----"

echo
echo
echo "* PoC Use Case: "
echo
echo "----"
echo 
echo
echo "----"

echo
echo
echo "* PoC Use Case: "
echo
echo "----"
echo 
echo
echo "----"






