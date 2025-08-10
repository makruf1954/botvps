#!/bin/bash

# ========================================================
# VMESS Account Renewal Script for Telegram Bot
# Adapted from user's renew-vmess function
# ========================================================

# Configuration
CONFIG_FILE="/etc/xray/config.json"
LOG_FILE="/var/log/vmess_renew.log" # Log untuk operasi renew VMESS
DOMAIN=$(cat /etc/xray/domain)
IP=$(curl -sS ipv4.icanhazip.com)
ISP=$(cat /etc/xray/isp) # Tambahan: dari script renew-vmess Anda
CITY=$(cat /etc/xray/city) # Tambahan: dari script renew-vmess Anda

# --- Input Validation ---
if [ "$#" -ne 3 ]; then
    echo "❌ Error: Invalid arguments"
    echo "Usage: $0 <username> <days_to_add> <admin_telegram_id>"
    exit 1
fi

USERNAME="$1"
DAYS="$2"
ADMIN_ID="$3"

# --- Validation Functions ---
validate_username() {
    # Cek di config.json untuk pola #vmg atau #vm
    if ! grep -q -E "^#vmg $USERNAME |^#vm $USERNAME " "$CONFIG_FILE"; then
        echo "❌ Error: User $USERNAME not found in VMESS configuration."
        exit 1
    fi
}

validate_days() {
    if ! [[ "$DAYS" =~ ^[0-9]+$ && "$DAYS" -gt 0 ]]; then
        echo "❌ Error: Days to add must be a positive integer."
        exit 1
    fi
}

# --- Renewal Function ---
renew_vmess() {
    # Dapatkan tanggal kadaluwarsa saat ini untuk user dari config.json
    # Kita perlu mengambil yang paling relevan (baik dari #vmg atau #vm)
    # Asumsi #vmg dan #vm memiliki tanggal yang sama untuk user yang sama
    current_exp_line=$(grep -E "^#vmg $USERNAME |^#vm $USERNAME " "$CONFIG_FILE" | head -n 1)
    
    if [ -z "$current_exp_line" ]; then
        echo "❌ Error: Could not find user $USERNAME's entry to determine current expiry."
        exit 1
    fi

    current_exp_date_raw=$(echo "$current_exp_line" | awk '{print $3}')
    
    # Validasi tanggal kadaluwarsa yang diambil
    if ! date -d "$current_exp_date_raw" &>/dev/null; then
        echo "❌ Error: Invalid current expiry date format for $USERNAME: $current_exp_date_raw"
        echo "Please check the user's entry in $CONFIG_FILE."
        exit 1
    fi

    # --- Logika Perhitungan Tanggal dari script renew-vmess Anda ---
    now=$(date +%Y-%m-%d)
    d1=$(date -d "$current_exp_date_raw" +%s) # Tanggal Expired saat ini (detik sejak epoch)
    d2=$(date -d "$now" +%s)                 # Tanggal hari ini (detik sejak epoch)
    
    # Hitung sisa hari dari tanggal expired saat ini
    exp2=$(( (d1 - d2) / 86400 ))
    
    # Jika tanggal sudah lewat atau hari ini (sisa hari <= 0), mulai hitungan dari hari ini
    if [ "$exp2" -lt 0 ]; then
        exp2=0
    fi
    
    # Tambahkan hari baru ke sisa hari yang ada
    exp3=$(($exp2 + $DAYS))
    
    # Hitung tanggal expired yang baru (YYYY-MM-DD)
    new_exp_system=$(date -d "$exp3 days" +"%Y-%m-%d")
    new_exp_display=$(date -d "$new_exp_system" +"%d %b, %Y") # Format untuk ditampilkan

    # --- Update entri di config.json dengan perintah sed yang akurat ---
    # Ganti tanggal kadaluwarsa lama ($current_exp_date_raw) dengan yang baru ($new_exp_system)
    # Ini akan dilakukan untuk kedua jenis penanda (#vmg dan #vm)
    sed -i "s|#vmg $USERNAME $current_exp_date_raw|#vmg $USERNAME $new_exp_system|g" "$CONFIG_FILE"
    sed -i "s|#vm $USERNAME $current_exp_date_raw|#vm $USERNAME $new_exp_system|g" "$CONFIG_FILE"

    # Log the action
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Renewed VMESS $USERNAME for $DAYS days (new expiry: $new_exp_system) by Admin ID: $ADMIN_ID" >> "$LOG_FILE"
}

# --- Main Execution ---
validate_username
validate_days

if renew_vmess; then
    # Prepare output message for Telegram
    echo "✅ <b>VMESS ACCOUNT RENEWED</b>"
    echo "============================="
    echo "<b>Username:</b> <code>$USERNAME</code>"
    echo "<b>Days Added:</b> $DAYS"
    echo "<b>New Expiry:</b> $new_exp_display"
    echo "============================="
    echo "<b>Server Info:</b>"
    echo "<b>IP:</b> $IP"
    echo "<b>Domain:</b> $DOMAIN"
    echo "<b>ISP:</b> $ISP" # Tambahan
    echo "<b>City:</b> $CITY" # Tambahan
    echo "============================="
    echo "<i>Renewed at: $(date '+%d %b, %Y %H:%M:%S')</i>"
else
    echo "❌ <b>RENEWAL FAILED</b>"
    echo "============================="
    echo "<b>Username:</b> <code>$USERNAME</code>"
    echo "<b>Error:</b> An unknown error occurred during renewal."
    exit 1
fi

# Optional: Tambahan notifikasi ke CHATID2 seperti di script Anda
# CATID2 dan URL2 harus didefinisikan di suatu tempat yang dapat diakses script ini
# Contoh: Jika CHATID2 dan URL2 adalah variabel lingkungan atau dari config file yang terpisah.
# Jika tidak, bagian ini bisa dihapus atau diabaikan.
: '
USER_SHORT=$(echo "$USERNAME" | cut -c 1-3) # Ambil 3 karakter pertama username
TIME2=$(date +'%Y-%m-%d %H:%M:%S')
TEXT2="
<code>◇━━━━━━━━━━━━━━◇</code>
<b>    PEMBELIAN VMESS SUCCES </b>
<code>◇━━━━━━━━━━━━━━◇</code>
<b>DOMAIN    :</b> <code>${DOMAIN} </code>
<b>ISP       :</b> <code>$ISP $CITY </code>
<b>DATE      :</b> <code>${TIME2} WIB </code>
<b>DETAIL    :</b> <code>Trx VMESS </code>
<b>USER      :</b> <code>${USER_SHORT}xxx </code>
<b>DURASI    :</b> <code>$DAYS Hari </code>
<code>◇━━━━━━━━━━━━━━◇</code>
<i> Renew Account From Server..</i>
"
# Pastikan $CHATID2 dan $URL2 didefinisikan di lingkungan atau file config terpisah
# curl -s --max-time $TIMES -d "chat_id=$CHATID2&disable_web_page_preview=1&text=$TEXT2&parse_mode=html" $URL2 >/dev/null
'

exit 0
