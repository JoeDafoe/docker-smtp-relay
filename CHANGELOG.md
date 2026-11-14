# Changelog

## 2026/11/14

### Image

+ Update Alpine to 3.24.4
+ Update Postfix to latest available Alpine 3.24 package
+ Add `ca-certificates` package explicitly
+ Update CA certificate store during image build
+ Update OCI image author label
+ Improve Docker runtime directory handling
+ Add `/etc/supervisor.d` directory for dynamically generated Supervisor services
+ Add `/external-scripts` directory as mount point for externally managed helper scripts
+ Improve Docker healthcheck timing and startup behaviour
+ Keep `/data` and `/var/spool/postfix` as persistent volumes
+ Keep optional site-specific helper scripts outside the Docker image

### Dynamic Client Template

+ Add `dynamic-client_template.sh` as reference implementation for Dynamic DNS based SMTP client filtering
+ Provide the Dynamic DNS updater as a customizable template instead of embedding site-specific Dynamic DNS logic directly into the Docker image
+ Allow administrators to copy `dynamic-client_template.sh` to their persistent Docker configuration directory and customize the script without rebuilding the Docker image
+ Design the template to be mounted read-only into `/external-scripts`
+ Add `--init` execution mode to perform an initial DNS lookup and create the first CIDR map during container startup
+ Add `--once` execution mode to perform one DNS lookup and CIDR update
+ Add `--loop` execution mode to continuously monitor the configured Dynamic DNS hostname
+ Add `RELAY_DYNAMIC_CLIENT` to define the Dynamic DNS hostname of the authorized SMTP client
+ Add `RELAY_DYNAMIC_CLIENT_INTERVAL` to define the DNS polling interval in seconds
+ Set the default Dynamic DNS polling interval to 60 seconds
+ Validate the polling interval and allow values between 30 and 86400 seconds
+ Add `RELAY_DYNAMIC_CLIENT_MAP` to define the generated Postfix CIDR map
+ Default the generated CIDR map to `/data/dynamic-client.cidr`
+ Store the generated CIDR map on persistent `/data` storage
+ Resolve the current IPv4 address of the configured Dynamic DNS hostname
+ Validate resolved IPv4 addresses before applying them
+ Generate an exact `/32` allow rule for the currently authorized SMTP client
+ Generate a catch-all IPv4 reject rule for all other clients
+ Generate CIDR maps containing the source hostname, update timestamp, current `/32` authorized address and catch-all reject rule
+ Compare the currently resolved DNS address with the address already stored in the CIDR map
+ Do not rewrite the CIDR map when the IPv4 address has not changed
+ Use temporary files and atomic file replacement when updating the CIDR map
+ Run `postfix check` before reloading Postfix after an IP address change
+ Automatically reload Postfix after applying a changed Dynamic DNS client address
+ Skip Postfix reload during initial container setup when Postfix is not running yet
+ Keep the previous valid CIDR map when a temporary DNS lookup fails
+ Prevent temporary DNS resolution failures from automatically opening SMTP access
+ Add timestamped logging to the Dynamic DNS updater
+ Log the configured DNS hostname, polling interval and CIDR map path during updater startup
+ Log authorized client IP changes
+ Log Postfix reload operations caused by Dynamic DNS IP changes

### Dynamic Client Locking

+ Add runtime locking to `dynamic-client_template.sh` to prevent concurrent Dynamic DNS update operations
+ Use `/tmp/dynamic-client.lock` as non-persistent runtime lock
+ Ensure the updater lock is released after every individual DNS update cycle
+ Fix previous lock handling where an `EXIT` trap kept the lock for the lifetime of the complete `--loop` process
+ Fix repeated `Another update operation is already running` warnings after the first successful update
+ Remove stale updater locks when the Supervisor managed `--loop` process starts
+ Add signal handling for `INT`, `TERM` and `HUP` while an update operation owns the lock
+ Keep runtime locks outside persistent Docker volumes
+ Verify that normal polling cycles no longer leave stale lock state behind

### External Script Integration

+ Add `RELAY_EXTERNAL_SCRIPT` environment variable to enable optional external relay extensions
+ Keep external script functionality disabled when `RELAY_EXTERNAL_SCRIPT` is empty or unset
+ Restrict external relay scripts to the `/external-scripts` directory
+ Verify that configured external scripts exist before enabling them
+ Verify that configured external scripts are readable and executable
+ Run the configured external script with `--init` during container initialization
+ Require successful initial execution before enabling Dynamic Client restrictions
+ Verify that initialization creates a non-empty CIDR map
+ Verify that the generated map contains at least one valid IPv4 `/32` allow rule
+ Require Dynamic Client maps to be stored below persistent `/data`
+ Configure Postfix automatically with `smtpd_client_restrictions = check_client_access cidr:/data/dynamic-client.cidr`
+ Keep external scripts independent from the Docker image so custom logic can be updated without rebuilding the image
+ Support read-only `/external-scripts` mounts
+ Allow `dynamic-client_template.sh` to be used as a starting point for custom client discovery and authorization mechanisms

### Dynamic Client Filtering

+ Add optional Dynamic DNS based SMTP client IP filtering
+ Support SMTP clients with dynamically changing public IPv4 addresses
+ Keep Dynamic DNS client authorization separate from Postfix `mynetworks`
+ Allow `RELAY_MYNETWORKS` to remain limited to trusted networks such as `127.0.0.0/8`
+ Use a dedicated Postfix CIDR client access map instead of dynamically modifying `mynetworks`
+ Authorize the current Dynamic DNS client address using an exact `/32` rule
+ Reject Internet SMTP clients whose IPv4 address does not match the dynamically authorized address
+ Keep Dynamic DNS client filtering independent from SASL username/password authentication
+ Support combining Dynamic DNS IP filtering and SASL authentication as separate security layers
+ Remove the need to configure `RELAY_MYNETWORKS=0.0.0.0/0` only because an authorized SMTP client has a dynamic public IP address

### Supervisor

+ Add support for dynamically generated Supervisor program configurations
+ Add `/etc/supervisor.d/*.ini` include support
+ Automatically generate `/etc/supervisor.d/external-relay-script.ini` when an external script is enabled
+ Run external Dynamic DNS updater scripts as Supervisor managed processes
+ Start the Dynamic DNS updater using `--loop`
+ Automatically restart the external updater if it terminates unexpectedly
+ Add startup retry handling
+ Add clean `TERM` shutdown handling
+ Redirect updater output to Docker stdout/stderr
+ Allow updater status to be checked using `supervisorctl status`

### TLS

+ Add support for explicit incoming and outgoing Postfix TLS configuration through `POSTCONF_*`
+ Support mandatory TLS connections to upstream SMTP relays using `POSTCONF_smtp_tls_security_level=encrypt`
+ Add incoming SMTP STARTTLS support using `POSTCONF_smtpd_tls_security_level=may`
+ Add support for restricting SMTP AUTH to encrypted connections using `POSTCONF_smtpd_tls_auth_only=yes`
+ Add support for externally mounted TLS certificates and private keys
+ Support Let's Encrypt certificates managed by Certbot outside the Docker container
+ Support mounting the complete `/etc/letsencrypt` hierarchy read-only into the container
+ Preserve Certbot `live` to `archive` certificate symlinks inside the container
+ Verify incoming SMTP STARTTLS with Microsoft Exchange
+ Verify successful TLS 1.2 operation
+ Verify `ECDHE-ECDSA-AES128-GCM-SHA256` cipher compatibility
+ Support SASL `LOGIN` only after successful STARTTLS negotiation
+ Verify TLS protected SASL authentication
+ Verify mandatory encrypted Postfix delivery to an upstream SMTP smart host
+ Verify outgoing mail delivery with `tls=encrypt`
+ Support configurable `smtpd_tls_loglevel` through `POSTCONF_*`

### Security

+ Default `RELAY_MYNETWORKS` to `127.0.0.0/8`
+ Add Dynamic DNS client allowlisting as an optional security layer in addition to SASL authentication
+ Allow unauthorized Internet SMTP clients to be rejected using the generated CIDR access map
+ Keep IP authorization independent from SMTP username/password authentication
+ Support SASL authentication only after STARTTLS
+ Support TLS protected SASL `LOGIN` authentication
+ Support mandatory encrypted delivery to configured upstream SMTP smart hosts
+ Improve separation between trusted Postfix networks and dynamically authorized Internet clients
+ Support certificate hostname validation by SMTP clients
+ Support publicly trusted Let's Encrypt certificates
+ Prevent temporary Dynamic DNS failures from automatically opening SMTP access
+ Persist the last known valid Dynamic DNS CIDR configuration across container restarts
+ Keep Dynamic DNS runtime locks non-persistent
+ Recommend read-only mounts for external scripts and TLS certificate storage

### Configuration

+ Add `RELAY_EXTERNAL_SCRIPT` environment variable
+ Add `RELAY_DYNAMIC_CLIENT` environment variable
+ Add `RELAY_DYNAMIC_CLIENT_INTERVAL` environment variable
+ Add `RELAY_DYNAMIC_CLIENT_MAP` environment variable
+ Keep support for arbitrary Postfix configuration through `POSTCONF_*`
+ Support incoming STARTTLS configuration using `POSTCONF_smtpd_*`
+ Support upstream TLS configuration using `POSTCONF_smtp_*`
+ Support `POSTCONF_smtp_tls_security_level=encrypt`
+ Support `POSTCONF_smtpd_tls_security_level=may`
+ Support `POSTCONF_smtpd_tls_auth_only=yes`
+ Support external certificate paths using `POSTCONF_smtpd_tls_cert_file`
+ Support external private key paths using `POSTCONF_smtpd_tls_key_file`
+ Document recommended Postfix 3.11 `compatibility_level=3.11`
+ Keep external script configuration independent from environment-specific implementation logic

### Logging and Troubleshooting

+ Add Dynamic DNS updater messages to Docker logs
+ Log Dynamic DNS updater startup information
+ Log DNS lookup failures
+ Log invalid DNS IPv4 responses
+ Log Dynamic DNS client IP changes
+ Log Postfix reload operations after Dynamic DNS IP changes
+ Add warnings for concurrent updater operations
+ Fix repetitive lock warnings caused by stale update locks
+ Improve incoming STARTTLS troubleshooting
+ Add configurable Postfix server-side TLS logging
+ Add verification methods for Dynamic DNS CIDR maps using `postmap`
+ Add verification methods for Dynamic DNS hostname resolution using `getent`
+ Add verification methods for Postfix `mynetworks`
+ Add verification methods for `smtpd_client_restrictions`
+ Add verification methods for Supervisor managed services
+ Add verification methods for incoming TLS connections
+ Add verification methods for outgoing TLS connections
+ Add verification methods for SASL authenticated mail flow
+ Add Docker container health verification
+ Add Postfix mail queue verification
+ Add mounted certificate and private key readability checks

### Documentation

+ Update README for Alpine 3.24.4
+ Document `dynamic-client_template.sh`
+ Document the purpose of the Dynamic Client template
+ Document how to copy and customize `dynamic-client_template.sh`
+ Document that customized Dynamic Client scripts remain outside the Docker image
+ Document read-only external script mounting under `/external-scripts`
+ Document `--init`, `--once` and `--loop` execution modes
+ Document Dynamic DNS based SMTP client filtering
+ Document Dynamic DNS environment variables
+ Document persistent CIDR map behaviour
+ Document IPv4 `/32` allow and catch-all reject rules
+ Document Dynamic DNS polling and update behaviour
+ Document behaviour during temporary DNS failures
+ Document updater locking and stale lock recovery
+ Document Supervisor integration
+ Document Dynamic DNS runtime verification
+ Document manual CIDR lookups using `postmap`
+ Document DNS verification using `getent`
+ Document outgoing mandatory TLS configuration
+ Document incoming STARTTLS configuration
+ Document SASL authentication over TLS
+ Document externally managed Let's Encrypt certificates
+ Document read-only `/etc/letsencrypt` mounts
+ Add Dynamic DNS `docker run` example
+ Add Dynamic DNS Docker Compose example
+ Add runtime verification and troubleshooting commands
+ Add Internet-facing SMTP relay security recommendations


## 2025/10/03

+ Change "message_size_limit" from standard 10 MB to 50 MB


## 2025/07/16

+ Update alpine to 3.22.1
+ Update Postfix to latest
+ Delete Install cyrus-sasl-plain
+ Change postconf -e "sender_canonical_maps = hash:/etc/postfix/sender_canonical" to postconf -e "sender_canonical_maps = lmdb:/etc/postfix/sender_canonical"


## 3.2.0 (2020-05-09)

+ Update alpine to 3.11
+ Split entrypoint tasks into separated files
+ Update rsyslog config to new syntax
+ Update supervisord config
+ Use postfix start-fg command to run postfix
+ Add missing package for timezone to work
+ Add postconf entrypoint hook from POSTCONF_* variables
+ Fix #17 sasl_client bulk feed (thanks @mattstrain) #17
+ Fix sasl passwd list command
+ Declare /var/spool/postfix as volume to persist queue
+ Fix bad check condition with RELAY TLS
+ Apply smtp_tls_CAfile only if TLS is used
+ Move utility script from /opt/postfix to /opt
+ Add utility script /opt/smtp_client.py
+ Improve sasldb pwcheck configuration

### Build process

+ Add shellcheck tests
+ Add timezone test
+ Add sasl client credentials feed test
+ Add sasl client auth test
+ Prevent overwrite /etc permissions during COPY
+ Improve publish script and edit pushed tags

### Deprecation

- DEPRECATE RELAY_EXTRAS_SETTINGS settings in favor of POSTCONF_ variables (will be removed in 4.0)


## 3.1.0 (2019-09-09)

### Image

- Allow use of external users database (thanks to @kir4h)
- Update alpine to 3.10
- Refactor the entrypoint.sh
- Update supervisor configuration


## 3.0.1 (2019-05-23)

### Image

- Image has now a default value for `RELAY_TLS_CA` (thanks to @kir4h)


## 3.0.0 (2019-03-30)

### Image

- Replace start.sh by entrypoint


## 2.2.0 (2018-11-03)

### Image

+ Upgrade base image to Alpine 3.8


## 2.1.0 (2018-03-31)

### Image

+ Add docker healthcheck command


## 2.0.0 (2018-02-03)

### Image

+ Add RELAY_EXTRAS_SETTINGS setting
+ Upgrade base image to Alpine 3.7

### Sasl

* Moved the utility scripts to /opt/postfix


## 1.0.0 (2017-05-27)

First release
