#!/usr/bin/env bash
# Sukuria savadarbį (self-signed) macOS pasirašymo sertifikatą „POM Self-Signed“.
#
# KODĖL to reikia. Vietinis (ad-hoc) parašas keičiasi po kiekvieno perkompiliavimo,
# todėl macOS kaskart mato tarsi visai kitą programą. Dėl to:
#   1. pranešimų sistema atsisako registruoti POM („Notifications are not allowed“);
#   2. raktinės leidimas „Visada leisti“ neišlieka ir klausiama iš naujo.
# Pastovus savadarbis sertifikatas abi bėdas išsprendžia, nes parašas nebesikeičia.
#
# Sertifikatas lieka tik tavo kompiuteryje: privatus raktas guli login raktinėje ir
# į saugyklą niekada nepatenka. Būsena „NOT_TRUSTED“ čia normali – ji liečia tik
# Gatekeeper (programa nenotarizuota Apple), o ne raktinę ar pranešimus.
#
# Paleisti reikia vieną kartą, prieš pirmą `./scripts/bundle.sh`.

set -euo pipefail

IDENTITY="POM Self-Signed"

if security find-identity -p codesigning | grep -q "$IDENTITY"; then
  echo "Tapatybė \"$IDENTITY\" jau yra, nieko nedarau."
  security find-identity -p codesigning | grep "$IDENTITY"
  exit 0
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

cat >"$TMP/cert.cnf" <<'EOF'
[req]
distinguished_name = dn
x509_extensions = v3
prompt = no
[dn]
CN = POM Self-Signed
[v3]
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
basicConstraints = critical, CA:false
EOF

openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "$TMP/cert.key" -out "$TMP/cert.crt" -days 3650 -config "$TMP/cert.cnf" 2>/dev/null

# -legacy: macOS neperskaito OpenSSL 3 numatytojo PKCS12 apsaugos formato.
openssl pkcs12 -export -legacy \
  -inkey "$TMP/cert.key" -in "$TMP/cert.crt" -name "$IDENTITY" \
  -out "$TMP/cert.p12" -passout pass:pom 2>/dev/null

# -T /usr/bin/codesign -A: leidžia pasirašymo komandai naudoti raktą be atskiro klausimo.
security import "$TMP/cert.p12" \
  -k "$HOME/Library/Keychains/login.keychain-db" -P "pom" \
  -T /usr/bin/codesign -A

echo
echo "Sukurta tapatybė \"$IDENTITY\"."
security find-identity -p codesigning | grep "$IDENTITY"
echo
echo "Dabar paleisk: ./scripts/bundle.sh && ./scripts/install.sh"
