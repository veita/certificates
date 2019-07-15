#!/bin/bash

BN="host.example.org"
DIR=${BN}

# PKCS7 Zertifikatskette nach PEM konvertieren
openssl pkcs7                    \
    -inform PEM                  \
    -outform PEM                 \
    -in ${DIR}/b64/${BN}.p7b     \
    -print_certs                 \
    > ${DIR}/${BN}-chain.pem


# Privaten Schlüssel und Zertifikat in PKCS12-Datei überführen
openssl pkcs12 -export                      \
    -name "${BM}-certificate+key-pair"      \
    -out ${DIR}/${BN}-signed.p12            \
    -inkey ${DIR}/${BN}.pkey                \
    -in ${DIR}/${BN}-chain.pem              \
    -passin file:${DIR}/${BN}-password.txt  \
    -passout file:${DIR}/${BN}-password.txt

