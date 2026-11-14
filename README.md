# Docker SMTP Relay

This image contains an instance of Postfix SMTP server configured as a SMTP relay.

This relay can be restricted by domain name, trusted networks, SASL authentication and optionally by a dynamically resolved client IP address.

This makes the image suitable for applications, servers and mail systems such as Microsoft Exchange that need to send emails through an upstream SMTP relay.

:warning: Take care of the [changelogs](CHANGELOG.md) because some breaking changes may happen between versions.

:warning: If this relay is exposed to the Internet, do not use `RELAY_MYNETWORKS=0.0.0.0/0` unless you fully understand the resulting Postfix relay permissions. SASL authentication and restrictive client access rules are strongly recommended.

## Supported tags, image variants and respective Dockerfile links

* Main image with Postfix [Dockerfile](https://github.com/JoeDafoe/docker-smtp-relay/blob/master/Dockerfile)

    * Alpine 3.24.4
    * Postfix
    * Cyrus SASL
    * Supervisor
    * rsyslog

## Features

* Postfix SMTP relay
* Cyrus SASL authentication
* Persistent SASL database
* Persistent Postfix mail queue
* Sender domain restrictions
* Multiple relay authorization modes
* Upstream smart host support
* TLS support for the upstream SMTP relay
* Generic Postfix configuration through `POSTCONF_*`
* Docker health check
* Supervisor process management
* Optional external script support
* Optional Dynamic DNS based client IP filtering
* Automatic Postfix reload when the Dynamic DNS client IP changes
* Persistent last known Dynamic DNS client IP

## Example of usage

This relay can take place into an information system if you want to give access to web applications, servers, Microsoft Exchange or other applications that need a way to send notification emails.

Clients can be authorized in different ways:

* The host IP address is in the range of `RELAY_MYNETWORKS`
* The host is authenticated with a valid SASL login/password
* The host IP address matches an optional Dynamic DNS client rule
* A combination of Dynamic DNS client filtering and SASL authentication

For Internet-facing SMTP relays, using both IP filtering and SASL authentication provides an additional layer of protection.

## Docker Informations

* This port is available on this image

| Port | Usage |
| ---- | ----- |
| 25 | SMTP for incoming relay user |

The container port can be mapped to another host port.

For example:

```bash
-p 587:25
```

Postfix will continue listening on port `25` inside the container while clients connect to port `587` on the Docker host.

* These volumes can be used with this image

| Volume | Usage |
| ------ | ----- |
| `/data` | Contains the SASL database and optional Dynamic DNS CIDR map |
| `/var/spool/postfix` | Where Postfix stores the mail queue to persist messages across container restarts |
| `/external-scripts` | Optional external scripts. Recommended to mount read-only |

* This image takes these environment variables as parameters

| Environment | Type | Usage |
| ----------- | ---- | ----- |
| `RELAY_MYHOSTNAME` | String | The hostname of the SMTP relay. Docker assigns a random hostname by default, so you can specify a human-readable hostname |
| `RELAY_MYDOMAIN` | String | The domain name that this relay will forward mail for |
| `RELAY_MYNETWORKS` | List of strings | Space separated list of trusted networks |
| `RELAY_DOMAINS` | List of strings | Space separated list of external domain names for which the relay will forward email. Useless when using a `*NODOMAIN` relay mode. Defaults to `RELAY_MYDOMAIN` |
| `RELAY_HOST` | String | The remote host to which relayed emails are sent |
| `RELAY_LOGIN` | String | Login name presented to the upstream relay during authentication |
| `RELAY_PASSWORD` | String | Password presented to the upstream relay during authentication |
| `RELAY_USE_TLS` | Boolean (`yes/no`) | Enable TLS for the connection to the upstream relay |
| `RELAY_TLS_VERIFY` | Enum | TLS security level: `none`, `may`, `encrypt`, `dane`, `dane-only`, `fingerprint`, `verify`, `secure` |
| `RELAY_TLS_CA` | String path | CA file used to check relayhost certificates. Default: `/etc/ssl/certs/ca-certificates.crt` |
| `RELAY_POSTMASTER` | Email address | Postmaster address used for Postfix errors and configuration notifications |
| `RELAY_STRICT_SENDER_MYDOMAIN` | Boolean (`true/false`) | If set to `true`, sender addresses must belong to the relay domain |
| `RELAY_MODE` | Enum | Predefined relay behaviour. See below |
| `RELAY_EXTRAS_SETTINGS` | List of strings | Deprecated. Use `POSTCONF_` instead |
| `POSTCONF_[custom]` | Mixed | Set any available Postfix `postconf` parameter |
| `RELAY_EXTERNAL_SCRIPT` | String path | Optional external script. Empty or unset disables this feature |
| `RELAY_DYNAMIC_CLIENT` | DNS hostname | Dynamic DNS hostname representing an authorized SMTP client |
| `RELAY_DYNAMIC_CLIENT_INTERVAL` | Integer | DNS update interval in seconds. Example: `60` |
| `RELAY_DYNAMIC_CLIENT_MAP` | String path | Persistent CIDR map. Default: `/data/dynamic-client.cidr` |

### Relay Mode

Description of available relay modes.

| Relay mode value | Description | Usage |
| ---------------- | ----------- | ----- |
| `STRICT` | Only network and SASL authenticated users can send email through the relay. All emails must have a recipient address that belongs to the relay domains | Typically used when applications may only send to internal domains |
| `ALLOW_SASLAUTH_NODOMAIN` | SASL authenticated users may send to external domains. Network authenticated users remain restricted to the relay domains | Recommended when authenticated applications or Microsoft Exchange need to send to external recipients |
| `ALLOW_NETAUTH_NODOMAIN` | Network authenticated users may send to external domains. SASL authenticated users remain restricted to the relay domains | Useful when trusted internal networks must relay externally |
| `ALLOW_AUTH_NODOMAIN` | Network and SASL authenticated users may send to arbitrary recipients | Simple unrestricted relay for authenticated clients. Use with care |

For other examples of values, refer to the Dockerfile.

## Postfix configuration using POSTCONF_

Any available Postfix setting can be configured using an environment variable prefixed with `POSTCONF_`.

For example:

```bash
-e "POSTCONF_compatibility_level=3.6"
```

results in:

```text
compatibility_level = 3.6
```

To require TLS when sending to the upstream SMTP relay:

```bash
-e "POSTCONF_smtp_tls_security_level=encrypt"
```

This results in:

```text
smtp_tls_security_level = encrypt
```

The effective Postfix configuration can be checked with:

```bash
docker exec smtp-relay postconf -n
```

A specific setting can be checked using:

```bash
docker exec smtp-relay postconf smtp_tls_security_level
```

## TLS to the upstream relay

TLS can be enabled for the connection between this relay and the upstream SMTP server.

For a known upstream smart host that supports STARTTLS, TLS can be required with:

```bash
-e "RELAY_USE_TLS=yes"
-e "POSTCONF_smtp_tls_security_level=encrypt"
```

With:

```text
smtp_tls_security_level = encrypt
```

Postfix will not send the message to the upstream server without TLS.

A successful TLS delivery can be verified in the logs:

```text
tls=encrypt
dsn=2.0.0
status=sent
```

For example:

```bash
docker logs --since 5m smtp-relay 2>&1 | grep 'postfix/smtp'
```

## Dynamic DNS Client Filtering

The image supports optional Dynamic DNS based SMTP client filtering.

This is useful when a server such as Microsoft Exchange connects to the SMTP relay over the Internet but has a dynamically assigned public IPv4 address.

Instead of trusting every IPv4 address with:

```text
RELAY_MYNETWORKS=0.0.0.0/0
```

a Dynamic DNS hostname can be resolved periodically.

Example:

```text
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
Postfix SMTP relay
```

All other IPv4 addresses can then be rejected:

```text
0.0.0.0/0 REJECT Client IP is not authorized
```

It is recommended to combine Dynamic DNS client filtering with SASL authentication.

The resulting security model is:

```text
Dynamic DNS IP match
        +
SASL authentication
        +
SMTP relay authorization
```

Dynamic DNS client filtering does **not** replace SASL authentication.

### Dynamic DNS Environment Variables

Enable the feature using:

```bash
-e "RELAY_EXTERNAL_SCRIPT=/external-scripts/dynamic-client.sh"
-e "RELAY_DYNAMIC_CLIENT=mail.example.net"
-e "RELAY_DYNAMIC_CLIENT_INTERVAL=60"
-e "RELAY_DYNAMIC_CLIENT_MAP=/data/dynamic-client.cidr"
```

The recommended trusted network configuration in this scenario is:

```bash
-e "RELAY_MYNETWORKS=127.0.0.0/8"
```

The dynamic client IP should not be added to `RELAY_MYNETWORKS`.

Instead, Postfix uses a dedicated client access map.

### External Script

The Dynamic DNS update script is intentionally stored outside the Docker image.

Example host path:

```text
/DockerConfigs/mailrelay/scripts/dynamic-client.sh
```

Mount it read-only:

```bash
-v /DockerConfigs/mailrelay/scripts:/external-scripts:ro
```

Make the script executable:

```bash
chmod 755 /DockerConfigs/mailrelay/scripts/dynamic-client.sh
```

This design allows the Dynamic DNS logic to be modified without rebuilding the Docker image.

When `RELAY_EXTERNAL_SCRIPT` is not defined, the external script functionality is disabled.

### External Script Interface

An external script must support:

```text
--init
--loop
```

`--init` is executed when the container starts:

```bash
/external-scripts/dynamic-client.sh --init
```

It creates the initial Dynamic DNS CIDR map.

`--loop` is managed by Supervisor:

```bash
/external-scripts/dynamic-client.sh --loop
```

The loop checks the DNS hostname periodically.

### Generated CIDR Map

The generated map is stored in the persistent `/data` volume.

Default:

```text
/data/dynamic-client.cidr
```

Example:

```text
# Automatically generated. Do not edit.
# Source: mail.example.net
# Updated: 2026-11-14T10:23:29Z
203.0.113.10/32 OK
0.0.0.0/0 REJECT Client IP is not authorized
```

Postfix automatically uses:

```text
smtpd_client_restrictions = check_client_access cidr:/data/dynamic-client.cidr
```

You can verify this with:

```bash
docker exec smtp-relay postconf smtpd_client_restrictions
```

Expected:

```text
smtpd_client_restrictions = check_client_access cidr:/data/dynamic-client.cidr
```

### Dynamic DNS Update Behaviour

The updater checks the configured DNS hostname periodically.

If the IP does not change:

```text
DNS lookup
    |
same IP
    |
no action
```

If the IP changes:

```text
DNS lookup
    |
new IP
    |
update CIDR map
    |
postfix check
    |
postfix reload
```

Postfix is only reloaded when required.

If DNS resolution temporarily fails and an existing map is already available, the existing map is retained.

### Verify Dynamic DNS Resolution

Check DNS inside the container:

```bash
docker exec smtp-relay getent ahostsv4 mail.example.net
```

Check the currently generated access map:

```bash
docker exec smtp-relay cat /data/dynamic-client.cidr
```

### Test the CIDR Map

Test the authorized IP:

```bash
docker exec smtp-relay \
  postmap -q 203.0.113.10 cidr:/data/dynamic-client.cidr
```

Expected:

```text
OK
```

Test an unauthorized IP:

```bash
docker exec smtp-relay \
  postmap -q 8.8.8.8 cidr:/data/dynamic-client.cidr
```

Expected:

```text
REJECT Client IP is not authorized
```

### Supervisor Integration

The Dynamic DNS updater is managed by Supervisor.

Check its status:

```bash
docker exec smtp-relay supervisorctl status
```

A Dynamic DNS enabled relay should show something similar to:

```text
external-relay-script    RUNNING
postfix                  RUNNING
rsyslogd                 RUNNING
```

Supervisor loads dynamically generated definitions from:

```text
/etc/supervisor.d/*.ini
```

### Dynamic DNS Logs

Ch*ck the updater:

```bash
docker lo*s --since 10m smtp-relay 2>&1 | gr*p dynamic-client
```

Example:

``*text
[dynamic-client] Updater star*ed.
[dynamic-client] DNS name: mai*.example.net
[dynamic-client] Inte*val: 60s
[dynamic-client] CIDR map* /data/dynamic-client.cidr
```

Af*er an IP change:

```text
[dynamic-client] Client IP updated: mail.ex*mple.net -> 203.0.113.20
[dynamic-client] Postfix reloaded.
```

## I*stallation

* Manual

```bash
git *lone https://github.com/JoeDafoe/docker-smtp-relay.git
cd docker-smtp*relay
./build.sh
```

Alternativel*:

```bash
docker build -t joedafo*/docker-smtp-relay:latest .
```

**Automatic

```bash
docker pull joe*afoe/docker-smtp-relay:latest
```
*## Usage

Basic example:

```bash
*ocker run \
  --name smtp-relay \
* -d \
  --restart=always \
  -p 25*25 \
  -e "RELAY_MYDOMAIN=domain.c*m" \
  -e "RELAY_HOST=relay:25" \
* joedafoe/docker-smtp-relay:latest*```

### Dynamic DNS protected Int*rnet relay

Example for an authent*cated mail server with a dynamic p*blic IP:

```bash
docker run \
  -*name mailrelay \
  -d \
  --restar*=always \
  -p 587:25 \
  -v /Dock*rConfigs/mailrelay/data:/data \
  *v /DockerConfigs/mailrelay/postfix*/var/spool/postfix \
  -v /DockerC*nfigs/mailrelay/scripts:/external-*cripts:ro \
  -e "RELAY_POSTMASTER*administrator@example.net" \
  -e *RELAY_MYHOSTNAME=relay.example.net* \
  -e "RELAY_MYDOMAIN=example.ne*" \
  -e "RELAY_HOST=upstream-rela*.example.net:25" \
  -e "RELAY_MYN*TWORKS=127.0.0.0/8" \
  -e "RELAY_*ODE=ALLOW_SASLAUTH_NODOMAIN" \
  -* "RELAY_USE_TLS=yes" \
  -e "RELAY*EXTERNAL_SCRIPT=/external-scripts/*ynamic-client.sh" \
  -e "RELAY_DY*AMIC_CLIENT=mail.example.net" \
  *e "RELAY_DYNAMIC_CLIENT_INTERVAL=6*" \
  -e "RELAY_DYNAMIC_CLIENT_MAP*/data/dynamic-client.cidr" \
  -e *POSTCONF_compatibility_level=3.6" *
  -e "POSTCONF_smtp_tls_security_*evel=encrypt" \
  joedafoe/docker-*mtp-relay:latest
```

### Docker-c*mpose Specific configuration examp*es

* unauthenticated SMTP relay f*ltered by subnet and domain name

*``yaml
services:
  smtp-relay:
   *image: joedafoe/docker-smtp-relay:*atest
    environment:
      RELAY*POSTMASTER: 'postmaster@example.ne*'
      RELAY_MYHOSTNAME: 'smtp-re*ay.example.net'
      RELAY_MYDOMA*N: 'example.net'
      RELAY_MYNET*ORKS: '127.0.0.0/8 10.0.0.0/24'
  *   RELAY_HOST: '[10.1.0.1]:25'
   *ports:
      - "10.0.0.1:3000:25"
*``

* authenticated SMTP proxy

``*yaml
services:
  smtp-relay-auth:
*   image: joedafoe/docker-smtp-rel*y:latest
    environment:
      RE*AY_POSTMASTER: 'postmaster@example*net'
      RELAY_MYHOSTNAME: 'smtp*relay.example.net'
      RELAY_MYD*MAIN: 'example.net'
      RELAY_MY*ETWORKS: '127.0.0.0/8 10.0.0.0/24'*      RELAY_HOST: '[10.1.0.1]:25'
*     RELAY_MODE: 'ALLOW_SASLAUTH_N*DOMAIN'
      RELAY_LOGIN: 'sasl-u*er-login'
      RELAY_PASSWORD: 'x*xxxxxxxxxx'
      RELAY_USE_TLS: '*o'
      POSTCONF_compatibility_le*el: '3.6'
    ports:
      - "10.0*0.1:3000:25"
    volumes:
      - *ata-smtp-relay-auth:/data
      - *ata-smtp-relay-queue:/var/spool/po*tfix

volumes:
  data-smtp-relay-a*th:
  data-smtp-relay-queue:
```

*## Using external relay credential*

If you want to prevent having yo*r upstream relay credentials in yo*r `docker-compose.yml`, mount them*instead of setting `RELAY_LOGIN` a*d `RELAY_PASSWORD`.

Mount the cre*entials file to:

```text
/etc/pos*fix/sasl_passwd
```

Example:

```*aml
services:
  smtp-relay-auth:
 *  image: joedafoe/docker-smtp-rela*:latest
    environment:
      REL*Y_POSTMASTER: 'postmaster@example.*et'
      RELAY_MYHOSTNAME: 'smtp-*elay.example.net'
      RELAY_MYDO*AIN: 'example.net'
      RELAY_MYN*TWORKS: '127.0.0.0/8 10.0.0.0/24'
*     RELAY_HOST: '[10.1.0.1]:25'
 *    RELAY_MODE: 'ALLOW_SASLAUTH_NO*OMAIN'
      RELAY_USE_TLS: 'no'
 *    POSTCONF_compatibility_level: *3.6'
    ports:
      - "10.0.0.1:*000:25"
    volumes:
      - data-*mtp-relay-auth:/data
      - "/my/*ocal/path/sasl_passwd:/etc/postfix*sasl_passwd:ro"

volumes:
  data-s*tp-relay-auth:
```

Example conten*s:

```text
[10.1.0.1]:25 sasl-use*-login:xxxxxxxxxxxx
```

## Config*ration during runtime

* List all *ASL users:

```bash
docker exec sm*p-relay /opt/listpasswd.sh
```

* *dd a SASL user:

```bash
docker ex*c -it smtp-relay \
  /opt/saslpass*d.sh \
  -u domain.com \
  -c user*ame
```

Replace `domain.com` with*your relay domain.

You will be pr*mpted for the password.

* Add mul*iple SASL users:

Mount a credenti*ls list to:

```text
/etc/postfix/*lient_sasl_passwd
```

Each line u*es:

```text
USERNAME PASSWORD
```*
Example:

```text
application1 Pa*swordExample1
application2 Passwor*Example2
```

Check the Docker log* to ensure all entries were regist*red successfully.

## Incoming STARTTLS

Incoming STARTTLS can protect SMTP authentication between the SMTP client and this relay.

The relevant Postfix settings are:

```text
smtpd_tls_security_level = may
smtpd_tls_auth_only = yes
smtpd_tls_cert_file = /cert/fullchain.pem
smtpd_tls_key_file = /cert/privkey.pem
```

These can be configured using `POSTCONF_*`:

```bash
-e "POSTCONF_smtpd_tls_security_level=may"
-e "POSTCONF_smtpd_tls_auth_only=yes"
-e "POSTCONF_smtpd_tls_cert_file=/cert/fullchain.pem"
-e "POSTCONF_smtpd_tls_key_file=/cert/privkey.pem"
```

Mount the certificate read-only:

```bash
-v /local/cert:/cert:ro
```

For Internet-facing SMTP AUTH, preventing authentication before TLS is strongly recommended:

```text
smtpd_tls_auth_only = yes
```

## Troubleshooting

### Show effective Postfix configuration

```bash
docker exec smtp-relay postconf -n
```

### Show Docker logs

```bash
docker logs --since 10m smtp-relay
```

### Check mail flow

```bash
docker logs --since 5m smtp-relay 2>&1 \
  | grep -E 'sasl_|status=|reject|REJECT|dynamic-client'
```

Successful SASL authentication can look like:

```text
sasl_method=LOGIN
sasl_username=user@example.net
```

Successful TLS delivery to an upstream relay can look like:

```text
tls=encrypt
dsn=2.0.0
status=sent
```

### Check Dynamic DNS

```bash
docker exec smtp-relay \
  getent ahostsv4 mail.example.net
```

### Check Dynamic Client map

```bash
docker exec smtp-relay \
  cat /data/dynamic-client.cidr
```

### Check Postfix client restrictions

```bash
docker exec smtp-relay \
  postconf smtpd_client_restrictions
```

### Check Supervisor

```bash
docker exec smtp-relay supervisorctl status
```

### Check container health

```bash
docker inspect \
  --format='{{json .State.Health}}' \
  smtp-relay
```

### Test SMTP

A simple SMTP client is embedded in the image:

```bash
docker exec -it smtp-relay \
  /opt/smtp_client.py \
  -s test \
  -f noreply@domain.com \
  --user user1:password1 \
  admin@domain.com
```

## Security recommendations

For SMTP relays exposed to the Internet:

* Do not use `RELAY_MYNETWORKS=0.0.0.0/0` as a general trust mechanism.
* Prefer SASL authentication for external SMTP clients.
* Use Dynamic DNS client filtering as an additional security layer when the authorized server has a dynamic public IP.
* Keep `RELAY_MYNETWORKS` limited to networks that should actually be trusted.
* Require TLS to a known upstream smart host where supported:

```text
smtp_tls_security_level = encrypt
```

* Enable incoming STARTTLS when SMTP AUTH is used over the Internet.
* Prevent unencrypted SMTP authentication:

```text
smtpd_tls_auth_only = yes
```

* Use long and unique SASL passwords.
* Protect the persistent `/data` volume because it contains SASL authentication data.
* Mount external scripts read-only.
* Monitor Postfix logs for failed SASL authentication and rejected clients.

## Todo

* Improve SMTP application-level health check
* Add Prometheus exporters:
  * [rsyslog_exporter](https://github.com/engage-ehs/rsyslog_exporter)
  * [postfix_exporter](https://github.com/kumina/postfix_exporter)
* Add automated tests for Dynamic DNS updates
* Add IPv6 support to the Dynamic DNS client filter
* Extend incoming STARTTLS examples
