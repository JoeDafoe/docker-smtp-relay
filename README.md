Docker SMTP Relay
A lightweight Postfix SMTP relay running in Docker and based on Alpine Linux.

The image provides a configurable SMTP relay for applications, servers, Microsoft Exchange environments, monitoring systems, and other SMTP clients that need to forward email through an upstream mail relay.

Clients can be authorized by:

Trusted networks (RELAY_MYNETWORKS)
SASL username/password authentication
Optional Dynamic DNS based client IP filtering
A combination of IP filtering and SASL authentication
Messages forwarded to an upstream SMTP relay can be protected using TLS.

Security: Do not expose an unrestricted SMTP relay to the Internet.
For Internet-facing deployments, SASL authentication, restrictive client access rules, and TLS are strongly recommended.

Important: Review CHANGELOG.md before upgrading because new releases may introduce configuration changes.

Features
Postfix SMTP relay
Alpine Linux based image
IPv4 support
Cyrus SASL authentication
Persistent SASL user database
Persistent Postfix mail queue
Sender-domain restrictions
Multiple predefined relay modes
Upstream SMTP smart-host support
TLS support for upstream SMTP connections
Generic Postfix configuration through POSTCONF_*
Docker health check
Supervisor based process management
Optional external script support
Dynamic DNS client IP allowlisting
Automatic Postfix reload after Dynamic DNS IP changes
Persistent last-known Dynamic DNS client IP
Supported Image
Docker image:

joedafoe/docker-smtp-relay:latest
Source:

GitHub Repository

Dockerfile

Current base image:

Alpine 3.24.4
Architecture
Typical deployment:

SMTP Client / Exchange
          |
          | SMTP
          | optional SASL authentication
          |
          v
+-------------------------------+
| Docker SMTP Relay             |
|                               |
| Postfix                       |
| Cyrus SASL                    |
| Dynamic Client IP Filtering   |
| Supervisor                    |
+-------------------------------+
          |
          | SMTP
          | TLS optional/required
          |
          v
   Upstream SMTP Relay
Example with Docker port mapping:

Exchange
   |
   | TCP/587
   v
Docker Host :587
   |
   | Docker NAT
   v
Container :25
   |
   | STARTTLS
   v
Upstream SMTP Relay :25
Postfix itself continues to listen on TCP/25 inside the container. Docker can publish this as another port such as TCP/587.

Docker Information
Port
Port	Usage
25/tcp	Incoming SMTP relay connections
Example:

-p 587:25
Clients connect to:

relay.example.net:587
while Postfix listens on:

container:25
Persistent Volumes
Volume	Usage
/data	Persistent SASL database and Dynamic DNS CIDR map
/var/spool/postfix	Persistent Postfix mail queue
/external-scripts	Optional externally managed scripts, normally mounted read-only
Example:

-v /DockerConfigs/mailrelay/data:/data
-v /DockerConfigs/mailrelay/postfix:/var/spool/postfix
-v /DockerConfigs/mailrelay/scripts:/external-scripts:ro
Environment Variables
Basic Configuration
Environment	Type	Description
RELAY_MYHOSTNAME	String	Hostname presented by the SMTP relay
RELAY_MYDOMAIN	String	Primary mail domain
RELAY_MYNETWORKS	List	Networks trusted by Postfix
RELAY_DOMAINS	List	Domains handled by the relay
RELAY_HOST	String	Upstream SMTP smart host
RELAY_POSTMASTER	Email	Address receiving Postfix error notifications
RELAY_MODE	Enum	Relay authorization mode
RELAY_STRICT_SENDER_MYDOMAIN	Boolean	Restrict envelope sender addresses to RELAY_MYDOMAIN
RELAY_LOGIN	String	Optional username for authentication against the upstream relay
RELAY_PASSWORD	String	Optional password for authentication against the upstream relay
RELAY_USE_TLS	Boolean	Enable TLS support for the upstream relay
RELAY_TLS_VERIFY	Enum	TLS security level
RELAY_TLS_CA	Path	CA bundle used for TLS validation
RELAY_EXTRAS_SETTINGS	String	Deprecated. Additional settings passed to postconf -e
POSTCONF_[setting]	Mixed	Set arbitrary Postfix configuration parameters
Default trusted network:

127.0.0.0/8
For Internet-facing deployments it is strongly recommended not to use:

0.0.0.0/0
as a general trusted network.

Generic Postfix Configuration with POSTCONF_
Postfix settings can be supplied directly using environment variables prefixed with:

POSTCONF_
For example:

-e "POSTCONF_compatibility_level=3.6"
results in:

compatibility_level = 3.6
Another example:

-e "POSTCONF_smtp_tls_security_level=encrypt"
results in:

smtp_tls_security_level = encrypt
The effective configuration can be inspected with:

docker exec smtp-relay postconf -n
or for a specific setting:

docker exec smtp-relay postconf smtp_tls_security_level
Relay Modes
STRICT
RELAY_MODE=STRICT
Only network-authorized or SASL-authenticated clients are allowed to use the relay.

Recipients are restricted to the configured relay domains.

ALLOW_SASLAUTH_NODOMAIN
RELAY_MODE=ALLOW_SASLAUTH_NODOMAIN
SASL-authenticated clients can relay messages to arbitrary recipient domains.

Network-authorized clients remain subject to the configured relay-domain restrictions.

This mode is useful when an authenticated server such as Microsoft Exchange needs to send mail to external users.

ALLOW_NETAUTH_NODOMAIN
RELAY_MODE=ALLOW_NETAUTH_NODOMAIN
Network-authorized clients can relay to arbitrary recipient domains.

SASL-authenticated clients remain subject to relay-domain restrictions.

ALLOW_AUTH_NODOMAIN
RELAY_MODE=ALLOW_AUTH_NODOMAIN
Network-authorized and SASL-authenticated clients can relay to arbitrary recipient domains.

Use this mode carefully on Internet-facing systems.

SASL Authentication
Incoming SMTP clients can authenticate using Cyrus SASL.

The SASL database is stored persistently under:

/data/sasldb2
The image currently supports:

PLAIN
LOGIN
CRAM-MD5
DIGEST-MD5
For Internet-facing deployments, PLAIN and LOGIN should only be used together with TLS.

List SASL Users
docker exec smtp-relay /opt/listpasswd.sh
Add a SASL User
docker exec -it smtp-relay \
  /opt/saslpasswd.sh \
  -u domain.com \
  -c username
The password is requested interactively.

Add Multiple SASL Users
A credentials file can be mounted to:

/etc/postfix/client_sasl_passwd
with one account per line:

username1 password1
username2 password2
The accounts are registered during container startup.

Check the Docker logs to verify that all users have been processed successfully.

Authentication Against the Upstream SMTP Relay
If the upstream SMTP relay requires authentication:

-e "RELAY_LOGIN=username"
-e "RELAY_PASSWORD=password"
Alternatively, credentials can be mounted using:

/etc/postfix/sasl_passwd
Example:

[relay.example.net]:25 username:password
Mount:

-v /local/path/sasl_passwd:/etc/postfix/sasl_passwd:ro
TLS to the Upstream SMTP Relay
Postfix can encrypt SMTP connections from the container to the upstream relay.

For a trusted upstream smart host where TLS should be mandatory:

-e "POSTCONF_smtp_tls_security_level=encrypt"
This results in:

smtp_tls_security_level = encrypt
With encrypt, Postfix requires TLS before delivering the message to the upstream SMTP server.

If the upstream server does not provide STARTTLS, the message is not sent in clear text.

Useful TLS security levels include:

none
may
encrypt
dane
dane-only
fingerprint
verify
secure
Check the active setting:

docker exec smtp-relay \
  postconf smtp_tls_security_level
A successful TLS protected delivery is visible in the Postfix logs:

tls=encrypt
dsn=2.0.0
status=sent
Dynamic DNS Client Allowlisting
The image supports optional Dynamic DNS based SMTP client filtering.

This is useful when an SMTP client, such as a Microsoft Exchange server, connects through the Internet but has a dynamically assigned public IPv4 address.

Example:

Microsoft Exchange
Dynamic Public IP
       |
       |
       | Dynamic DNS
       v
mail.example.net
       |
       | A record lookup
       v
203.0.113.10
       |
       v
SMTP Relay
Instead of trusting all IPv4 clients with:

RELAY_MYNETWORKS=0.0.0.0/0
the current address of an authorized client can be resolved from DNS and written to a Postfix CIDR access map.

Recommended Dynamic Client Security Model
The Dynamic DNS filter is intended as an additional security layer.

Recommended:

Dynamic DNS IP match
        +
SASL authentication
        +
TLS
Example:

mail.example.net
       |
       | DNS lookup
       v
203.0.113.10
       |
       v
203.0.113.10/32 OK
       |
       v
SASL authentication
       |
       v
Postfix relay
Other IPv4 addresses can be rejected:

0.0.0.0/0 REJECT Client IP is not authorized
Dynamic DNS based filtering does not replace SASL authentication.

External Script Support
External relay extensions can be mounted under:

/external-scripts
and enabled using:

RELAY_EXTERNAL_SCRIPT
Example:

-v /local/scripts:/external-scripts:ro
-e "RELAY_EXTERNAL_SCRIPT=/external-scripts/dynamic-client.sh"
The script remains outside the Docker image.

This makes it possible to modify or replace the updater script without rebuilding the image.

When RELAY_EXTERNAL_SCRIPT is not defined, the external script functionality is disabled and normal relay operation continues without Dynamic DNS client filtering.

External Script Interface
The configured external script must support two modes:

--init
--loop
--init
Called once during container startup.

It must create the initial client access map before normal operation starts.

Example:

/external-scripts/dynamic-client.sh --init
--loop
Started by Supervisor after initialization.

Example:

/external-scripts/dynamic-client.sh --loop
The loop periodically checks DNS and updates the client map when required.

Dynamic DNS Environment Variables
Variable	Default	Description
RELAY_EXTERNAL_SCRIPT	empty	Path to the optional external updater
RELAY_DYNAMIC_CLIENT	empty	DNS hostname representing the authorized SMTP client
RELAY_DYNAMIC_CLIENT_INTERVAL	60	DNS check interval in seconds
RELAY_DYNAMIC_CLIENT_MAP	/data/dynamic-client.cidr	Persistent Postfix CIDR map
Example:

-e "RELAY_EXTERNAL_SCRIPT=/external-scripts/dynamic-client.sh"
-e "RELAY_DYNAMIC_CLIENT=mail.example.net"
-e "RELAY_DYNAMIC_CLIENT_INTERVAL=60"
-e "RELAY_DYNAMIC_CLIENT_MAP=/data/dynamic-client.cidr"
Dynamic DNS CIDR Map
The generated CIDR map is stored persistently.

Default:

/data/dynamic-client.cidr
Example:

# Automatically generated. Do not edit.
# Source: mail.example.net
# Updated: 2026-11-14T10:23:29Z
203.0.113.10/32 OK
0.0.0.0/0 REJECT Client IP is not authorized
Postfix uses the map through:

smtpd_client_restrictions =
    check_client_access cidr:/data/dynamic-client.cidr
Verify the active configuration:

docker exec smtp-relay \
  postconf smtpd_client_restrictions
Expected:

smtpd_client_restrictions = check_client_access cidr:/data/dynamic-client.cidr
Postfix CIDR tables evaluate network patterns in order and use the result associated with the first matching pattern.

Dynamic DNS Update Behavior
The updater periodically resolves:

RELAY_DYNAMIC_CLIENT
For example:

mail.example.net
IP has not changed
DNS lookup
   |
same IPv4
   |
no configuration change
No unnecessary Postfix reload is performed.

IP has changed
DNS lookup
   |
new IPv4
   |
update dynamic-client.cidr
   |
postfix check
   |
postfix reload
The new address becomes active automatically.

DNS lookup fails
If an existing CIDR map is available, it is retained.

DNS failure
   |
   v
keep previous CIDR map
The previous client address is therefore not removed simply because of a temporary DNS outage.

Supervisor Integration
The external updater is managed by Supervisor.

Its generated configuration is stored under:

/etc/supervisor.d/
The main Supervisor configuration loads dynamic definitions using:

[include]
files = /etc/supervisor.d/*.ini
When the Dynamic DNS functionality is enabled, the container creates a program similar to:

[program:external-relay-script]
command=/external-scripts/dynamic-client.sh --loop
priority=20
autostart=true
autorestart=true
startsecs=2
startretries=5
stopsignal=TERM
stopwaitsecs=10
redirect_stderr=true
stdout_logfile=/dev/fd/1
stdout_logfile_maxbytes=0
Check the processes:

docker exec smtp-relay supervisorctl status
Expected:

external-relay-script   RUNNING
postfix                 RUNNING
rsyslogd                RUNNING
Dynamic DNS Logging
Updater messages are available through normal Docker logs.

docker logs smtp-relay 2>&1 | grep dynamic-client
Example:

[dynamic-client] Updater started.
[dynamic-client] DNS name: mail.example.net
[dynamic-client] Interval: 60s
[dynamic-client] CIDR map: /data/dynamic-client.cidr
After an address change:

[dynamic-client] Client IP updated: mail.example.net -> 203.0.113.20
[dynamic-client] Postfix reloaded.
Testing Dynamic DNS Filtering
Check DNS resolution
docker exec smtp-relay \
  getent ahostsv4 mail.example.net
Example:

203.0.113.10 STREAM mail.example.net
203.0.113.10 DGRAM  mail.example.net
Show the generated CIDR map
docker exec smtp-relay \
  cat /data/dynamic-client.cidr
Example:

203.0.113.10/32 OK
0.0.0.0/0 REJECT Client IP is not authorized
Test an allowed address
docker exec smtp-relay \
  postmap -q 203.0.113.10 \
  cidr:/data/dynamic-client.cidr
Expected:

OK
Test an unauthorized address
docker exec smtp-relay \
  postmap -q 8.8.8.8 \
  cidr:/data/dynamic-client.cidr
Expected:

REJECT Client IP is not authorized
Health Check
The container contains a TCP based SMTP health check.

Default configuration:

interval:     10s
timeout:      3s
start-period: 10s
retries:      3
Repeated entries such as:

connect from localhost[127.0.0.1]
lost connection after CONNECT from localhost[127.0.0.1]
can therefore appear in the Postfix logs.

These connections are normally generated by the Docker health check.

Check container health:

docker inspect \
  --format='{{json .State.Health}}' \
  smtp-relay
Installation
Docker Hub
docker pull joedafoe/docker-smtp-relay:latest
Build Manually
git clone https://github.com/JoeDafoe/docker-smtp-relay.git
cd docker-smtp-relay

docker build \
  -t joedafoe/docker-smtp-relay:latest \
  .
Basic Usage
docker run \
  --name smtp-relay \
  -d \
  --restart=always \
  -p 25:25 \
  -e "RELAY_MYDOMAIN=domain.com" \
  -e "RELAY_HOST=relay:25" \
  joedafoe/docker-smtp-relay:latest
Complete Dynamic DNS Example
Create directories:

mkdir -p /DockerConfigs/mailrelay/data
mkdir -p /DockerConfigs/mailrelay/postfix
mkdir -p /DockerConfigs/mailrelay/scripts
Place the updater at:

/DockerConfigs/mailrelay/scripts/dynamic-client.sh
Make it executable:

chmod 755 \
  /DockerConfigs/mailrelay/scripts/dynamic-client.sh
Example deployment:

docker run \
  --name mailrelay \
  -d \
  --restart=always \
  -p 587:25 \
  -v /DockerConfigs/mailrelay/data:/data \
  -v /DockerConfigs/mailrelay/postfix:/var/spool/postfix \
  -v /DockerConfigs/mailrelay/scripts:/external-scripts:ro \
  -e "RELAY_POSTMASTER=administrator@example.net" \
  -e "RELAY_MYHOSTNAME=relay.example.net" \
  -e "RELAY_MYDOMAIN=example.net" \
  -e "RELAY_HOST=upstream-relay.example.net:25" \
  -e "RELAY_MYNETWORKS=127.0.0.0/8" \
  -e "RELAY_MODE=ALLOW_SASLAUTH_NODOMAIN" \
  -e "RELAY_USE_TLS=yes" \
  -e "RELAY_EXTERNAL_SCRIPT=/external-scripts/dynamic-client.sh" \
  -e "RELAY_DYNAMIC_CLIENT=mail.example.net" \
  -e "RELAY_DYNAMIC_CLIENT_INTERVAL=60" \
  -e "RELAY_DYNAMIC_CLIENT_MAP=/data/dynamic-client.cidr" \
  -e "POSTCONF_compatibility_level=3.6" \
  -e "POSTCONF_smtp_tls_security_level=encrypt" \
  joedafoe/docker-smtp-relay:latest
Verify a Running Deployment
Container
docker ps
DNS
docker exec mailrelay \
  getent ahostsv4 mail.example.net
Dynamic Client Map
docker exec mailrelay \
  cat /data/dynamic-client.cidr
Postfix Client Restrictions
docker exec mailrelay \
  postconf smtpd_client_restrictions
Expected:

smtpd_client_restrictions =
check_client_access cidr:/data/dynamic-client.cidr
Trusted Networks
docker exec mailrelay postconf mynetworks
Recommended for this deployment model:

mynetworks = 127.0.0.0/8
Upstream TLS
docker exec mailrelay \
  postconf smtp_tls_security_level
Expected when TLS is required:

smtp_tls_security_level = encrypt
Supervisor
docker exec mailrelay \
  supervisorctl status
Expected:

external-relay-script   RUNNING
postfix                 RUNNING
rsyslogd                RUNNING
Docker Compose Examples
Subnet Restricted SMTP Relay
services:
  smtp-relay:
    image: joedafoe/docker-smtp-relay:latest
    restart: always

    environment:
      RELAY_POSTMASTER: 'postmaster@example.net'
      RELAY_MYHOSTNAME: 'smtp-relay.example.net'
      RELAY_MYDOMAIN: 'example.net'
      RELAY_MYNETWORKS: '127.0.0.0/8 10.0.0.0/24'
      RELAY_HOST: '[10.1.0.1]:25'

    ports:
      - "10.0.0.1:3000:25"
Authenticated SMTP Relay
services:
  smtp-relay-auth:
    image: joedafoe/docker-smtp-relay:latest
    restart: always

    environment:
      RELAY_POSTMASTER: 'postmaster@example.net'
      RELAY_MYHOSTNAME: 'smtp-relay.example.net'
      RELAY_MYDOMAIN: 'example.net'
      RELAY_MYNETWORKS: '127.0.0.0/8'
      RELAY_HOST: '[10.1.0.1]:25'
      RELAY_MODE: 'ALLOW_SASLAUTH_NODOMAIN'
      RELAY_USE_TLS: 'yes'
      POSTCONF_compatibility_level: '3.6'
      POSTCONF_smtp_tls_security_level: 'encrypt'

    ports:
      - "587:25"

    volumes:
      - data-smtp-relay-auth:/data
      - data-smtp-relay-queue:/var/spool/postfix

volumes:
  data-smtp-relay-auth:
  data-smtp-relay-queue:
Dynamic DNS Protected Relay
services:
  smtp-relay:
    image: joedafoe/docker-smtp-relay:latest
    restart: always

    ports:
      - "587:25"

    environment:
      RELAY_POSTMASTER: 'postmaster@example.net'
      RELAY_MYHOSTNAME: 'relay.example.net'
      RELAY_MYDOMAIN: 'example.net'

      RELAY_MYNETWORKS: '127.0.0.0/8'
      RELAY_MODE: 'ALLOW_SASLAUTH_NODOMAIN'

      RELAY_HOST: 'upstream-relay.example.net:25'
      RELAY_USE_TLS: 'yes'

      RELAY_EXTERNAL_SCRIPT: '/external-scripts/dynamic-client.sh'
      RELAY_DYNAMIC_CLIENT: 'mail.example.net'
      RELAY_DYNAMIC_CLIENT_INTERVAL: '60'
      RELAY_DYNAMIC_CLIENT_MAP: '/data/dynamic-client.cidr'

      POSTCONF_compatibility_level: '3.6'
      POSTCONF_smtp_tls_security_level: 'encrypt'

    volumes:
      - /DockerConfigs/mailrelay/data:/data
      - /DockerConfigs/mailrelay/postfix:/var/spool/postfix
      - /DockerConfigs/mailrelay/scripts:/external-scripts:ro
Incoming STARTTLS
Incoming STARTTLS protects authentication and SMTP traffic between an SMTP client and this relay.

Relevant Postfix parameters are:

smtpd_tls_security_level = may
smtpd_tls_auth_only = yes
smtpd_tls_cert_file = /cert/fullchain.pem
smtpd_tls_key_file = /cert/privkey.pem
They can be supplied through POSTCONF_*:

-e "POSTCONF_smtpd_tls_security_level=may"
-e "POSTCONF_smtpd_tls_auth_only=yes"
-e "POSTCONF_smtpd_tls_cert_file=/cert/fullchain.pem"
-e "POSTCONF_smtpd_tls_key_file=/cert/privkey.pem"
Mount the certificate read-only:

-v /local/cert:/cert:ro
For SMTP AUTH exposed to the Internet, preventing authentication before TLS is strongly recommended:

smtpd_tls_auth_only = yes
Troubleshooting
Effective Postfix Configuration
docker exec smtp-relay postconf -n
Mail Flow Logs
docker logs --since 5m smtp-relay 2>&1 \
  | grep -E 'sasl_|status=|reject|REJECT|dynamic-client'
Successful SASL authentication may appear as:

sasl_method=LOGIN
sasl_username=user@example.net
Successful upstream TLS delivery may appear as:

tls=encrypt
dsn=2.0.0
status=sent
Dynamic DNS Logs
docker logs --since 10m smtp-relay 2>&1 \
  | grep dynamic-client
SMTP Listener
docker exec smtp-relay \
  nc -z -w 2 127.0.0.1 25
Test SMTP from Inside the Container
docker exec -it smtp-relay \
  /opt/smtp_client.py \
  -s test \
  -f noreply@domain.com \
  --user user1:password1 \
  admin@domain.com
Security Recommendations
For Internet-facing relays:

Do not use RELAY_MYNETWORKS=0.0.0.0/0 as a general trust mechanism.
Prefer SASL authentication for external SMTP clients.
Use Dynamic DNS filtering as an additional security layer when the authorized client has a dynamic public IP.
Keep RELAY_MYNETWORKS limited to systems and networks that should actually be trusted.
Require TLS when sending to a known upstream smart host when supported:
smtp_tls_security_level = encrypt
Enable STARTTLS for Internet-facing incoming SMTP authentication.
Prevent SMTP AUTH before TLS:
smtpd_tls_auth_only = yes
Use long and unique SASL credentials.
Protect the /data volume because it contains SASL authentication data.
Monitor Postfix logs for failed authentication and unauthorized client attempts.
Mount external scripts read-only:
/external-scripts:ro
Keep the Dynamic DNS CIDR map on persistent storage.
