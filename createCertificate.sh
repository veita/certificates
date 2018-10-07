#!/bin/bash

#-------------------------------------------------------------------------------

DNS_1="host.example.org"

DN_COUNTRY="DE"
DN_STATE="Baden-Württemberg"
DN_LOCALITY="Freiburg i. Br."
DN_ORGANIZATION="Die Firma"
VALIDITY_YEARS=5

#-------------------------------------------------------------------------------

DIR_NAME="$DNS_1"
FILE_NAME="$DNS_1"

PASSWORD_FILE="${DIR_NAME}/${FILE_NAME}-password.txt"
PKEY_FILE="${DIR_NAME}/${FILE_NAME}.pkey"
CSR_FILE="${DIR_NAME}/${FILE_NAME}.csr"
CERT_PEM_FILE="${DIR_NAME}/${FILE_NAME}.pem"
CERT_DER_FILE="${DIR_NAME}/${FILE_NAME}.der"
PKCS12_FILE="${DIR_NAME}/${FILE_NAME}.p12"
CFG_FILE="${DIR_NAME}/${FILE_NAME}-extensions.cfg"
FINGERPRINT_FILE="${DIR_NAME}/${FILE_NAME}-fingerprint.txt"

#-------------------------------------------------------------------------------

P_OK="\033[1;32m[OK]\033[0m"

mkdir $DIR_NAME || exit 1

# Generate and save password
PASSWORD=$(openssl rand -base64 33)
printf "%s\n%s" "${PASSWORD}" "${PASSWORD}" > "$PASSWORD_FILE"
chmod 600 "$PASSWORD_FILE"
printf "$P_OK Random password in\n     %s\n" "${PASSWORD_FILE}"

# Generate password-protected private key
openssl genpkey                 \
 -algorithm RSA                 \
 -pkeyopt rsa_keygen_bits:3072  \
 -aes-256-cbc                   \
 -pass file:"$PASSWORD_FILE"    \
 -out "$PKEY_FILE"              \
 -outform PEM                   \
 || exit 1
chmod 600 "$PKEY_FILE"
printf "$P_OK Password-protected private key in\n     %s\n" "${PKEY_FILE}"

# Create an extension configuration
cat > "$CFG_FILE" << EOT
[ req ]
prompt             = no
default_bits       = 3072
default_keyfile    = ${PKEY_FILE}
distinguished_name = distinguished_name_req
req_extensions     = v3_req
x509_extensions    = v3_req

[ distinguished_name_req ]
C=${DN_COUNTRY}
ST=${DN_STATE}
L=${DN_LOCALITY}
O=${DN_ORGANIZATION}
CN=${DNS_1}

[ v3_req ]
basicConstraints = CA:FALSE
keyUsage         = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName   = @alt_names

[ alt_names ]
DNS.1 = ${DNS_1}
#DNS.2 = host2.example.org
#DNS.3 = host3.example.org
EOT

# Create the certificate request
openssl req                    \
 -key "$PKEY_FILE"             \
 -passin file:"$PASSWORD_FILE" \
 -keyform PEM                  \
 -new -sha256                  \
 -utf8                         \
 -config "$CFG_FILE"           \
 -out "$CSR_FILE"              \
 || exit 1
chmod 640 "$CSR_FILE"
printf "$P_OK CSR\n     %s\n" "${CSR_FILE}"

# Self sign the request and export the certificate to different formats
openssl x509                     \
 -signkey "$PKEY_FILE"           \
 -passin file:"$PASSWORD_FILE"   \
 -in "$CSR_FILE"                 \
 -req -sha256                    \
 -days $((365 * VALIDITY_YEARS)) \
 -extfile "$CFG_FILE"            \
 -extensions v3_req              \
 -out "$CERT_PEM_FILE"           \
 || exit 1
chmod 640 "$CERT_PEM_FILE"
printf "$P_OK Certificate\n     %s\n" "${CERT_PEM_FILE}"

openssl x509           \
 -in "$CERT_PEM_FILE"  \
 -outform DER          \
 -out "$CERT_DER_FILE" \
 || exit 1
chmod 640 "$CERT_DER_FILE"
printf "$P_OK Certificate exported to\n     %s\n" "${CERT_DER_FILE}"

openssl pkcs12                  \
 -inkey "$PKEY_FILE"            \
 -in "$CERT_PEM_FILE"           \
 -passin file:"$PASSWORD_FILE"  \
 -export -out "$PKCS12_FILE"    \
 -passout file:"$PASSWORD_FILE" \
 || exit1
chmod 600 "$PKCS12_FILE"
printf "$P_OK Certificate and private key exported to\n     %s\n" "${PKCS12_FILE}"

# Create fingerprints
openssl x509 -sha256 -in "$CERT_PEM_FILE" -noout -fingerprint  > "$FINGERPRINT_FILE"
openssl x509 -sha1   -in "$CERT_PEM_FILE" -noout -fingerprint >> "$FINGERPRINT_FILE"
chmod 640 "$FINGERPRINT_FILE"
printf "$P_OK Certificate fingerprints in\n     %s\n" "${FINGERPRINT_FILE}"

# Display the certificate
printf "Display the certificate? [Y/n] "
read ANSWER; ANSWER=${ANSWER:=y}
if [ "$ANSWER" = "y" ] || [ "$ANSWER" = "Y" ];
then
    openssl x509 -text -noout -in "$CERT_PEM_FILE" | less
fi

