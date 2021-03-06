---
category: security
tocprty: 1
---

# Configure Network Security and Encryption Using SAS Security Certificate Framework
## Overview
The SAS Security Certificate Framework is a collection of software applications that integrate the security requirements of your SAS applications and your Kubernetes security infrastructure.

## Requirements

cert-manager: cert-manager is an open-source application that acts as a key management system.  Optionally, SAS Viya can use cert-manager to create a root certificate authority certificate and to create server identity certificates that are issued by this CA.  The use of certificates is optional depending on which TLS mode is used.  This is described in more detail below.


* Install cert-manager Version 1.03 or later


## Installation
### Overview

Thinking of your Kubernetes cluster as a hotel provides a powerful metaphor for how Ingress security works in Kubernetes. The Kubernetes pods running in the cluster are the guest rooms.  When people use SAS Viya, they come in through the front door of the hotel and into lobby. They interact with the front desk staff, but they do not need access to the rooms inside the hotel.  A front desk staff member accepts the request to complete a task from the customer and asks them to wait. They examine the request to determine the type of work required and then take it through the service entrance behind the front desk, down the hallway to where the rooms are located, delivering it to the room designated for that type of work.

Much of this process involves private data.  The customer, or SAS Viya user, provides the private data (user IDs, passwords and other private data pertinent to the task) to the front desk staff member and entrusts them to protect the data while it is being delivered to the rooms.

All the work involved in completing the task goes on inside the rooms. In each room is a highly specialized worker that performs a single part of the task. To accomplish anything useful requires workers in multiple rooms to work together. Each worker does their part and then passes the task down the hallway to the room with the worker responsible for completing the next phase in the task. This continues until the task is complete. While the partially completed task is being shuffled up and down the hallway, the private data involved with the task travels with it.

The completed task is finally delivered to a member of the front desk staff, and this staff member delivers it to the waiting customer.

The back-end workers in a SAS Viya deployment only communicate with members of the front desk staff or with other back-end workers within the hotel.  These workers (which are really SAS Viya servers) have one room door and it faces the hallway inside the hotel. They cannot get to the public streets without going past the front desk, through the lobby and out the front door.  The network traffic flow in these connections is limited to the interior hallways of the hotel.

A few servers within the SAS Viya deployment work the front desk and accept connections from customers that reside outside the cluster.  Customers bring requests for SAS Viya tasks to be accomplished from the outside world and they take the completed task back onto the public streets. The network traffic flow involved in this communication travels through the front door of the hotel and on public streets.

### SAS Viya Security Configuration

SAS Viya supports three "modes" of TLS configuration and also offers the ability to disable security:

* "front-door" TLS
* "front-door"
* "back-end" TLS (full-stack TLS)
* "no TLS"

Almost everyone agrees that private data should be secured before it is transported on public streets, so it is typical for the front desk staff to use secure communication (TLS, https) while in the lobby, which is accessible to the public.

However, the owners of some hotels believe that it is safe to leave the network traffic within the hallways unsecured.  This is reasonable if the hotels have very tight lobby and perimeter security, the entire hotel staff is carefully screened for security clearance, and the hotel perimeter is under constant surveillance. In these hotels, network traffic that is contained entirely within the hotel's safe perimeter can be left unencrypted, and the entire hotel staff can be trusted with the sensitive data.  Only the traffic that travels through the front door onto public streets needs to be encrypted. For this case, you can configure SAS Viya to encrypt only network traffic that will travel outside the hotel's front door. Therefore, we refer to this type of TLS configuration as "front-door TLS".

In other hotels where the public is free to pass through the lobby and access the hallways, all traffic, whether interior to the hotel or outside of it, needs to be encrypted.  Therefore, we refer to these types of TLS configuration as "front-door and back-end TLS" or "full-stack TLS".

In some public cloud platforms, the hotel staff itself secures the data prior to carrying it down the hallway so there may be no need for the SAS Viya workers in the rooms to perform these same security duties.

The "front desk" servers that are intended to accept connections from outside the cluster include:

*The NGINX Ingress controller, which routes traffic to all web applications such as SAS Drive and SASStudio
*SAS Cloud Analytic Services (the CAS server)
*SAS/CONNECT

Think of SAS Viya as a hotel with three front desks in the lobby: NGINX, CAS, and SAS/CONNECT.   All three front desks have access to the same interior rooms (the back-end services).

### Trust

Customers are required to provide private data to the front desk staff.  They provide their user IDs, passwords and other private data which is necessary to conduct business with the back-end services. As a result, they should require assurance that the front desk is trustworthy.  TLS provides the mechanism for assuring trust between customers and front desk workers.

A brief explanation of trust:

1.The customer has in their possession a list of hotel companies which are judged by an independent organization to be trustworthy.
2.The customer asks to see the front desk worker's identification
3.The customer validates that the name on the credential matches the worker's nametag
4.The customer verifies that the issuer of the credential is in the list of hotels that are judged to be trustworthy

More specifically:

1.The client, in this case, a web browser or other application that is being used by a SAS Viya user to access SAS Viya, possess a bundle of certificate authorities judged to be trustworthy.  The independent body that does the judging is https://www.mozilla.org
2.The client requests the server's identity certificate
3.The client validates that the identity of the server matches the identity specified by the certificate.
4.The client deduces the certificate authority (CA) that issued the server's identity certificate
5.The client verifies that the CA is in their bundle of trusted CAs

If you configure SAS Viya to secure network traffic using either the back-end or full-stack TLS mode, clients and servers should be required to verify the trustworthiness of the certificates used to secure the SAS Viya front-desk servers.  You can configure those front-desk servers to use your own certificates which are already deemed trustworthy by your organization's infrastructure.  Or you can also configure SAS Viya to auto-generate its own front-desk server certificates.  In the latter case, you should configure your infrastructure to trust the SAS Viya-generated CA certificates.

If you use full-stack TLS mode, where SAS Viya secures network connections between the back-end servers in the hotel rooms, these connections are configured to use certificates auto-generated by the SAS Viya deployment and the back-end servers are configured to trust those SAS Viya generated certificates.

### Kustomize Configuration

Customizations are provided that enable you to configure TLS for network communication involving your SAS Viya applications.  They allow you to incorporate information that is specific to your environment, such as hostnames, paths to configuration files and certificates to the SAS Viya deployment.

These instructions assume that you created a $deploy/site-config directory as suggested in [SAS Viya Deployment Guide](http://documentation.sas.com/?softwareId=mysas&softwareVersion=prod&docsetId=dplyml0phy0dkr&docsetTarget=titlepage.htm). We further suggest that you create sub-directories under site-config for the different categories of files that are required.

The following is a conceptual directory structure that illustrates the different types of files that will be used during your deployment.  Depending on your chosen TLS mode and other site specific settings, some of these directories will not be required.  The complete set is provided here for illustrative purposes.  The required set of directories will become apparent as you read through these instructions.

```text
   $deploy/
   ├── site-config/
   │   └── security/
   │      ├── cacerts/
   │      │   ├── my_CA_Certs.pem (optional file(s) containing a set of CA certificates)
   │      │   └── my_other CA_certs.pem (multiple CA certificate files are allowed)
   │      ├── my_ingress_cert.crt
   │      ├── my_ingress_cert.key
   │      ├── customer-provided-ca-certificates.yaml
   │      ├── customer-provided-ingress-certificate.yaml
   │      └── cert-manager-provided-ingress-certificate.yaml
   ├── kustomization.yaml
   ├── sas-bases
   │      ├── base
   │      ├── examples
   │      ├── overlays
   │      └── more files and directories
   └── more files and directories
```

## TLS for SAS Viya Applications
### Cert-Manager configuration

As noted above, cert-manager is required and must be configured prior to deploying SAS Viya.

The SAS Viya deployment process includes resources that create a root CA certificate and store it in a Kubernetes Secret named sas-viya-ca-certificate-secret.  This root CA certificate is unique and is generated at the time of your deployment. The deployment process also creates a second cert-manager certificate issuer which is used to creates server identity certificates that are signed by the root CA certificate.  All of the certificates referenced in the following instructions are created using this cert-manager issuer.

### NGINX TLS (used in both front-door and full-stack TLS modes)

#### Certificates for the NGINX Controller

The NGINX controller is a front-door server: it accepts connections that originate outside the cluster.  TLS connections are secured by the NGINX process using a certificate and key.

You can secure NGINX with your own certificate and key files (likely because you obtained them from your organization's IT department) or the certificate and key can be auto-generated by cert-manager.  Depending on the source of cert/key files, the configuration steps are different.

Choose one of the two methods based on the source of your NGINX cert/key files, then follow the steps in the corresponding section (below) to include the appropriate transformer. Include only one of these two transformers in your kustomization.yaml

* customer-provided-ingress-certificate.yaml

or

* cert-manager-provided-ingress-certificate.yaml

If you include both of these files in your kustomization.yaml, errors will result.

##### NGINX Ingress Certificate and Key Files Are Provided by the Customer

Use this method if you have your own server identity certificate and key that you want to use to secure NGINX.  This is desirable if you have "site signed certificates", that is, certificates with a root CA that is already widely distributed throughout your site.

The server identity certificate must be configured with the appropriate SAN DNS attributes such that the DNS alias (host name) of the Ingress controller can be validated by all connecting clients. This means that the there must be a SAN DNS entry for any possible DNS hostname alias that you might use to reach the Ingress host.  Potential client applications include SAS CLI applications that you run on hosts outside the cluster and also some servers that are running inside the cluster. You must include the value specified for the INGRESS_HOST literal in your kustomization.yaml file as a SAN DNS entry in your certificate.

SAS requires that the all certificates in chain of trust including:

* the server identity certificate
* all intermediate CA certificates
* the root CA certificate

be included in the server certificate file that you provided to the deployment. While the root CA certificate is not strictly required, it is recommended that you include it for convenience.  The certificates should be included in order of issuance, the first one being the server identity certificate, followed by its issuer. If the issuer is an intermediate, then it should be followed by the corresponding issuer.  This should continue up to and including the root CA certificate.

Your certificate(s) and private key must be stored in a Kubernetes secret.  An annotated example of the code to create this secret is provided in the following customization file: sas-bases/examples/security/customer-provided-ingress-certificate.yaml.
Copy the example file to your site-config directory and make edits as described in the comments.

```text
cd $deploy
cp examples/security/customer-provided-ingress-certificate.yaml site-config/security
vi site-config/security/customer-provided-ingress-certificate.yaml
```

Once your edits are in place, add the path to this file to the generators block of your $deploy/kustomization.yaml file.

```yaml
generators:
- site-config/security/customer-provided-ingress-certificate.yaml # configures Ingress to use a secret which contains customer-provided certificate and key
```

If you are using your own NGINX Ingress certificate as described above rather than having SAS Viya deployment auto-generate the certificate, you must follow the instructions in the section '''Incorporating Additional CA Certificates into the SAS Viya Deployment''' to include the corresponding root CA certificate in the list of trusted CA certificates in the deployment.

##### NGINX Ingress Certificates Auto-Generated by cert-manager

If you do not have certificates to use for the NGINX Ingress controller, SAS can generate them using cert-manager. All SAS Viya servers are automatically configured to trust the issuing CA certificate used by cert-manager.

Follow these instructions to use cert-manager to generate the certificate and key used by the NGINX Ingress controller.

First you have to configure which cert-manager issuer should be used to generate the NGINX ingress certificates.  An annotated example of the code is provided in the following customization file: sas-bases/examples/security/cert-manager-provided-ingress-certificate.yaml.   Copy the example to your site-config directory and make edits as described in the comments.

```text
cd $deploy
cp examples/security/cert-manager-provided-ingress-certificate.yaml site-config/security
vi site-config/security/cert-manager-provided-ingress-certificate.yaml
```
Once your edits are in place, add the path to this file to the to the transformers block of your base kustomization.yaml file:

```yaml
transformers:
- site-config/security/cert-manager-provided-ingress-certificate.yaml # causes cert-manager to generate Ingress certificate and key and store it in secret
```

#### Resources and Transformers to Enable TLS

In addition to the file that specifies the source of certificates, you should add these resources and transformers to the base kustomization.yaml file as follows:

```yaml
resources:
- sas-bases/overlays/cert-manager-issuer
- sas-bases/overlays/network/ingress/security # configure Ingress to use TLS
```

**IMPORTANT:** These lines must come before the line that lists the required transformers, that is, "- sas-bases/overlays/required/transformers.yaml"

```yaml
transformers:
- sas-bases/overlays/network/ingress/security/transformers/ingress-tls-transformers.yaml # configure Ingress to use TLS
```

### Enable TLS for SAS Front-Door Servers: CAS and SAS/CONNECT

**Note:** NGINX TLS is a prerequisite.

CAS and SAS/CONNECT are front-door servers because they accept connections from outside the cluster and handle network traffic that travels outside the perimeter of the cluster. To configure SAS Viya for front-door TLS mode, add these transformers to your kustomization.yaml.  They configure CAS and SAS/CONNECT to encrypt network traffic.

**IMPORTANT:**

* Do not add the cas-connect-tls-transformers.yaml if you intend to enable full-stack TLS mode because it is already included in the product-tls-transformers.yaml used for Full-stack TLS (see below).
* The cas-connect-tls-transformers.yaml line must come before the line that lists the required transformers, that is, - sas-bases/overlays/required/transformers.yaml"`

```yaml
transformers:
- sas-bases/overlays/network/ingress/security/transformers/cas-connect-tls-transformers.yaml # transformers to build trust stores for all services and enable backend TLS for CAS.
- sas-bases/overlays/required/transformers.yaml # This line is provided as a location reference, it should appear only once and not be duplicated.
```

### Full-Stack TLS Mode

**Note:** NGINX TLS is a prerequisite.

To encrypt network traffic within the cluster, all SAS Viya servers must be configured to use TLS for all network connections.  Since NGINX decrypts incoming network traffic, if the back-end servers require TLS, NGINX must re-encrypt traffic before forwarding it to the "back-end" SAS applications and SAS servers must use TLS when communicating directly with one another.  The SAS Viya servers use cert-manager certificates to secure their network traffic with NGINX and other SAS Viya servers.  While this increases latency and increases CPU utilization, unless you do this, network traffic within your cluster will not be encrypted. To configure all servers to use TLS, include these resources in the `transformers:` section of your kustomization.yaml file.

**IMPORTANT:** These lines must come before the line that lists the required transformers, ("- sas-bases/overlays/required/transformers.yaml").

Include these customizations in the transformers block of the base kustomization.yaml file:

```yaml
transformers:
- sas-bases/overlays/network/ingress/security/transformers/product-tls-transformers.yaml # adds the tls enablement data bits to selected product DUs
- sas-bases/overlays/network/ingress/security/transformers/backend-tls-transformers.yaml # transformers to support TLS for backend servers
- sas-bases/overlays/required/transformers.yaml # This line is provided as a location reference, so it should appear only once and not be duplicated.
```

### Configuration of Server Certificate Attributes

If you have DNS aliases or IP addresses that need to be added to SAN DNS or SAN IP entries in the server identity certificates that are created by cert-manager and used in your SAS Viya deployment, the configuration settings that control the attributes are stored in the Kubernetes configmap named "sas-certframe-user-config".  To alter the default settings, please see the comments in the provided example file:  $deploy/examples/security/customer-provided-merge-sas-certframe-configmap.yaml

To add alter any of the default values follow these instructions:

Copy the example file to your site-config directory and make edits as described in the comments.

```text
cd $deploy
cp examples/security/customer-provided-merge-sas-certframe-configmap.yaml site-config/security/
vi site-config/security/customer-provided-merge-sas-certframe-configmap.yaml
```

Once your edits are in place, add the path to the file to the generators block of your `$deploy/kustomization.yaml` file. Here is an example:

```yaml
generators:
- site-config/security/customer-provided-merge-sas-certframe-configmap.yaml # merges customer provided configuration settings into the sas-certframe-user-config configmap
```

## CA Certificates

### Incorporating Additional CA Certificates into the SAS Viya Deployment

One of the reasons for using TLS is to eliminate the possibility that you are communicating with an imposter, such as a rogue server that is impersonating your intended destination address by posing as that host name.  In order to prevent this, the TLS handshake requires that the remote server present a certificate that identifies it as having the same hostname as was specified in the TLS connection request.
In order for this validation to be meaningful, you need to know whether the presented certificate is trustworthy.  Determining whether a certificate authority is trustworthy is quite simple.  A list of every trusted certificate authority is delivered with SAS Viya.  Each entry in this file comes in the form of a root CA certificate, which identifies the trustworthy certificate authority.  The file that contains this list of trusted certificate authority certificates is called a bundle of trusted CA certs, or trust bundle.

SAS Viya is configured to include all CA certificates that are distributed by mozilla.org in the trust bundle file. For more information, see [Additional Resources](#additional-resources). These are sometimes referenced as "public" CA certificates. SAS Viya servers will be able to connect to any web sites and services that are protected by these public CA certificates because SAS Viya is automatically configured to use them.

You might want to configure SAS Viya to securely communicate with web resources that are protected by CA certificates not included in this public trust bundle.  For example, your organization might have its own CA certificates that are used to protect private web resources such as your LDAP server, internal corporate web servers, or other resources.

If you want to use SAS Viya to connect to these private web resources, SAS Viya must be configured to trust them.  Enabling trust means that they must be added to the bundle of trusted CA certificates that are used by SAS.  In order to add them, provide all the trusted CA certificates (the root certificate and all corresponding intermediate CA certificates) to the SAS Viya software.

Follow these steps to provide CA certificates to the SAS Viya deployment. The certificate files must be in PEM format, and the path to the files should be relative to the directory that contains the kustomization.yaml file.

Since you may have to maintain several files containing CA certificates and these will need to be updated over time, it may be convenient to create a separate directory for these files as illustrated in the directory structure example above.

Place your CA certificate files in the `site-config/security/cacerts directory`. Ensure that the userid that will run the kustomize command has read access to the files.

Copy the file `$deploy/examples/security/customer-provided-ca-certificates.yaml` into your `$deploy/site-config/security directory`.

Edit the `site-config/security/customer-provided-ca-certificates.yaml` file and enter the required information.  Instructions for editing this file are provided as comments in the file.

Here is an example:

```text
export deploy=~/deploy
cd $deploy
mkdir -p site-config/security/cacerts
#
# the following line assumes that your CA Certificates are in a file named /tmp/my_ca_certificates.pem
#
cp /tmp/my_ca_certificates.pem site-config/security/cacerts
cp examples/security/customer-provided-ca-certificates.yaml site-config/security
vi site-config/security/customer-provided-ca-certificates.yaml
```

Once your edits are in place, add the path to this file to the generators block of your `$deploy/kustomization.yaml` file. Here is an example:

```yaml
generators:
- site-config/security/customer-provided-ca-certificates.yaml # generates a configmap that contains CA Certificates
```

#### Incorporating Additional CA Certificates into the SAS Viya Deployment when "Front-door TLS" or "Full-stack TLS" modes are used

All additional CA certificates provided are automatically included in the pods' trust bundles when "Front-door TLS" or "Full-stack TLS" modes are used.

#### Incorporating Additional CA Certificates into the SAS Viya Deployment when "No TLS" Mode Is Used

In order to add additional CA certificates to pod trust bundles ensure that this overlay is in the resources block of your `$deploy/kustomization.yaml` file:

```yaml
resources:
- sas-bases/overlays/network/ingress/security #  include customer-provided CA certificates in trust bundles
```

Additionally, add this transformer to the transformers block of your base kustomization.yaml file. It must come before the line that lists the required transformers.

**IMPORTANT:** Do not add this transformer if you have configured front-door TLS or full-stack TLS mode.

```yaml
transformers:
- sas-bases/overlays/network/ingress/security/transformers/truststore-transformers-without-backend-tls.yaml # transformers to build trust stores when no backend tls is desired
- sas-bases/overlays/required/transformers.yaml # This line is provided as a location reference, so it should appear only once and not be duplicated.
```

### Extracting the SAS Viya generated root CA Certificate from a Deployment

If you make use of cert-manager generated certificates to protect SAS Viya servers and services, the SAS Viya deployment process creates a Kubernetes secret named "sas-viya-ca-certificate-secret" that contains the root CA certificate used to issue the necessary server identity certificates.  This happens when you

* Use full-stack TLS mode
* Use front-door TLS mode and choose to configure the NGINX Ingresses to use a cert-manager certificate

In these configured modes, the cert-manager root CA certificate will need to be added to the bundle of trusted root CA certificates used by any external clients that will access the SAS Viya deployment.  These clients include:

*Web browsers
*SAS Viya Administrative CLI applications
*Remote SAS sessions that connect to Viya
*curl

The following command can be used to extract the CA certificate from the secret.  You will need to run this with an Kubernetes identity that has roles which allow it to access secrets.

```text
#command to get the secret
kubectl get secret sas-viya-ca-certificate-secret -o go-template='{{(index .data "ca.crt")}}'
```

Because Kubernetes stores secrets in base64 encoding, you must decode the certificate before it can be used.

```text
#command to get the secret, decode it into PEM format and write it to a file
kubectl get secret sas-viya-ca-certificate-secret -o go-template='{{(index .data "ca.crt")}}' | base64 -d > /tmp/my_ca_certificate.pem
```

## Istio Ingress

SAS Viya does not support Istio Ingress with mTLS enabled.  For secure network communications, you must use NGINX Ingress.

## Example kustomization.yaml Files

```yaml
#Full-stack TLS with customer-provided Ingress certificates
namespace: fullstacktls
resources:
- sas-bases/base
- sas-bases/overlays/cert-manager-issuer
- sas-bases/overlays/network/ingress
- sas-bases/overlays/network/ingress/security

transformers:
- sas-bases/overlays/network/ingress/security/transformers/product-tls-transformers.yaml
- sas-bases/overlays/network/ingress/security/transformers/ingress-tls-transformers.yaml
- sas-bases/overlays/network/ingress/security/transformers/backend-tls-transformers.yaml
- sas-bases/overlays/required/transformers.yaml

generators:
- site-config/security/customer-provided-ingress-certificate.yaml
- site-config/security/customer-provided-ca-certificates.yaml
```


```yaml
#Front-door TLS with auto-generated cert-manager provided Ingress certificates
namespace: frontdoortls
resources:
- sas-bases/base
- sas-bases/overlays/cert-manager-issuer
- sas-bases/overlays/network/ingress
- sas-bases/overlays/network/ingress/security

transformers:
- sas-bases/overlays/network/ingress/security/transformers/ingress-tls-transformers.yaml
- sas-bases/overlays/network/ingress/security/transformers/cas-connect-tls-transformers.yaml
- sas-bases/overlays/required/transformers.yaml

generators:
- site-config/security/customer-provided-ca-certificates.yaml # This generator is optional.  Include it only if you need to add additional CA Certificates
```


```yaml
#Front-door TLS with customer-provided Ingress certificates
namespace: frontdoortls
resources:
- sas-bases/base
- sas-bases/overlays/cert-manager-issuer
- sas-bases/overlays/network/ingress
- sas-bases/overlays/network/ingress/security

transformers:
- sas-bases/overlays/network/ingress/security/transformers/ingress-tls-transformers.yaml
- sas-bases/overlays/network/ingress/security/transformers/cas-connect-tls-transformers.yaml
- sas-bases/overlays/required/transformers.yaml

generators:
- site-config/security/customer-provided-ingress-certificate.yaml
- site-config/security/customer-provided-ca-certificates.yaml
```


## Additional Resources

*https://cert-manager.io/
*http://documentation.sas.com/?cdcId=itopscdc&cdcVersion=default&docsetId=dplyml0phy0dkr&docsetTarget=titlepage.htm
