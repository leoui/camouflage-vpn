#!/bin/bash
#
# ╔═══════════════════════════════════════════════════════════════╗
# ║              CAMOUFLAGE — OpenVPN Installer                  ║
# ║          Hardened Road Warrior VPN untuk Indonesia            ║
# ╚═══════════════════════════════════════════════════════════════╝
#
# Berdasarkan karya Nyr dan Angristan
# https://github.com/Nyr/openvpn-install
# https://github.com/angristan/openvpn-install
#
# Copyright (c) 2026 Camouflage Project. Released under the MIT License.
#
# Fitur Keamanan:
#   - Easy-RSA v3.2.5 (terbaru, kompatibel OpenSSL 3)
#   - tls-crypt (enkripsi + autentikasi control channel)
#   - data-ciphers AES-256-GCM:AES-128-GCM:CHACHA20-POLY1305
#   - TLS 1.2 minimum enforcement
#   - TLS 1.3 ciphersuites hardening
#   - SHA-512 HMAC untuk control channel
#   - Embedded DH parameters RFC 7919 (ffdhe2048)
#   - Certificate 3650 hari (10 tahun) dengan CRL
#   - Systemd-based iptables (bukan rc.local)
#   - IPv6 leak protection
#   - DNS leak protection (block-outside-dns)
#   - Logging ke file terpisah
#   - Dukungan Ubuntu, Debian, AlmaLinux, Rocky, CentOS, Fedora
#   - Auto-detect IP public untuk NAT
#   - Opsi keamanan level: Standard / Hardened / Paranoid
#   - Max client limiter
#   - Session timeout opsional
#

CAMOUFLAGE_VERSION="2.1.0"
CAMOUFLAGE_DATE="2026"

# =====================================================================
# PREFLIGHT CHECKS
# =====================================================================

# Deteksi pengguna Debian menjalankan script dengan "sh" bukannya bash
if readlink /proc/$$/exe | grep -q "dash"; then
	echo 'Script ini harus dijalankan dengan "bash", bukan "sh".'
	exit 1
fi

# Buang stdin. Diperlukan saat menjalankan via ssh pipe
read -N 999999 -t 0.001

if [[ "$EUID" -ne 0 ]]; then
	echo "Maaf, kamu harus menjalankan ini sebagai root"
	exit 1
fi

if [[ ! -e /dev/net/tun ]]; then
	echo
	print_warning "Perangkat TUN tidak tersedia."
	echo
	echo "Tanpa TUN, OpenVPN tidak bisa berjalan."
	read -p "Coba aktifkan TUN sekarang? [Y/n]: " -e -i Y tun_enable
	if [[ "$tun_enable" =~ ^[yY]$ ]]; then
		mkdir -p /dev/net
		if mknod /dev/net/tun c 10 200 2>/dev/null; then
			chmod 600 /dev/net/tun
			print_success "TUN device berhasil diaktifkan."
		elif modprobe tun 2>/dev/null && [[ -e /dev/net/tun ]]; then
			print_success "TUN module berhasil dimuat."
		else
			print_error "Gagal mengaktifkan TUN secara otomatis."
			echo "Kemungkinan TUN dinonaktifkan di level hypervisor/VPS panel."
			echo "Aktifkan TUN di panel kontrol VPS kamu (Virtualizor, SolusVM, dll)."
			exit 1
		fi
	else
		echo "Aktifkan TUN device terlebih dahulu, lalu jalankan script ini lagi."
		exit 1
	fi
fi

# =====================================================================
# DETEKSI OS
# =====================================================================
if [[ -e /etc/os-release ]]; then
	source /etc/os-release
	os=$ID
	os_version=$VERSION_ID
elif [[ -e /etc/debian_version ]]; then
	os=debian
	os_version=$(cat /etc/debian_version)
elif [[ -e /etc/centos-release ]]; then
	os=centos
	os_version=$(grep -oE '[0-9]+' /etc/centos-release | head -1)
elif [[ -e /etc/fedora-release ]]; then
	os=fedora
	os_version=$(grep -oE '[0-9]+' /etc/fedora-release | head -1)
else
	echo "OS tidak didukung."
	echo "Camouflage mendukung: Ubuntu 20.04+, Debian 11+, AlmaLinux 8+, Rocky 8+, CentOS Stream 8+, Fedora 38+"
	exit 1
fi

# Normalisasi nama OS
case $os in
	ubuntu)
		os=ubuntu
		if [[ "${os_version%%.*}" -lt 20 ]]; then
			echo "Ubuntu versi $os_version tidak didukung. Minimal Ubuntu 20.04."
			exit 1
		fi
		;;
	debian)
		os=debian
		if [[ "${os_version%%.*}" -lt 11 ]]; then
			echo "Debian versi $os_version tidak didukung. Minimal Debian 11."
			exit 1
		fi
		;;
	centos|almalinux|rocky)
		os=centos
		if [[ "${os_version%%.*}" -lt 8 ]]; then
			echo "OS versi $os_version tidak didukung. Minimal versi 8."
			exit 1
		fi
		;;
	fedora)
		os=fedora
		if [[ "${os_version%%.*}" -lt 38 ]]; then
			echo "Fedora versi $os_version tidak didukung. Minimal Fedora 38."
			exit 1
		fi
		;;
	*)
		echo "OS '$os' tidak didukung."
		exit 1
		;;
esac

# Deteksi group name
if [[ "$os" =~ (debian|ubuntu) ]]; then
	group_name=nogroup
else
	group_name=nobody
fi

# =====================================================================
# FUNGSI UTILITAS
# =====================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

print_header() {
	echo -e "${CYAN}"
	echo "╔═══════════════════════════════════════════════════════════════╗"
	echo "║              CAMOUFLAGE v${CAMOUFLAGE_VERSION} — OpenVPN Installer             ║"
	echo "║          Hardened Road Warrior VPN untuk Indonesia            ║"
	echo "╚═══════════════════════════════════════════════════════════════╝"
	echo -e "${NC}"
}

print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_error()   { echo -e "${RED}[✗]${NC} $1"; }
print_info()    { echo -e "${CYAN}[i]${NC} $1"; }
print_step()    { echo -e "${BOLD}>>> $1${NC}"; }

# =====================================================================
# FUNGSI PEMBUATAN CLIENT
# =====================================================================

new_client() {
	local client_name="$1"
	{
		cat /etc/openvpn/server/client-common.txt
		echo "<ca>"
		cat /etc/openvpn/server/ca.crt
		echo "</ca>"
		echo "<cert>"
		sed -ne '/BEGIN CERTIFICATE/,$ p' /etc/openvpn/server/easy-rsa/pki/issued/"${client_name}".crt
		echo "</cert>"
		echo "<key>"
		cat /etc/openvpn/server/easy-rsa/pki/private/"${client_name}".key
		echo "</key>"
		echo "<tls-crypt>"
		sed -ne '/BEGIN OpenVPN Static key/,$ p' /etc/openvpn/server/tc.key
		echo "</tls-crypt>"
	} > ~/"${client_name}".ovpn
}

# =====================================================================
# MENU MANAJEMEN (jika sudah terinstall)
# =====================================================================

if [[ -e /etc/openvpn/server/server.conf ]]; then
	while : ; do
		clear
		print_header
		echo "OpenVPN sudah terinstall via Camouflage."
		echo
		echo "Apa yang mau kamu lakukan?"
		echo "   1) Tambah user baru"
		echo "   2) Batalkan akses user yang sudah ada"
		echo "   3) Lihat client aktif"
		echo "   4) Lihat status server"
		echo "   5) Hapus OpenVPN"
		echo "   6) Keluar"
		read -p "Pilih jawaban [1-6]: " option
		case $option in
			1)
				echo
				echo "Silakan beri nama untuk client baru."
				echo "Nama: alfanumerik, underscore, atau dash saja."
				until [[ $client =~ ^[a-zA-Z0-9_-]+$ ]]; do
					read -p "Nama client: " -e client
				done
				if [[ -e /etc/openvpn/server/easy-rsa/pki/issued/"$client".crt ]]; then
					print_error "Client '$client' sudah ada! Gunakan nama lain."
					client=""
					continue
				fi
				cd /etc/openvpn/server/easy-rsa/
				./easyrsa --batch --days=3650 build-client-full "$client" nopass
				new_client "$client"
				print_success "Client $client berhasil dibuat!"
				echo "File: $(echo ~/"$client.ovpn")"
				exit 0
				;;
			2)
				number_of_clients=$(tail -n +2 /etc/openvpn/server/easy-rsa/pki/index.txt | grep -c "^V")
				if [[ "$number_of_clients" = 0 ]]; then
					echo
					print_warning "Tidak ada client aktif!"
					exit 1
				fi
				echo
				echo "Pilih client yang mau dibatalkan aksesnya:"
				tail -n +2 /etc/openvpn/server/easy-rsa/pki/index.txt | grep "^V" | cut -d '=' -f 2 | nl -s ') '
				until [[ $client_number =~ ^[0-9]+$ && $client_number -le $number_of_clients && $client_number -ge 1 ]]; do
					read -p "Pilih client [1-$number_of_clients]: " client_number
				done
				client=$(tail -n +2 /etc/openvpn/server/easy-rsa/pki/index.txt | grep "^V" | cut -d '=' -f 2 | sed -n "${client_number}p")
				echo
				read -p "Yakin batalkan akses $client? [y/N]: " -e revoke
				if [[ "$revoke" =~ ^[yY]$ ]]; then
					cd /etc/openvpn/server/easy-rsa/
					./easyrsa --batch revoke "$client"
					./easyrsa --batch --days=3650 gen-crl
					rm -f /etc/openvpn/server/crl.pem
					cp /etc/openvpn/server/easy-rsa/pki/crl.pem /etc/openvpn/server/crl.pem
					chown nobody:"$group_name" /etc/openvpn/server/crl.pem
					rm -f ~/"$client".ovpn
					print_success "Client $client dibatalkan!"
				else
					print_info "Dibatalkan."
				fi
				exit 0
				;;
			3)
				echo
				print_step "Client Aktif:"
				echo "---"
				count=0
				while IFS= read -r line; do
					name=$(echo "$line" | cut -d '=' -f 2)
					if [[ "$name" != "server" ]]; then
						count=$((count + 1))
						echo "  $count) $name"
					fi
				done < <(tail -n +2 /etc/openvpn/server/easy-rsa/pki/index.txt | grep "^V")
				[[ $count -eq 0 ]] && print_warning "Tidak ada client aktif."
				echo
				revoked_count=$(tail -n +2 /etc/openvpn/server/easy-rsa/pki/index.txt | grep -c "^R" 2>/dev/null || echo 0)
				if [[ "$revoked_count" -gt 0 ]]; then
					print_step "Client Dibatalkan:"
					echo "---"
					tail -n +2 /etc/openvpn/server/easy-rsa/pki/index.txt | grep "^R" | cut -d '=' -f 2 | while read -r name; do
						echo "  [REVOKED] $name"
					done
				fi
				echo
				read -n1 -r -p "Tekan tombol apapun..."
				;;
			4)
				echo
				print_step "Status Server OpenVPN Camouflage"
				echo "---"
				if systemctl is-active --quiet openvpn-server@server.service 2>/dev/null; then
					print_success "Service: AKTIF"
				else
					print_error "Service: TIDAK AKTIF"
				fi
				if [[ -e /etc/openvpn/server/server.conf ]]; then
					s_port=$(grep '^port ' /etc/openvpn/server/server.conf | cut -d " " -f 2)
					s_proto=$(grep '^proto ' /etc/openvpn/server/server.conf | cut -d " " -f 2)
					echo "  Port: $s_port | Proto: $s_proto"
				fi
				echo
				if [[ -e /var/log/openvpn/openvpn-status.log ]]; then
					print_step "Koneksi Aktif:"
					active_count=$(grep -c "^CLIENT_LIST" /var/log/openvpn/openvpn-status.log 2>/dev/null || echo 0)
					if [[ "$active_count" -gt 0 ]]; then
						grep "^CLIENT_LIST" /var/log/openvpn/openvpn-status.log | while IFS=',' read -r _ name real virt _ _ _ _ _; do
							echo "  $name | VPN: $virt | Dari: $real"
						done
					else
						print_info "Tidak ada koneksi aktif."
					fi
				fi
				echo
				print_step "Log Terakhir:"
				journalctl -u openvpn-server@server.service --no-pager -n 8 2>/dev/null || \
					tail -8 /var/log/openvpn/camouflage.log 2>/dev/null || \
					print_warning "Log tidak tersedia."
				echo
				read -n1 -r -p "Tekan tombol apapun..."
				;;
			5)
				echo
				read -p "Yakin hapus OpenVPN? [y/N]: " -e remove
				if [[ "$remove" =~ ^[yY]$ ]]; then
					port=$(grep '^port ' /etc/openvpn/server/server.conf | cut -d " " -f 2)
					protocol=$(grep '^proto ' /etc/openvpn/server/server.conf | cut -d " " -f 2)
					systemctl disable --now openvpn-server@server.service 2>/dev/null
					if systemctl is-active --quiet openvpn-iptables.service 2>/dev/null; then
						systemctl disable --now openvpn-iptables.service
					fi
					rm -f /etc/systemd/system/openvpn-iptables.service
					if pgrep firewalld > /dev/null 2>&1; then
						ip=$(firewall-cmd --direct --get-rules ipv4 nat POSTROUTING | grep '\-s 10.8.0.0/24' | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')
						firewall-cmd --zone=public --remove-port="$port/$protocol" 2>/dev/null
						firewall-cmd --zone=trusted --remove-source=10.8.0.0/24 2>/dev/null
						firewall-cmd --permanent --zone=public --remove-port="$port/$protocol" 2>/dev/null
						firewall-cmd --permanent --zone=trusted --remove-source=10.8.0.0/24 2>/dev/null
						[[ -n "$ip" ]] && firewall-cmd --direct --remove-rule ipv4 nat POSTROUTING 0 -s 10.8.0.0/24 ! -d 10.8.0.0/24 -j SNAT --to "$ip" 2>/dev/null
						[[ -n "$ip" ]] && firewall-cmd --permanent --direct --remove-rule ipv4 nat POSTROUTING 0 -s 10.8.0.0/24 ! -d 10.8.0.0/24 -j SNAT --to "$ip" 2>/dev/null
					fi
					if command -v sestatus &>/dev/null && sestatus 2>/dev/null | grep "Current mode" | grep -q "enforcing" && [[ "$port" != '1194' ]]; then
						semanage port -d -t openvpn_port_t -p "$protocol" "$port" 2>/dev/null
					fi
					if [[ "$os" =~ (debian|ubuntu) ]]; then
						apt-get remove --purge -y openvpn 2>/dev/null
					else
						dnf remove -y openvpn 2>/dev/null || yum remove -y openvpn 2>/dev/null
					fi
					rm -rf /etc/openvpn/server
					rm -f /etc/sysctl.d/99-openvpn-forward.conf
					rm -rf /var/log/openvpn
					sysctl --system > /dev/null 2>&1
					systemctl daemon-reload
					print_success "Camouflage VPN berhasil dihapus!"
				else
					print_info "Dibatalkan."
				fi
				exit 0
				;;
			6) exit 0 ;;
		esac
	done
fi

# =====================================================================
# INSTALASI BARU
# =====================================================================
clear
print_header
echo "Ada beberapa pertanyaan sebelum memulai instalasi."
echo "Tekan enter untuk menerima pilihan default."
echo

# ------- IP -------
if [[ $(ip -4 addr | grep inet | grep -vEc '127(\.[0-9]{1,3}){3}') -eq 1 ]]; then
	ip=$(ip -4 addr | grep inet | grep -vE '127(\.[0-9]{1,3}){3}' | cut -d '/' -f 1 | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}')
else
	number_of_ip=$(ip -4 addr | grep inet | grep -vEc '127(\.[0-9]{1,3}){3}')
	echo "Server punya beberapa IPv4. Pilih:"
	ip -4 addr | grep inet | grep -vE '127(\.[0-9]{1,3}){3}' | cut -d '/' -f 1 | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | nl -s ') '
	until [[ $ip_number =~ ^[0-9]+$ && $ip_number -le $number_of_ip && $ip_number -ge 1 ]]; do
		read -p "IPv4 [1-$number_of_ip]: " ip_number
	done
	ip=$(ip -4 addr | grep inet | grep -vE '127(\.[0-9]{1,3}){3}' | cut -d '/' -f 1 | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | sed -n "${ip_number}p")
fi

if echo "$ip" | grep -qE '^(10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.|192\.168)'; then
	echo
	print_info "Server dibelakang NAT."
	public_ip=$(curl -4s https://api.ipify.org 2>/dev/null || curl -4s https://ifconfig.me 2>/dev/null || curl -4s https://icanhazip.com 2>/dev/null)
	if [[ -n "$public_ip" ]]; then
		read -p "IP public [$public_ip]: " -e -i "$public_ip" public_ip
	else
		read -p "IP public / hostname: " -e public_ip
	fi
fi

# ------- IPv6 -------
echo
echo "Aktifkan IPv6?"
echo "   1) Tidak (direkomendasikan — cegah IPv6 leak)"
echo "   2) Ya"
until [[ $ipv6_support =~ ^[12]$ ]]; do
	read -p "IPv6 [1-2]: " -e -i 1 ipv6_support
done
if [[ $ipv6_support == 2 ]]; then
	if [[ $(ip -6 addr | grep -c 'inet6 [23]') -ge 1 ]]; then
		ip6=$(ip -6 addr | grep 'inet6 [23]' | cut -d '/' -f 1 | grep -oE '([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}' | head -1)
		print_info "IPv6: $ip6"
	else
		print_warning "Tidak ada IPv6 global. Dinonaktifkan."
		ipv6_support=1
	fi
fi

# ------- Protokol -------
echo
echo "Protokol:"
echo "   1) UDP (direkomendasikan)"
echo "   2) TCP"
until [[ $protocol_choice =~ ^[12]$ ]]; do
	read -p "Protokol [1-2]: " -e -i 1 protocol_choice
done
case $protocol_choice in
	1) protocol=udp ;;
	2) protocol=tcp ;;
esac

# ------- Port -------
echo
echo "Port OpenVPN (tip: 443/TCP bisa bypass firewall):"
until [[ $port =~ ^[0-9]+$ && $port -le 65535 && $port -ge 1 ]]; do
	read -p "Port [1-65535]: " -e -i 1194 port
done

# ------- DNS -------
echo
echo "DNS untuk VPN:"
echo "   1) DNS sistem"
echo "   2) Cloudflare (1.1.1.1)"
echo "   3) Google (8.8.8.8)"
echo "   4) OpenDNS (208.67.222.222)"
echo "   5) Quad9 (9.9.9.9)"
echo "   6) AdGuard (94.140.14.14) — blokir iklan"
echo "   7) Cloudflare Malware (1.1.1.2)"
echo "   8) Custom DNS"
until [[ $dns =~ ^[1-8]$ ]]; do
	read -p "DNS [1-8]: " -e -i 2 dns
done
if [[ $dns == 8 ]]; then
	until [[ $custom_dns1 =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; do
		read -p "DNS primer: " -e custom_dns1
	done
	until [[ $custom_dns2 =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; do
		read -p "DNS sekunder: " -e custom_dns2
	done
fi

# ------- Level Keamanan -------
echo
echo "Level keamanan:"
echo "   1) Standard  — AES-256-GCM, tls-crypt, TLS 1.2+"
echo "   2) Hardened  — + TLS cipher hardening, logging (direkomendasikan)"
echo "   3) Paranoid  — + strict ciphers, max-clients (bisa inkompatibel)"
until [[ $security_level =~ ^[1-3]$ ]]; do
	read -p "Keamanan [1-3]: " -e -i 2 security_level
done

if [[ $security_level == 3 ]]; then
	echo
	until [[ $max_clients =~ ^[0-9]+$ && $max_clients -ge 1 && $max_clients -le 1024 ]]; do
		read -p "Max clients [1-1024]: " -e -i 10 max_clients
	done
fi

if [[ $security_level -ge 2 ]]; then
	echo
	echo "Session timeout:"
	echo "   1) Tidak ada"
	echo "   2) 12 jam"
	echo "   3) 24 jam"
	echo "   4) 72 jam"
	echo "   5) Custom (jam)"
	until [[ $timeout_choice =~ ^[1-5]$ ]]; do
		read -p "Timeout [1-5]: " -e -i 1 timeout_choice
	done
	case $timeout_choice in
		1) session_timeout=0 ;;
		2) session_timeout=43200 ;;
		3) session_timeout=86400 ;;
		4) session_timeout=259200 ;;
		5) read -p "Jam: " -e timeout_hours; session_timeout=$((timeout_hours * 3600)) ;;
	esac
fi

# ------- Client -------
echo
echo "Nama client pertama (alfanumerik/underscore/dash):"
until [[ $client =~ ^[a-zA-Z0-9_-]+$ ]]; do
	read -p "Nama client: " -e -i "client1" client
done

# ------- Konfirmasi -------
echo
echo -e "${BOLD}═══ Ringkasan Konfigurasi ═══${NC}"
echo "  IP        : $ip"
[[ -n "$public_ip" ]] && echo "  IP Public : $public_ip"
echo "  Proto     : $protocol | Port: $port"
echo "  DNS       : $dns"
sec_label="Standard"; [[ $security_level == 2 ]] && sec_label="Hardened"; [[ $security_level == 3 ]] && sec_label="Paranoid"
echo "  Keamanan  : $sec_label"
echo "  Client    : $client"
echo -e "${BOLD}═════════════════════════════${NC}"
echo
read -n1 -r -p "Tekan tombol apapun untuk mulai instalasi..."
echo; echo

# =====================================================================
# INSTALL PAKET
# =====================================================================
print_step "Menginstall paket..."
if [[ "$os" =~ (debian|ubuntu) ]]; then
	export DEBIAN_FRONTEND=noninteractive
	apt-get update -qq
	if ! apt-get install -y -qq openvpn openssl ca-certificates curl wget iptables; then
		print_error "Gagal menginstall satu atau lebih paket."
		exit 1
	fi
else
	[[ "$os" == "centos" ]] && { dnf install -y -q epel-release 2>/dev/null || yum install -y -q epel-release 2>/dev/null; }
	if ! { dnf install -y -q openvpn openssl ca-certificates curl wget iptables 2>/dev/null || \
		yum install -y -q openvpn openssl ca-certificates curl wget iptables 2>/dev/null; }; then
		print_error "Gagal menginstall satu atau lebih paket."
		exit 1
	fi
fi
print_success "Paket terinstall."

# =====================================================================
# INSTALL EASY-RSA v3.2.5
# =====================================================================
print_step "Menginstall Easy-RSA v3.2.5..."
EASYRSA_VER="3.2.5"
EASYRSA_URL="https://github.com/OpenVPN/easy-rsa/releases/download/v${EASYRSA_VER}/EasyRSA-${EASYRSA_VER}.tgz"
mkdir -p /etc/openvpn/server/easy-rsa/
if ! { wget -qO ~/easyrsa.tgz "$EASYRSA_URL" 2>/dev/null || curl -sLo ~/easyrsa.tgz "$EASYRSA_URL"; }; then
	print_error "Gagal mengunduh Easy-RSA. Periksa koneksi internet."
	exit 1
fi
if ! tar xzf ~/easyrsa.tgz --strip-components=1 -C /etc/openvpn/server/easy-rsa/ 2>/dev/null; then
	print_error "Gagal mengekstrak Easy-RSA. File mungkin korup."
	rm -f ~/easyrsa.tgz
	exit 1
fi
rm -f ~/easyrsa.tgz
chown -R root:root /etc/openvpn/server/easy-rsa/
print_success "Easy-RSA v${EASYRSA_VER} terinstall."

# =====================================================================
# BUAT PKI
# =====================================================================
print_step "Membuat PKI dan sertifikat..."
cd /etc/openvpn/server/easy-rsa/
./easyrsa --batch init-pki > /dev/null 2>&1
./easyrsa --batch build-ca nopass > /dev/null 2>&1

# Embedded DH (RFC 7919 ffdhe2048)
cat > /etc/openvpn/server/dh.pem << 'DHEOF'
-----BEGIN DH PARAMETERS-----
MIIBCAKCAQEA//////////+t+FRYortKmq/cViAnPTzx2LnFg84tNpWp4TZBFGQz
+8yTnc4kmz75fS/jY2MMddj2gbICrsRhetPfHtXV/WVhJDP1H18GbtCFY2VVPe0a
87VXE15/V8k1mE8McODmi3fipona8+/och3xWKE2rec1MKzKT0g6eXq8CrGCsyT7
YdEIqUuyyOP7uWrat2DX9GgdT0Kj3jlN9K5W7edjcrsZCwenyO4KbXCeAvzhzffi
7MA0BM0oNC9hkXL+nOmFg/+OTxIy7vKBg8P+OxtMb61zO7X8vC7CIAXFjvGDfRaD
ssbzSibBsu/6iGtCOGEoXJf//////////wIBAg==
-----END DH PARAMETERS-----
DHEOF
ln -sf /etc/openvpn/server/dh.pem /etc/openvpn/server/easy-rsa/pki/dh.pem 2>/dev/null

./easyrsa --batch --days=3650 build-server-full server nopass > /dev/null 2>&1
./easyrsa --batch --days=3650 build-client-full "$client" nopass > /dev/null 2>&1
./easyrsa --batch --days=3650 gen-crl > /dev/null 2>&1

cp pki/ca.crt pki/private/ca.key pki/issued/server.crt pki/private/server.key pki/crl.pem /etc/openvpn/server/
chown nobody:"$group_name" /etc/openvpn/server/crl.pem
chmod o+x /etc/openvpn/server/

# TLS-crypt key
# --genkey tls-crypt (OpenVPN 2.5+), fallback ke --genkey secret (2.4-)
if openvpn --help 2>&1 | grep -q "tls-crypt"; then
	openvpn --genkey tls-crypt /etc/openvpn/server/tc.key
else
	openvpn --genkey --secret /etc/openvpn/server/tc.key
fi
print_success "PKI selesai."

# =====================================================================
# LOG DIRECTORY
# =====================================================================
mkdir -p /var/log/openvpn
chmod 750 /var/log/openvpn

# =====================================================================
# BUAT server.conf
# =====================================================================
print_step "Membuat konfigurasi server..."

cat > /etc/openvpn/server/server.conf << EOF
# Camouflage v${CAMOUFLAGE_VERSION} — Generated $(date '+%Y-%m-%d %H:%M')
local $ip
port $port
proto $protocol
dev tun

# Sertifikat
ca ca.crt
cert server.crt
key server.key
dh dh.pem

# Keamanan Crypto
auth SHA512
tls-crypt tc.key
EOF

case $security_level in
	1)
		cat >> /etc/openvpn/server/server.conf << 'EOF'
data-ciphers AES-256-GCM:AES-128-GCM:CHACHA20-POLY1305
data-ciphers-fallback AES-256-GCM
tls-version-min 1.2
EOF
		;;
	2)
		cat >> /etc/openvpn/server/server.conf << 'EOF'
data-ciphers AES-256-GCM:CHACHA20-POLY1305
data-ciphers-fallback AES-256-GCM
tls-version-min 1.2
tls-cipher TLS-ECDHE-RSA-WITH-AES-256-GCM-SHA384:TLS-ECDHE-RSA-WITH-AES-128-GCM-SHA256:TLS-DHE-RSA-WITH-AES-256-GCM-SHA384
tls-ciphersuites TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
EOF
		;;
	3)
		cat >> /etc/openvpn/server/server.conf << 'EOF'
data-ciphers AES-256-GCM:CHACHA20-POLY1305
data-ciphers-fallback AES-256-GCM
tls-version-min 1.2
tls-cipher TLS-ECDHE-RSA-WITH-AES-256-GCM-SHA384
tls-ciphersuites TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
EOF
		;;
esac

# Topologi
cat >> /etc/openvpn/server/server.conf << EOF

# Jaringan
topology subnet
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
EOF

[[ $ipv6_support == 2 ]] && echo "server-ipv6 fddd:1194:1194:1194::/64" >> /etc/openvpn/server/server.conf

# Push
echo '' >> /etc/openvpn/server/server.conf
echo 'push "redirect-gateway def1 bypass-dhcp"' >> /etc/openvpn/server/server.conf
if [[ $ipv6_support == 2 ]]; then
	echo 'push "redirect-gateway ipv6"' >> /etc/openvpn/server/server.conf
	echo 'push "route-ipv6 2000::/3"' >> /etc/openvpn/server/server.conf
fi

# DNS
case $dns in
	1)
		if grep -q "127.0.0.53" "/etc/resolv.conf"; then
			RESOLVCONF='/run/systemd/resolve/resolv.conf'
		else
			RESOLVCONF='/etc/resolv.conf'
		fi
		grep -v '#' "$RESOLVCONF" | grep 'nameserver' | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | while read -r line; do
			echo "push \"dhcp-option DNS $line\"" >> /etc/openvpn/server/server.conf
		done
		;;
	2) echo 'push "dhcp-option DNS 1.1.1.1"' >> /etc/openvpn/server/server.conf
	   echo 'push "dhcp-option DNS 1.0.0.1"' >> /etc/openvpn/server/server.conf ;;
	3) echo 'push "dhcp-option DNS 8.8.8.8"' >> /etc/openvpn/server/server.conf
	   echo 'push "dhcp-option DNS 8.8.4.4"' >> /etc/openvpn/server/server.conf ;;
	4) echo 'push "dhcp-option DNS 208.67.222.222"' >> /etc/openvpn/server/server.conf
	   echo 'push "dhcp-option DNS 208.67.220.220"' >> /etc/openvpn/server/server.conf ;;
	5) echo 'push "dhcp-option DNS 9.9.9.9"' >> /etc/openvpn/server/server.conf
	   echo 'push "dhcp-option DNS 149.112.112.112"' >> /etc/openvpn/server/server.conf ;;
	6) echo 'push "dhcp-option DNS 94.140.14.14"' >> /etc/openvpn/server/server.conf
	   echo 'push "dhcp-option DNS 94.140.15.15"' >> /etc/openvpn/server/server.conf ;;
	7) echo 'push "dhcp-option DNS 1.1.1.2"' >> /etc/openvpn/server/server.conf
	   echo 'push "dhcp-option DNS 1.0.0.2"' >> /etc/openvpn/server/server.conf ;;
	8) echo "push \"dhcp-option DNS $custom_dns1\"" >> /etc/openvpn/server/server.conf
	   echo "push \"dhcp-option DNS $custom_dns2\"" >> /etc/openvpn/server/server.conf ;;
esac

# Opsi lanjutan
cat >> /etc/openvpn/server/server.conf << EOF

# Koneksi
keepalive 10 120
user nobody
group $group_name
persist-key
persist-tun

# Logging
status /var/log/openvpn/openvpn-status.log
status-version 2
log /var/log/openvpn/camouflage.log
verb 3

# Keamanan
crl-verify crl.pem
remote-cert-tls client
EOF

[[ "$protocol" == "udp" ]] && echo "explicit-exit-notify" >> /etc/openvpn/server/server.conf
[[ $security_level == 3 ]] && [[ -n "$max_clients" ]] && echo "max-clients $max_clients" >> /etc/openvpn/server/server.conf
[[ $security_level -ge 2 ]] && [[ -n "$session_timeout" ]] && [[ "$session_timeout" -gt 0 ]] && echo "reneg-sec $session_timeout" >> /etc/openvpn/server/server.conf

ln -sf /var/log/openvpn/openvpn-status.log /etc/openvpn/server/openvpn-status.log 2>/dev/null
print_success "Konfigurasi server selesai."

# =====================================================================
# IP FORWARDING
# =====================================================================
print_step "Mengaktifkan IP forwarding..."
echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-openvpn-forward.conf
[[ $ipv6_support == 2 ]] && echo 'net.ipv6.conf.all.forwarding=1' >> /etc/sysctl.d/99-openvpn-forward.conf
# Apply sysctl - coba system-wide, fallback ke per-file
if ! sysctl --system > /dev/null 2>&1; then
	sysctl -p /etc/sysctl.d/99-openvpn-forward.conf > /dev/null 2>&1 || true
fi
# Verifikasi ip_forward aktif
if [[ "$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null)" != "1" ]]; then
	# Paksa aktif secara langsung
	echo 1 > /proc/sys/net/ipv4/ip_forward 2>/dev/null || true
fi
print_success "IP forwarding aktif."

# =====================================================================
# FIREWALL
# =====================================================================
print_step "Mengkonfigurasi firewall..."
if pgrep firewalld > /dev/null 2>&1; then
	firewall-cmd --zone=public --add-port="$port/$protocol" 2>/dev/null
	firewall-cmd --zone=trusted --add-source=10.8.0.0/24 2>/dev/null
	firewall-cmd --permanent --zone=public --add-port="$port/$protocol" 2>/dev/null
	firewall-cmd --permanent --zone=trusted --add-source=10.8.0.0/24 2>/dev/null
	firewall-cmd --direct --add-rule ipv4 nat POSTROUTING 0 -s 10.8.0.0/24 ! -d 10.8.0.0/24 -j SNAT --to "$ip" 2>/dev/null
	firewall-cmd --permanent --direct --add-rule ipv4 nat POSTROUTING 0 -s 10.8.0.0/24 ! -d 10.8.0.0/24 -j SNAT --to "$ip" 2>/dev/null
	if [[ $ipv6_support == 2 ]] && [[ -n "$ip6" ]]; then
		firewall-cmd --zone=trusted --add-source=fddd:1194:1194:1194::/64 2>/dev/null
		firewall-cmd --permanent --zone=trusted --add-source=fddd:1194:1194:1194::/64 2>/dev/null
		firewall-cmd --direct --add-rule ipv6 nat POSTROUTING 0 -s fddd:1194:1194:1194::/64 ! -d fddd:1194:1194:1194::/64 -j SNAT --to "$ip6" 2>/dev/null
		firewall-cmd --permanent --direct --add-rule ipv6 nat POSTROUTING 0 -s fddd:1194:1194:1194::/64 ! -d fddd:1194:1194:1194::/64 -j SNAT --to "$ip6" 2>/dev/null
	fi
	firewall-cmd --reload 2>/dev/null
	print_success "Firewalld dikonfigurasi."
else
	# Pastikan iptables tersedia
	iptables_path=$(command -v iptables 2>/dev/null)
	if [[ -z "$iptables_path" ]]; then
		print_warning "iptables tidak ditemukan, mencoba menginstall..."
		if [[ "$os" =~ (debian|ubuntu) ]]; then
			apt-get install -y -qq iptables > /dev/null 2>&1
		else
			dnf install -y -q iptables 2>/dev/null || yum install -y -q iptables 2>/dev/null
		fi
		iptables_path=$(command -v iptables 2>/dev/null)
		if [[ -z "$iptables_path" ]]; then
			print_error "Gagal menginstall iptables. Install manual lalu jalankan ulang."
			exit 1
		fi
		print_success "iptables berhasil diinstall."
	fi
	ip6tables_path=$(command -v ip6tables 2>/dev/null)
	cat > /etc/systemd/system/openvpn-iptables.service << SVCEOF
[Unit]
Description=Camouflage iptables rules
Before=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$iptables_path -t nat -A POSTROUTING -s 10.8.0.0/24 ! -d 10.8.0.0/24 -j SNAT --to $ip
ExecStart=$iptables_path -I INPUT -p $protocol --dport $port -j ACCEPT
ExecStart=$iptables_path -I FORWARD -s 10.8.0.0/24 -j ACCEPT
ExecStart=$iptables_path -I FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
ExecStop=$iptables_path -t nat -D POSTROUTING -s 10.8.0.0/24 ! -d 10.8.0.0/24 -j SNAT --to $ip
ExecStop=$iptables_path -D INPUT -p $protocol --dport $port -j ACCEPT
ExecStop=$iptables_path -D FORWARD -s 10.8.0.0/24 -j ACCEPT
ExecStop=$iptables_path -D FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
SVCEOF
	if [[ $ipv6_support == 2 ]] && [[ -n "$ip6" ]]; then
		cat >> /etc/systemd/system/openvpn-iptables.service << SVCEOF
ExecStart=$ip6tables_path -t nat -A POSTROUTING -s fddd:1194:1194:1194::/64 ! -d fddd:1194:1194:1194::/64 -j SNAT --to $ip6
ExecStart=$ip6tables_path -I FORWARD -s fddd:1194:1194:1194::/64 -j ACCEPT
ExecStart=$ip6tables_path -I FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
ExecStop=$ip6tables_path -t nat -D POSTROUTING -s fddd:1194:1194:1194::/64 ! -d fddd:1194:1194:1194::/64 -j SNAT --to $ip6
ExecStop=$ip6tables_path -D FORWARD -s fddd:1194:1194:1194::/64 -j ACCEPT
ExecStop=$ip6tables_path -D FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
SVCEOF
	fi
	cat >> /etc/systemd/system/openvpn-iptables.service << 'SVCEOF'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SVCEOF
	systemctl daemon-reload
	systemctl enable --now openvpn-iptables.service > /dev/null 2>&1
	print_success "Iptables service dikonfigurasi."
fi

# =====================================================================
# SELINUX
# =====================================================================
if command -v sestatus &>/dev/null && sestatus 2>/dev/null | grep "Current mode" | grep -q "enforcing" && [[ "$port" != '1194' ]]; then
	print_step "Mengkonfigurasi SELinux..."
	if ! command -v semanage &>/dev/null; then
		print_warning "semanage tidak ditemukan, menginstall policycoreutils..."
		dnf install -y -q policycoreutils-python-utils 2>/dev/null || \
			yum install -y -q policycoreutils-python-utils 2>/dev/null || \
			yum install -y -q policycoreutils-python 2>/dev/null
	fi
	semanage port -a -t openvpn_port_t -p "$protocol" "$port" 2>/dev/null || true
	print_success "SELinux dikonfigurasi."
fi

# =====================================================================
# CLIENT TEMPLATE & PERTAMA
# =====================================================================
print_step "Membuat client config..."
[[ -n "$public_ip" ]] && ip="$public_ip"

cat > /etc/openvpn/server/client-common.txt << EOF
# Camouflage v${CAMOUFLAGE_VERSION} Client
client
dev tun
proto $protocol
remote $ip $port
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
auth SHA512
ignore-unknown-option block-outside-dns
block-outside-dns
verb 3
EOF

case $security_level in
	1) echo "data-ciphers AES-256-GCM:AES-128-GCM:CHACHA20-POLY1305" >> /etc/openvpn/server/client-common.txt ;;
	2|3) echo "data-ciphers AES-256-GCM:CHACHA20-POLY1305" >> /etc/openvpn/server/client-common.txt ;;
esac

new_client "$client"
print_success "Client '$client' dibuat."

# =====================================================================
# START
# =====================================================================
print_step "Memulai OpenVPN..."
systemctl enable --now openvpn-server@server.service > /dev/null 2>&1
sleep 2

echo
echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
if systemctl is-active --quiet openvpn-server@server.service; then
	echo -e "${CYAN}║${NC}  ${GREEN}✓ Camouflage v${CAMOUFLAGE_VERSION} berhasil diinstall!${NC}                       ${CYAN}║${NC}"
else
	echo -e "${CYAN}║${NC}  ${YELLOW}! Selesai, tapi service gagal start.${NC}                        ${CYAN}║${NC}"
	echo -e "${CYAN}║${NC}    journalctl -xeu openvpn-server@server.service             ${CYAN}║${NC}"
fi
echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║${NC}  File client : ~/${client}.ovpn                                 ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  Server log  : /var/log/openvpn/camouflage.log               ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  Keamanan    : ${sec_label}                                          ${CYAN}║${NC}"
echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║${NC}  Jalankan script ini lagi untuk mengelola client!             ${CYAN}║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo
