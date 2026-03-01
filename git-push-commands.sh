#!/bin/bash
# ╔═══════════════════════════════════════════════════════════╗
# ║  Perintah Git untuk push Camouflage VPN ke GitHub        ║
# ╚═══════════════════════════════════════════════════════════╝
#
# PERSIAPAN:
# 1. Buat repo baru di https://github.com/new
#    Nama: camouflage-vpn
#    Deskripsi: 🛡️ Hardened OpenVPN road warrior installer — Bahasa Indonesia
#    JANGAN centang "Add a README"
#
# 2. Konfigurasi git (jika belum):

git config --global user.name "Lewi Verdatama"
git config --global user.email "iam@leoui.me"

# 3. Jalankan perintah berikut:

cd /path/to/camouflage    # Ganti path

git init
git add -A
git commit -m "🛡️ Camouflage v2.0.0 — Hardened OpenVPN Installer

Fitur utama:
- Easy-RSA v3.2.5 (kompatibel OpenSSL 3)
- tls-crypt (enkripsi + auth control channel)
- data-ciphers AES-256-GCM:CHACHA20-POLY1305 (bukan cipher deprecated)
- TLS 1.2 minimum + TLS 1.3 ciphersuites hardening
- SHA-512 HMAC authentication
- Embedded RFC 7919 DH parameters (instan, tanpa generate)
- Systemd iptables service (bukan rc.local)
- IPv6 support + leak protection
- DNS leak protection (block-outside-dns)
- 3 level keamanan: Standard / Hardened / Paranoid
- Max client limiter (Paranoid)
- Session timeout opsional (Hardened+)
- Logging ke file terpisah (/var/log/openvpn/)
- 8 DNS options termasuk AdGuard, Quad9, custom
- 6 menu manajemen (tambah, revoke, list, status, hapus)
- Colored terminal UI
- Dukungan Ubuntu, Debian, AlmaLinux, Rocky, CentOS, Fedora
- Auto-detect IP public untuk NAT
- Full input validation + duplicate check
- remote-cert-tls client/server verification
- explicit-exit-notify untuk UDP
- Copyright 2026"

git branch -M main
git remote add origin https://github.com/leoui/camouflage-vpn.git  # GANTI USERNAME
git push -u origin main

# Opsional: buat release tag
git tag -a v2.0.0 -m "v2.0.0 — Initial release: Hardened OpenVPN Installer"
git push origin v2.0.0

# =====================================================================
# Kalau mau pakai SSH:
# git remote add origin git@github.com:USERNAME/camouflage-vpn.git
# =====================================================================
