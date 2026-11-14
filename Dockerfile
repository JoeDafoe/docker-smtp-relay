FROM alpine:3.24.4

LABEL org.opencontainers.image.authors="JoeDafoe"

ENV RELAY_MYDOMAIN=domain.com \
    RELAY_MYNETWORKS=127.0.0.0/8 \
    RELAY_HOST=[127.0.0.1]:25 \
    RELAY_USE_TLS=yes \
    RELAY_TLS_VERIFY=may \
    RELAY_DOMAINS=\$mydomain \
    RELAY_STRICT_SENDER_MYDOMAIN=true \
    RELAY_MODE=STRICT \
    RELAY_TLS_CA=/etc/ssl/certs/ca-certificates.crt \
    POSTCONF_inet_interfaces=all \
    POSTCONF_inet_protocols=ipv4

RUN apk add ---no-cache \
        ca-certificates\
        cyrus-sasl \
        cyrus-sasl-crammd5 \
        cyrus-sasl-digestmd5 \
        cyrus-sasl-login \
        cyrus-sasl-ntlm \
        postfix \
        rsyslog \
        supervisor \
        tzdata \
    && update-ca-certificates

RUN postconf -e 'notify_classes = bounce, 2bounce, data, delay, policy, protocol, resource, software' \
    && postconf -e 'bounce_notice_recipient = $2bounce_notice_recipient' \
    && postconf -e 'message_size_limit = 52428800' \
    && postconf -e 'delay_notice_recipient = $2bounce_notice_recipient' \
    && postconf -e 'error_notice_recipient = $2bounce_notice_recipient' \
    && postconf -e 'myorigin = $mydomain' \
    && postconf -e 'smtpd_sasl_auth_enable = yes' \
    && postconf -e 'smtpd_sasl_type = cyrus' \
    && postconf -e 'smtpd_sasl_local_domain = $mydomain' \
    && postconf -e 'smtpd_sasl_security_options = noanonymous' \
    && postconf -e 'smtpd_banner = $myhostname ESMTP $mail_name RELAY' \
    && postconf -e 'smtputf8_enable = no' \
    && mkdir -p /etc/sasl2 \
    && printf '%s\n' \
        'pwcheck_method: auxprop' \
        'auxprop_plugin: sasldb' \
        'mech_list: PLAIN LOGIN CRAM-MD5 DIGEST-MD5' \
        'sasldb_path: /data/sasldb2' \
        'log_level: 2' \
        > /etc/sasl2/smtpd.conf

COPY root/etc/ /etc/
COPY root/opt/ /opt/
COPY docker-entrypoint.d/ /docker-entrypoint.d/
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN find /docker-entrypoint.d -type f -name '*.sh' -exec chmod 0755 {} + \
    && chmod 0755 /usr/local/bin/docker-entrypoint.sh \
    && touch /etc/postfix/aliases \
    && touch /etc/postfix/sender_canonical \
    && mkdir -p /data \
    && mkdir -p /etc/supervisor.d \
    && mkdir -p /external-scripts

EXPOSE 25/tcp

VOLUME ["/data", "/var/spool/postfix"]

WORKDIR /data

HEALTHCHECK \
    --interval=10s \
    --timeout=3s \
    --start-period=10s \
    --retries=3 \
    CMD nc -z -w 2 127.0.0.1 25 || exit 1

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

CMD ["/usr/bin/supervisord", "--nodaemon", "--configuration", "/etc/supervisord.conf"]
