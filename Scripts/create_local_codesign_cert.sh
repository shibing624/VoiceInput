#!/usr/bin/env bash
set -euo pipefail

CERT_NAME="${CERT_NAME:-VoiceInput Local Code Signing}"
KEYCHAIN_PATH="${KEYCHAIN_PATH:-$HOME/Library/Keychains/login.keychain-db}"
VALID_DAYS="${VALID_DAYS:-3650}"

if security find-identity -v -p codesigning 2>/dev/null | rg -F "\"${CERT_NAME}\"" >/dev/null; then
  echo "Certificate already exists and is usable:"
  echo "  ${CERT_NAME}"
  exit 0
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

CONFIG_PATH="${TMP_DIR}/openssl.cnf"
KEY_PATH="${TMP_DIR}/codesign.key.pem"
CERT_PATH="${TMP_DIR}/codesign.cert.pem"
P12_PATH="${TMP_DIR}/codesign.p12"
P12_PASSWORD="voiceinput-local-codesign"

if security find-certificate -a -c "${CERT_NAME}" "${KEYCHAIN_PATH}" >/dev/null 2>&1; then
  security find-certificate -a -c "${CERT_NAME}" -p "${KEYCHAIN_PATH}" > "${CERT_PATH}"
  security add-trusted-cert -k "${KEYCHAIN_PATH}" -r trustRoot "${CERT_PATH}" >/dev/null

  if security find-identity -v -p codesigning 2>/dev/null | rg -F "\"${CERT_NAME}\"" >/dev/null; then
    echo "Certificate was present and is now trusted:"
    echo "  ${CERT_NAME}"
    exit 0
  fi
fi

cat > "${CONFIG_PATH}" <<EOF
[req]
prompt = no
distinguished_name = dn
x509_extensions = ext

[dn]
CN = ${CERT_NAME}
O = Local Development
OU = VoiceInput

[ext]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
EOF

echo "Generating local code signing certificate:"
echo "  ${CERT_NAME}"
openssl genrsa -out "${KEY_PATH}" 2048 >/dev/null 2>&1
openssl req -new -x509 \
  -key "${KEY_PATH}" \
  -out "${CERT_PATH}" \
  -days "${VALID_DAYS}" \
  -config "${CONFIG_PATH}" \
  -sha256 >/dev/null 2>&1

openssl pkcs12 -export \
  -legacy \
  -inkey "${KEY_PATH}" \
  -in "${CERT_PATH}" \
  -out "${P12_PATH}" \
  -name "${CERT_NAME}" \
  -passout "pass:${P12_PASSWORD}" >/dev/null 2>&1

security import "${P12_PATH}" \
  -k "${KEYCHAIN_PATH}" \
  -P "${P12_PASSWORD}" \
  -T /usr/bin/codesign \
  -T /usr/bin/security >/dev/null

security add-trusted-cert -k "${KEYCHAIN_PATH}" -r trustRoot "${CERT_PATH}" >/dev/null

echo "Imported into:"
echo "  ${KEYCHAIN_PATH}"
echo ""
echo "Available code signing identities:"
security find-identity -v -p codesigning
