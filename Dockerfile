FROM alpine:3.22

LABEL org.opencontainers.image.title="unbound-mikrotik" \
      org.opencontainers.image.description="Small Unbound recursive resolver image tuned for MikroTik RouterOS containers"

RUN apk add --no-cache \
      unbound \
    && mkdir -p /etc/unbound /var/lib/unbound /run/unbound \
    && chown -R unbound:unbound /var/lib/unbound /run/unbound

COPY unbound/unbound.conf /etc/unbound/unbound.conf
COPY unbound/root.hints /etc/unbound/root.hints
COPY unbound/root.key /etc/unbound/root.key
COPY unbound/root.key /var/lib/unbound/root.key
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN chmod 0755 /usr/local/bin/docker-entrypoint.sh \
    && chmod 0644 /etc/unbound/unbound.conf /etc/unbound/root.hints /etc/unbound/root.key /var/lib/unbound/root.key \
    && chown -R unbound:unbound /var/lib/unbound /run/unbound \
    && unbound-checkconf /etc/unbound/unbound.conf

EXPOSE 53/tcp 53/udp

STOPSIGNAL SIGTERM

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["unbound"]
