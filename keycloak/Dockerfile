# Keycloak para demonstracao (modo dev, banco interno). O realm "eventos" e importado na subida.
# FRONTEND_URL define a URL permitida para login/logout do front-end.
FROM quay.io/keycloak/keycloak:26.0
COPY realm-eventos.json /opt/keycloak/data/import/realm-eventos.json
ENV FRONTEND_URL=http://localhost:5173 \
    KC_HTTP_ENABLED=true \
    KC_PROXY_HEADERS=xforwarded \
    KC_HOSTNAME_STRICT=false \
    JAVA_OPTS_KC_HEAP="-Xms64m -Xmx320m"
EXPOSE 8080
ENTRYPOINT ["/opt/keycloak/bin/kc.sh", "start-dev", "--import-realm"]
