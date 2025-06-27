# inwx-dns-auth

A fully automated DNS challenge hook script for the INWX DNS API, designed for use with Let’s Encrypt and ACME-compatible clients (e.g., TrueNAS SCALE, acme.sh, Certbot, dehydrated).  
Supports both `deploy_challenge`/`clean_challenge` (RFC 8555) and `set`/`unset` modes for compatibility with TrueNAS "Custom Script" ACME integration.

## ✨ Features

- 🔑 Fully automatic DNS-01 challenge handling via INWX
- 🖥️ Compatible with TrueNAS SCALE ACME Certificate UI
- 🧰 Supports both ACME and legacy CLI hook formats
- 🕓 Built-in wait for DNS propagation before validation
- 📜 Clean logging to `/tmp/inwx-acme.log`
- ✅ Written in pure Bash, no dependencies beyond standard tools

## 🔧 Requirements

- `jq`
- `dig` (usually in `bind9-utils` or `dnsutils`)
- A registered domain managed by [inwx.com](https://www.inwx.com/)
- An INWX user with API access enabled

## 🚀 Usage

### 1. Clone or copy the script

```bash
chmod +x inwx-dns-auth.sh
