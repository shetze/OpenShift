# MitziCom OpenShift Instant PoC

This directiry contains a simple but powerful script to perform an OpenShift
Proof of Concept (PoC) in one go. This PoC is suited for an predefined lab
environment provided by Red Hat via OpenTLC.

As MitziCom administrator, you copy this directory to your bastion host
and start the automatic deployment by executing the deployment script as
follows:

  sh Deploy-OpenShift.sh

You will be asked a couple of questions regarding your individual environment.

In particular, you need to provide 
* the GUID of your environment
* an username and password you want to use to log into your OpenShift UI
* an LDAP password if you want to use an LDAP backend for authentication

After providing that information the deployment script will proceed unattended
and install the entire PoC environment. Then a number of OpenShift use cases is
automatically deployed and verified.


