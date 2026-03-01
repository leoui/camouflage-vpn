# 🕵️ Camouflage VPN

<div align="center">

![Version](https://img.shields.io/badge/version-2.1-blue?style=flat-square)
![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)
![OpenVPN](https://img.shields.io/badge/OpenVPN-2.5%2B-orange?style=flat-square)
![Easy-RSA](https://img.shields.io/badge/Easy--RSA-3.2.5-purple?style=flat-square)
![Bash](https://img.shields.io/badge/bash-5.0%2B-yellow?style=flat-square)

**Hardened OpenVPN Installer untuk Linux — Camouflage VPN dengan keamanan enterprise**

*Berdasarkan karya [Nyr](https://github.com/Nyr/openvpn-install) dan [Angristan](https://github.com/angristan/openvpn-install)*

</div>

---

## 📋 Daftar Isi

- [Fitur](#-fitur)
- [Distro yang Didukung](#-distro-yang-didukung)
- [Prasyarat](#-prasyarat)
- [Instalasi Cepat](#-instalasi-cepat)
- [Level Keamanan](#-level-keamanan)
- [Konfigurasi Kriptografi](#-konfigurasi-kriptografi)
- [Manajemen Client](#-manajemen-client)
- [Struktur File](#-struktur-file)
- [Kompatibilitas VPS](#-kompatibilitas-vps)
- [Troubleshooting](#-troubleshooting)
- [Perbedaan dari Versi Asli](#-perbedaan-dari-versi-asli)
- [Lisensi](#-lisensi)

---

## ✨ Fitur

### Keamanan
| Fitur | Detail |
|-------|--------|
| **TLS Control Channel** | `tls-crypt` — enkripsi + autentikasi sekaligus (bukan `tls-auth`) |
| **Data Cipher** | AES-256-GCM, AES-128-GCM, CHACHA20-POLY1305 |
| **TLS Minimum** | TLS 1.2 (TLS 1.0 dan 1.1 diblokir) |
| **TLS 1.3 Ciphersuites** | `TLS_AES_256_GCM_SHA384`, `TLS_CHACHA20_POLY1305_SHA256` |
| **HMAC Auth** | SHA-512 |
| **DH Parameters** | Embedded RFC 7919 ffdhe2048 (tidak perlu generate) |
| **Sertifikat** | 3650 hari (10 tahun) dengan CRL otomatis |
| **PKI Engine** | Easy-RSA v3.2.5 (kompatibel OpenSSL 3) |

### Infrastruktur
- **Firewall**: Systemd-based iptables service (bukan `rc.local` yang usang)
- **IPv6 Leak Protection**: Opsi untuk memblokir IPv6 sepenuhnya
- **DNS Leak Protection**: `block-outside-dns` + pilihan DNS provider
- **IP Forwarding**: Konfigurasi via `/etc/sysctl.d/` (bukan `sysctl.conf`)
- **Logging**: File log terpisah di `/var/log/openvpn/`
- **NAT Auto-detect**: Deteksi IP publik otomatis untuk server di belakang NAT
- **SELinux Support**: Konfigurasi port otomatis untuk SELinux enforcing

### Kemudahan Penggunaan
- **TUN Auto-enable**: Mencoba mengaktifkan `/dev/net/tun` otomatis jika belum aktif
- **Error Handling**: Setiap langkah instalasi diverifikasi
- **Multi-distro**: Satu script untuk Ubuntu, Debian, RHEL-family, Fedora
- **Menu Manajemen**: Tambah/cabut/lihat client dari script yang sama

---

## 🖥️ Distro yang Didukung

| Distro | Versi Minimum | Package Manager |
|--------|--------------|-----------------|
| Ubuntu | 20.04 LTS | `apt` |
| Debian | 11 (Bullseye) | `apt` |
| AlmaLinux | 8 | `dnf` |
| Rocky Linux | 8 | `dnf` |
| CentOS Stream | 8 | `dnf` |
| Fedora | 38 | `dnf` |

---

## 📦 Prasyarat

### Server
- Akses **root** (atau `sudo su`)
- Koneksi internet untuk mengunduh paket
- **Port terbuka** sesuai yang dipilih (default: UDP 1194)
- RAM minimal 256 MB, disk 1 GB

### Paket (di-install otomatis)
```
openvpn  openssl  ca-certificates  curl  wget  iptables
```

### Akses Internet
Script mengunduh **Easy-RSA v3.2.5** dari GitHub saat instalasi. Pastikan server bisa menjangkau `github.com`.

---

## 🚀 Instalasi Cepat

```bash
# Download script
wget https://raw.githubusercontent.com/leoui/camouflage-vpn/main/camouflage-vpn.sh

# Beri izin eksekusi
chmod +x camouflage-vpn.sh

# Jalankan sebagai root
sudo bash camouflage-vpn.sh
```

> ⚠️ **Harus dijalankan dengan `bash`**, bukan `sh`. Script menggunakan fitur bash-specific.

### One-liner (untuk VPS baru)

```bash
wget -O camouflage-vpn.sh https://raw.githubusercontent.com/leoui/camouflage-vpn/main/camouflage-vpn.sh && sudo bash camouflage-vpn.sh
```

---

## 🔐 Level Keamanan

Saat instalasi, kamu diminta memilih salah satu dari tiga level:

### Level 1 — Standard
```
data-ciphers AES-256-GCM:AES-128-GCM:CHACHA20-POLY1305
tls-version-min 1.2
```
Cocok untuk: Client lama atau perangkat dengan performa terbatas.

### Level 2 — Hardened *(Direkomendasikan)*
```
data-ciphers AES-256-GCM:CHACHA20-POLY1305
tls-version-min 1.2
tls-cipher TLS-ECDHE-RSA-WITH-AES-256-GCM-SHA384:...
tls-ciphersuites TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
+ Session timeout (opsional)
```
Cocok untuk: Penggunaan umum dengan keamanan tinggi.

### Level 3 — Paranoid
```
data-ciphers AES-256-GCM:CHACHA20-POLY1305
tls-cipher TLS-ECDHE-RSA-WITH-AES-256-GCM-SHA384 (hanya satu)
tls-ciphersuites TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
+ max-clients limiter
+ Session timeout
```
Cocok untuk: Lingkungan korporat / akses sangat terbatas. Mungkin inkompatibel dengan client OpenVPN versi lama.

---

## 🔑 Konfigurasi Kriptografi

### DH Parameters
Script menggunakan parameter DH yang sudah di-embed dari **RFC 7919 ffdhe2048** — tidak perlu proses generate yang memakan waktu lama.

### PKI
- CA dan sertifikat server/client: valid **3650 hari** (10 tahun)
- CRL di-generate otomatis dan di-rotasi saat client dicabut
- Semua operasi PKI dilakukan oleh **Easy-RSA v3.2.5**

### TLS-Crypt Key
- Di-generate dengan `openvpn --genkey tls-crypt` (OpenVPN 2.5+) atau `--genkey --secret` (fallback 2.4)
- Disimpan di `/etc/openvpn/server/tc.key`

---

## 👥 Manajemen Client

Jalankan script yang sama untuk membuka menu manajemen:

```bash
sudo bash camouflage-vpn.sh
```

```
Apa yang mau kamu lakukan?
   1) Tambah user baru
   2) Batalkan akses user yang sudah ada
   3) Lihat client aktif
   4) Lihat status server
   5) Hapus OpenVPN
   6) Keluar
```

### Tambah Client

```bash
sudo bash camouflage-vpn.sh
# Pilih: 1
# Masukkan nama client (alfanumerik, underscore, dash)
```

File `.ovpn` akan dibuat di direktori home root: `~/nama-client.ovpn`

### Cabut Akses Client

```bash
sudo bash camouflage-vpn.sh
# Pilih: 2
# Pilih nomor client dari daftar
```

Script otomatis merevoke sertifikat dan meregenerasi CRL.

### Pilihan DNS yang Tersedia

| Pilihan | Provider | IP |
|---------|----------|----|
| 1 | DNS Sistem | Dari `/etc/resolv.conf` |
| 2 | Cloudflare | `1.1.1.1`, `1.0.0.1` |
| 3 | Google | `8.8.8.8`, `8.8.4.4` |
| 4 | OpenDNS | `208.67.222.222`, `208.67.220.220` |
| 5 | Quad9 | `9.9.9.9`, `149.112.112.112` |
| 6 | AdGuard | `94.140.14.14` *(blokir iklan)* |
| 7 | Cloudflare Malware | `1.1.1.2` |
| 8 | Custom | IP pilihan sendiri |

---

## 📁 Struktur File

Setelah instalasi, berikut file yang dibuat:

```
/etc/openvpn/server/
├── server.conf          # Konfigurasi utama OpenVPN
├── ca.crt               # CA certificate
├── server.crt           # Server certificate
├── server.key           # Server private key
├── dh.pem               # DH parameters (RFC 7919 ffdhe2048)
├── tc.key               # TLS-crypt key
├── crl.pem              # Certificate Revocation List
├── client-common.txt    # Template konfigurasi client
└── easy-rsa/
    └── pki/
        ├── issued/      # Sertifikat client
        └── private/     # Private key client

/var/log/openvpn/
├── camouflage.log           # Log utama OpenVPN
└── openvpn-status.log       # Status koneksi aktif

/etc/sysctl.d/
└── 99-openvpn-forward.conf  # IP forwarding config

/etc/systemd/system/
└── openvpn-iptables.service # Firewall rules (jika tanpa firewalld)
```

---

## 🖧 Kompatibilitas VPS

### OpenVZ / LXC (TUN perlu diaktifkan)
Pada beberapa VPS berbasis OpenVZ atau LXC, perangkat TUN mungkin belum aktif.

Script akan **otomatis mendeteksi** dan menawarkan aktivasi:

```
[!] Perangkat TUN tidak tersedia.
Coba aktifkan TUN sekarang? [Y/n]:
```

Jika otomatis gagal (TUN dinonaktifkan di level hypervisor), aktifkan dari panel kontrol VPS:
- **Virtualizor**: VPS → Settings → TUN/TAP → Enable
- **SolusVM**: VPS → Settings → TUN/TAP
- **OpenVZ Panel**: `vzctl set VEID --devices c:10:200:rw --save`

### KVM / VMware / Hyper-V
TUN tersedia secara default. Tidak perlu konfigurasi tambahan.

### Hetzner Cloud *(Tested)*
Langsung kompatibel. Gunakan IPv4 public server.

### DigitalOcean / Vultr / Linode
Kompatibel penuh. Script auto-detect IP public via `api.ipify.org`.

---

## 🔧 Troubleshooting

### Service gagal start setelah instalasi

```bash
# Cek log detail
journalctl -xeu openvpn-server@server.service

# Atau lihat log file
tail -50 /var/log/openvpn/camouflage.log
```

### Klien tidak bisa konek

```bash
# Cek status service
systemctl status openvpn-server@server.service

# Cek apakah port terbuka
ss -ulnp | grep 1194   # UDP
ss -tlnp | grep 1194   # TCP

# Cek iptables
iptables -t nat -L POSTROUTING -v
iptables -L INPUT -v | grep 1194
```

### IP Forwarding tidak aktif

```bash
# Cek status
cat /proc/sys/net/ipv4/ip_forward
# Harus: 1

# Aktifkan manual jika perlu
echo 1 > /proc/sys/net/ipv4/ip_forward
sysctl -p /etc/sysctl.d/99-openvpn-forward.conf
```

### TUN device tidak muncul

```bash
# Cek
ls -la /dev/net/tun

# Buat manual
mkdir -p /dev/net
mknod /dev/net/tun c 10 200
chmod 600 /dev/net/tun

# Load modul
modprobe tun
```

### Error: `--tls-crypt` key tidak cocok

Pastikan file `tc.key` di client identik dengan yang ada di server `/etc/openvpn/server/tc.key`. File `.ovpn` yang dibuat script sudah embed key ini secara otomatis.

---

## 📊 Perbedaan dari Versi Asli

Dibandingkan [openvpn-install](https://github.com/Nyr/openvpn-install) oleh Nyr:

| Aspek | Original | Camouflage |
|-------|----------|------------|
| Manajemen PKI | Easy-RSA versi lama | Easy-RSA v3.2.5 |
| Control Channel | `tls-auth` | `tls-crypt` (lebih kuat) |
| DH Parameter | Generate saat install | Embedded RFC 7919 ffdhe2048 |
| Firewall | rc.local | Systemd service |
| Level Keamanan | Satu level | Standard / Hardened / Paranoid |
| Session Timeout | Tidak ada | Opsional (12j / 24j / 72j / custom) |
| Max Clients | Tidak ada | Opsional (mode Paranoid) |
| TUN Auto-enable | Tidak ada | ✅ Otomatis tawarkan aktivasi |
| Error Handling | Minimal | ✅ Verifikasi setiap langkah |
| IPv6 Leak Protection | Tidak ada | ✅ Opsi blokir IPv6 |
| genkey syntax | `--genkey secret` (deprecated) | ✅ Auto-detect versi OpenVPN |
| SELinux check | `hash semanage` | ✅ `command -v` + safe fallback |
| Logging | stdout | ✅ File log terpisah |

---

## 📝 Lisensi

MIT License — bebas digunakan, dimodifikasi, dan didistribusikan dengan mencantumkan kredit.

```
Copyright (c) 2026 Camouflage Project
```

Berdasarkan karya open source:
- [Nyr/openvpn-install](https://github.com/Nyr/openvpn-install) — MIT License
- [angristan/openvpn-install](https://github.com/angristan/openvpn-install) — MIT License

---

<div align="center">

Made with ☕ for secure VPN infrastructure by Lewi Verdatama

</div>
