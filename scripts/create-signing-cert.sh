#!/bin/bash
# Create a stable self-signed code-signing identity so macOS TCC grants
# (Screen Recording, Accessibility, etc.) survive rebuilds.
#
# Run once. After that, scripts/build.sh signs with this identity and
# permissions persist across rebuilds.

set -euo pipefail

CERT_NAME="CleanX Developer"
KEYCHAIN="${HOME}/Library/Keychains/login.keychain-db"

if security find-identity -p codesigning -v "${KEYCHAIN}" 2>/dev/null | grep -q "${CERT_NAME}"; then
    echo "✓ Identity '${CERT_NAME}' already exists in login keychain."
    exit 0
fi

WORKDIR="$(mktemp -d)"
trap "rm -rf '${WORKDIR}'" EXIT
cd "${WORKDIR}"

cat > openssl.cnf <<'EOF'
[ req ]
default_bits        = 2048
prompt              = no
default_md          = sha256
distinguished_name  = dn
x509_extensions     = v3_ext

[ dn ]
CN = CleanX Developer

[ v3_ext ]
basicConstraints       = critical, CA:FALSE
keyUsage               = critical, digitalSignature
extendedKeyUsage       = critical, codeSigning
1.2.840.113635.100.6.1.13 = critical, ASN1:NULL
EOF

openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout key.pem -out cert.pem \
    -days 3650 -config openssl.cnf >/dev/null 2>&1

openssl pkcs12 -export -legacy -inkey key.pem -in cert.pem \
    -name "${CERT_NAME}" -out cert.p12 -passout pass:cleanx >/dev/null 2>&1

security import cert.p12 -k "${KEYCHAIN}" -P cleanx \
    -T /usr/bin/codesign -T /usr/bin/security >/dev/null

# Trust the cert for code signing.
security add-trusted-cert -d -r trustAsRoot -k "${KEYCHAIN}" cert.pem 2>/dev/null || \
    echo "(skip trust step — already trusted or requires admin password)"

# Allow codesign to access without prompting.
security set-key-partition-list -S apple-tool:,apple: -s -k "" "${KEYCHAIN}" >/dev/null 2>&1 || true

echo "✓ Created code-signing identity '${CERT_NAME}'."
security find-identity -p codesigning -v "${KEYCHAIN}" | grep "${CERT_NAME}" || true
