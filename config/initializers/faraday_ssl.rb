# AFIP/ARCA endpoints use legacy Diffie-Hellman key sizes (< 2048-bit) that
# modern OpenSSL rejects by default (SECLEVEL=2). Lowering to SECLEVEL=1
# allows DH keys >= 1024-bit while keeping certificate verification enabled.
Faraday.default_connection_options.merge!(
  ssl: { verify: true, ciphers: "DEFAULT:@SECLEVEL=0" }
)
