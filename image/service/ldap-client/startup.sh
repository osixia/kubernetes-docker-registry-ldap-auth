#!/bin/bash -e

# set -x (bash debug) if log level is trace
# https://github.com/osixia/docker-light-baseimage/blob/stable/image/tool/log-helper
log-helper level eq trace && set -x

www_data_homedir=$( getent passwd "www-data" | cut -d: -f6 )

FIRST_START_DONE="${CONTAINER_STATE_DIR}/docker-ldap-client-first-start-done"
# container first start
if [ ! -e "$FIRST_START_DONE" ]; then

  if [ "${REGISTRY_LDAP_AUTH_LDAP_CLIENT_TLS,,}" == "true" ]; then

    # generate a certificate and key if files don't exists
    # https://github.com/osixia/docker-light-baseimage/blob/stable/image/service-available/:cfssl/assets/tool/cfssl-helper
    cfssl-helper ${LDAP_CLIENT_CFSSL_PREFIX} "${CONTAINER_SERVICE_DIR}/ldap-client/assets/certs/${REGISTRY_LDAP_AUTH_LDAP_CLIENT_TLS_CRT_FILENAME}" "${CONTAINER_SERVICE_DIR}/ldap-client/assets/certs/${REGISTRY_LDAP_AUTH_LDAP_CLIENT_TLS_KEY_FILENAME}" "${CONTAINER_SERVICE_DIR}/ldap-client/assets/certs/${REGISTRY_LDAP_AUTH_LDAP_CLIENT_TLS_CA_CRT_FILENAME}"

    # ldap client config
    sed -i --follow-symlinks "s,TLS_CACERT.*,TLS_CACERT ${CONTAINER_SERVICE_DIR}/ldap-client/assets/certs/${REGISTRY_LDAP_AUTH_LDAP_CLIENT_TLS_CA_CRT_FILENAME},g" /etc/ldap/ldap.conf
    echo "TLS_REQCERT $REGISTRY_LDAP_AUTH_LDAP_CLIENT_TLS_REQCERT" >> /etc/ldap/ldap.conf
    cp -f /etc/ldap/ldap.conf ${CONTAINER_SERVICE_DIR}/ldap-client/assets/ldap.conf

    [[ -f "$www_data_homedir/.ldaprc" ]] && rm -f $www_data_homedir/.ldaprc
    echo "TLS_CERT ${CONTAINER_SERVICE_DIR}/ldap-client/assets/certs/${REGISTRY_LDAP_AUTH_LDAP_CLIENT_TLS_CRT_FILENAME}" > $www_data_homedir/.ldaprc
    echo "TLS_KEY ${CONTAINER_SERVICE_DIR}/ldap-client/assets/certs/${REGISTRY_LDAP_AUTH_LDAP_CLIENT_TLS_KEY_FILENAME}" >> $www_data_homedir/.ldaprc
    cp -f $www_data_homedir/.ldaprc ${CONTAINER_SERVICE_DIR}/ldap-client/assets/.ldaprc

    chown www-data:www-data -R ${CONTAINER_SERVICE_DIR}/ldap-client/assets/certs/

    sed -i "s/#LDAPTrustedClientCert/LDAPTrustedClientCert/g" ${CONTAINER_SERVICE_DIR}/apache2/assets/sites-available/registry-proxy.conf

    sed -i "s/#LDAPTrustedGlobalCert/LDAPTrustedGlobalCert/g" ${CONTAINER_SERVICE_DIR}/apache2/assets/conf-available/registry-proxy.conf
    sed -i "s/#LDAPVerifyServerCert/LDAPVerifyServerCert/g" ${CONTAINER_SERVICE_DIR}/apache2/assets/conf-available/registry-proxy.conf
    sed -i "s/#LDAPTrustedMode/LDAPTrustedMode/g" ${CONTAINER_SERVICE_DIR}/apache2/assets/conf-available/registry-proxy.conf
  fi

  touch $FIRST_START_DONE
fi

ln -sf ${CONTAINER_SERVICE_DIR}/ldap-client/assets/.ldaprc $www_data_homedir/.ldaprc
ln -sf ${CONTAINER_SERVICE_DIR}/ldap-client/assets/ldap.conf /etc/ldap/ldap.conf

exit 0