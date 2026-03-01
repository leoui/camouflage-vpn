# 🛡️ Camouflage — Hardened OpenVPN Installer

<div align="center">

**Installer OpenVPN "road warrior" dengan keamanan tingkat tinggi — Bahasa Indonesia**

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Easy-RSA](https://img.shields.io/badge/Easy--RSA-v3.2.5-blue.svg)](https://github.com/OpenVPN/easy-rsa)
[![OpenVPN](https://img.shields.io/badge/OpenVPN-2.6.x-orange.svg)](https://openvpn.net/)
[![Shell](https://img.shields.io/badge/Shell-Bash-lightgrey.svg)]()

</div>

## Apa itu Camouflage?

Camouflage adalah installer OpenVPN otomatis yang didesain untuk keamanan maksimal. Dalam waktu kurang dari 2 menit, kamu bisa punya server VPN pribadi dengan enkripsi kelas militer.

Berdasarkan karya [Nyr](https://github.com/Nyr/openvpn-install) dan [Angristan](https://github.com/angristan/openvpn-install), ditulis ulang dengan fokus pada:
- 🔒 **Security hardening** tingkat lanjut
- 🇮🇩 **Antarmuka Bahasa Indonesia** penuh
- ⚡ **Instalasi cepat** tanpa konfigurasi manual
- 🎨 **UI terminal berwarna** yang informatif

## Fitur Utama

### 🔐 Keamanan

| Fitur | Deskripsi |
|---|---|
| **AES-256-GCM** | Cipher AEAD modern dengan hardware acceleration |
| **CHACHA20-POLY1305** | Cipher alternatif untuk device tanpa AES-NI |
| **tls-crypt** | Enkripsi + autentikasi seluruh control channel |
| **TLS 1.2+ enforced** | Memblokir koneksi dengan TLS lama |
| **TLS 1.3 ciphersuites** | Konfigurasi cipher TLS 1.3 eksplisit |
| **SHA-512 HMAC** | Hash authentication untuk control channel |
| **data-ciphers** | Negosiasi cipher modern (bukan `--cipher` deprecated) |
| **RFC 7919 DH** | Parameter Diffie-Hellman yang diaudit publik |
| **CRL verification** | Certificate Revocation List untuk pembatalan akses |
| **remote-cert-tls** | Verifikasi tipe sertifikat client/server |
| **block-outside-dns** | Mencegah DNS leak pada Windows |
| **explicit-exit-notify** | Clean disconnect untuk UDP |
| **IPv6 leak protection** | Opsi disable IPv6 untuk mencegah leak |

### 🎛️ Tiga Level Keamanan

1. **Standard** — Cocok untuk semua client OpenVPN 2.4+
   - `data-ciphers AES-256-GCM:AES-128-GCM:CHACHA20-POLY1305`
   - `tls-version-min 1.2`

2. **Hardened** ⭐ (direkomendasikan) — Tambahan TLS cipher hardening
   - `data-ciphers AES-256-GCM:CHACHA20-POLY1305` (tanpa AES-128)
   - `tls-cipher` & `tls-ciphersuites` eksplisit
   - Session timeout opsional
   - Logging ke file terpisah

3. **Paranoid** — Keamanan maksimal (bisa inkompatibel dengan client lama)
   - Strict TLS cipher (hanya AES-256-GCM SHA384)
   - `max-clients` limiter
   - Session timeout opsional

### 🖥️ Sistem Operasi

- Ubuntu 20.04, 22.04, 24.04+
- Debian 11, 12+
- AlmaLinux 8, 9+
- Rocky Linux 8, 9+
- CentOS Stream 8, 9+
- Fedora 38+

### 🌐 DNS Options (8 pilihan)

1. DNS Sistem
2. Cloudflare (1.1.1.1) — cepat, privacy-focused
3. Google (8.8.8.8) — stabil
4. OpenDNS (208.67.222.222) — dengan filter
5. Quad9 (9.9.9.9) — security + privacy
6. AdGuard DNS (94.140.14.14) — blokir iklan
7. Cloudflare Malware Blocking (1.1.1.2)
8. Custom DNS

### 📋 Manajemen Client (6 menu)

1. Tambah user baru (dengan validasi duplikat)
2. Batalkan akses user (revoke + CRL update)
3. Lihat daftar client aktif & revoked
4. Lihat status server & koneksi aktif
5. Hapus OpenVPN sepenuhnya
6. Keluar

## Instalasi

```bash
curl -O https://raw.githubusercontent.com/leoui/camouflage-vpn/main/camouflage-vpn.sh
chmod +x camouflage-vpn.sh
sudo bash camouflage-vpn.sh
```

## Penggunaan

### Menambah Client

```bash
sudo bash camouflage-vpn.sh
# Pilih opsi 1
```

### Melihat Status

```bash
sudo bash camouflage-vpn.sh
# Pilih opsi 4
```

### Cek Manual

```bash
# Status service
systemctl status openvpn-server@server.service

# Log real-time
journalctl -fu openvpn-server@server.service

# Log file
tail -f /var/log/openvpn/camouflage.log

# Client aktif
cat /var/log/openvpn/openvpn-status.log
```

## Perbandingan dengan Script Asli

| Komponen | Script Asli (2020) | Camouflage v2.0 (2026) |
|---|---|---|
| Easy-RSA | v3.0.6 | **v3.2.5** |
| TLS Protection | tls-auth | **tls-crypt** |
| Data Cipher | `cipher AES-256-CBC` | **`data-ciphers AES-256-GCM:CHACHA20-POLY1305`** |
| TLS Version | Tidak dibatasi | **tls-version-min 1.2** |
| TLS Ciphers | Default | **Hardened TLS 1.2 + 1.3 suites** |
| DH Params | `openssl dhparam` (lambat) | **Embedded RFC 7919** |
| Firewall | rc.local | **Systemd service** |
| Config Path | /etc/openvpn/ | **/etc/openvpn/server/** |
| OS Support | 3 distro | **6 distro** (+ versi min check) |
| DNS | 5 pilihan | **8 pilihan** (+ custom) |
| IPv6 | Tidak ada | **IPv6 support + leak protection** |
| Security Levels | Tidak ada | **3 level** (Standard/Hardened/Paranoid) |
| Max Clients | Tidak ada | **Configurable** |
| Session Timeout | Tidak ada | **Configurable** |
| Client Mgmt | 4 menu | **6 menu** (+ status, + client list) |
| Logging | Minimal | **File terpisah + status v2** |
| UI | Plain text | **Colored terminal UI** |
| Cert Verification | Tidak ada | **remote-cert-tls** |
| DNS Leak | Tidak ada | **block-outside-dns** |
| Input Validation | Minimal | **Full regex + duplicate check** |
| NAT Detection | Manual | **Auto-detect** |
| Buffer | sndbuf 0 / rcvbuf 0 | **OS default** |

## Menggunakan File .ovpn

| Platform | Aplikasi |
|---|---|
| **Windows** | [OpenVPN GUI](https://openvpn.net/community-downloads/) / [OpenVPN Connect](https://openvpn.net/vpn-client/) |
| **macOS** | [Tunnelblick](https://tunnelblick.net/) / OpenVPN Connect |
| **Linux** | `sudo openvpn --config client.ovpn` |
| **Android** | [OpenVPN for Android](https://play.google.com/store/apps/details?id=de.blinkt.openvpn) |
| **iOS** | [OpenVPN Connect](https://apps.apple.com/app/openvpn-connect/id590379981) |

## Struktur File

```
/etc/openvpn/server/
├── server.conf          # Konfigurasi server
├── ca.crt / ca.key      # Certificate Authority
├── server.crt / .key    # Sertifikat server
├── dh.pem               # DH parameters (RFC 7919)
├── tc.key               # TLS-crypt key
├── crl.pem              # Certificate Revocation List
├── client-common.txt    # Template client config
├── ipp.txt              # IP persistence
└── easy-rsa/            # Easy-RSA v3.2.5 PKI
    └── pki/
        ├── issued/      # Client certificates
        ├── private/     # Client private keys
        └── index.txt    # Certificate database

/var/log/openvpn/
├── camouflage.log          # Server log
└── openvpn-status.log      # Status & koneksi aktif

/etc/systemd/system/
└── openvpn-iptables.service  # Firewall rules (non-firewalld)
```

## Troubleshooting

### Service gagal start
```bash
journalctl -xeu openvpn-server@server.service
```

### Client tidak bisa connect
1. Pastikan port terbuka: `ss -tulnp | grep openvpn`
2. Cek firewall: `iptables -L -n -t nat`
3. Cek log: `tail -50 /var/log/openvpn/camouflage.log`

### Cipher mismatch
Jika client lama tidak bisa connect dengan level Hardened/Paranoid, turunkan ke Standard atau update client ke OpenVPN 2.5+.

## Keamanan

Jika kamu menemukan masalah keamanan, silakan buka issue dengan label `security`.

## Lisensi

MIT License — Lihat [LICENSE](LICENSE).

## Kredit

- [Nyr/openvpn-install](https://github.com/Nyr/openvpn-install)
- [Angristan/openvpn-install](https://github.com/angristan/openvpn-install)
- [OpenVPN/easy-rsa](https://github.com/OpenVPN/easy-rsa)
- [OpenVPN Community](https://community.openvpn.net/)
