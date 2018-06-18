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
openshift_master_cluster_public_hostname=loadbalancer.${GUID}.example.opentlc.com
openshift_master_default_subdomain=apps.${GUID}.example.opentlc.com 
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
openshift_master_identity_providers=[{'name': 'ldap', 'challenge': 'true', 'login': 'true', 'kind': 'LDAPPasswordIdentityProvider','attributes': {'id': ['dn'], 'email': ['mail'], 'name': ['cn'], 'preferredUsername': ['uid']}, 'bindDN': 'uid=admin,cn=users,cn=accounts,dc=shared,dc=example,dc=opentlc,dc=com', 'bindPassword': '${ldappasswd}', 'ca': '/etc/origin/master/ipa-ca.crt','insecure': 'false', 'url': 'ldaps://ipa.shared.example.opentlc.com:636/cn=users,cn=accounts,dc=shared,dc=example,dc=opentlc,dc=com?uid?sub?(memberOf=cn=ocp-users,cn=groups,cn=accounts,dc=shared,dc=example,dc=opentlc,dc=com)'}]
openshift_master_ldap_ca_file=$(pwd)/ipa-ca.crt
EOF
wget http://ipa.shared.example.opentlc.com/ipa/config/ca.crt -O ipa-ca.crt
fi

if [ -n "$htuser" -a -n $ldappasswd ]; then 
cat >> hosts <<EOF
openshift_master_identity_providers=[{'name': 'htpasswd_auth', 'login': 'true', 'challenge': 'true', 'kind': 'HTPasswdPasswordIdentityProvider', 'filename': '/etc/origin/master/htpasswd'},{'name': 'ldap', 'challenge': 'true', 'login': 'true', 'kind': 'LDAPPasswordIdentityProvider','attributes': {'id': ['dn'], 'email': ['mail'], 'name': ['cn'], 'preferredUsername': ['uid']}, 'bindDN': 'uid=admin,cn=users,cn=accounts,dc=shared,dc=example,dc=opentlc,dc=com', 'bindPassword': '${ldappasswd}', 'ca': '/etc/origin/master/ipa-ca.crt','insecure': 'false', 'url': 'ldaps://ipa.shared.example.opentlc.com:636/cn=users,cn=accounts,dc=shared,dc=example,dc=opentlc,dc=com?uid?sub?(memberOf=cn=ocp-users,cn=groups,cn=accounts,dc=shared,dc=example,dc=opentlc,dc=com)'}]
openshift_master_ldap_ca_file=$(pwd)/ipa-ca.crt
openshift_master_htpasswd_file=$(pwd)/htpasswd.openshift
EOF
wget http://ipa.shared.example.opentlc.com/ipa/config/ca.crt -O ipa-ca.crt
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

if [ "$answer" -ne "Y" ]; then
  echo "Thank you for trying the OpenShift PoC Deployment Script."
  echo "Keeping the Workdir for further investigation, please delete manually if you are done."
  exit 0
fi

ansible nfs -m shell -a 'for i in {001..050}; do mkdir /srv/nfs/pv$i; chown nfsnobody:nfsnobody /srv/nfs/pv$i; chmod 777 /srv/nfs/pv$i; done'

ansible-playbook -i ./hosts -f 20  /usr/share/ansible/openshift-ansible/playbooks/prerequisites.yml
ansible-playbook -i ./hosts -f 20 /usr/share/ansible/openshift-ansible/playbooks/deploy_cluster.yml

ansible masters[0] -b -m fetch -a "src=/root/.kube/config dest=/root/.kube/config flat=yes"

# Ability to authenticate at the master console
if [ -n "$htuser" ]; then 
  oc adm policy add-cluster-role-to-user cluster-admin $htuser
  oc adm policy add-cluster-role-to-user cluster-admin Karla
fi
if [ -n "$ldappasswd" ]; then 
cat << EOF > groupsync.yaml
kind: LDAPSyncConfig
apiVersion: v1
url: "ldap://ipa.shared.example.opentlc.com"
insecure: false
ca: "/etc/origin/master/ipa-ca.crt"
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
oc adm groups sync --sync-config=$(pwd)/groupsync.yaml --whitelist=$(pwd)/whitelist.yaml --confirm
oc adm policy add-cluster-role-to-group cluster-admin ocp-platform
fi

# Registry has storage attached and working
registry-pod=$(oc get pods -n default|grep docker-registry|cut -d' ' -f1)
oc info pod/${registry-pod} -n default


# Router is configured on each infranode
oc get pods -o wide -n default |grep router

# PVs of different types are available for users to consume
size=5Gi
mode=ReadWriteOnce
policy=Recycle
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
    path: /srv/nfs/pv${i}
    server: support1.${GUID}.internal
  persistentVolumeReclaimPolicy: $policy
EOF
done
oc get pv|grep Available

# Ability to deploy a simple app (nodejs-mongo-persistent)
oc new-project smoke-test
oc new-app nodejs-mongo-persistent
oc get pod
oc get route


# There are three masters working
oc get nodes|grep master


# There are three etcd instances working
ansible masters[0] -m shell -a '/usr/bin/etcdctl --cert-file /etc/etcd/peer.crt --key-file /etc/etcd/peer.key --ca-file /etc/etcd/ca.crt -C https://`hostname`:2379 cluster-health'

# There is a load balancer to access the masters called loadbalancer.$GUID.$DOMAIN
curl http://loadbalancer.$GUID.example.opentlc.com:9000/

# There is a load balancer/DNS for both infranodes called *.apps.$GUID.$DOMAIN

# There are at least two infranodes, labeled env=infra
oc get nodes -l env=infra





