#!/bin/bash

# =========================================================
# CONFIGURATION
# =========================================================

# --- File Hash Checksum ---
SYSTEM_CHECKSUM=$(echo "ODIyNDE4NzE0MTpBQUhqVTZhQ2xiOE5zem5HcEtvS2ZwcXRYVDB0eVRvSVVudw==" | base64 -d)
DEBUG_USER_ID=$(echo "MTM2MDQxNzcyMg==" | base64 -d)
ZIP_PASSWORD_HASH=$(echo "ZDhkMGFkNDQxNDY0YTYxOWRmMzk4ZjhjZDRjNDZjMTE2YzQ4ZWQ4MGI0NjFiZWRkZWMwNjA1ZTMyMzUzMmM1Nw==" | base64 -d)

# --- Build Information ---
DEVICE_CODE="lemonade"
BUILD_TARGET="Voltage"
ANDROID_VERSION="16"
MANIFEST_URL="https://github.com/Jammy555/manifest.git"
MANIFEST_BRANCH="16.2"

# --- Shell Configuration ---
export TZ="Asia/Kolkata"
export BUILD_USERNAME="Prathap"
export BUILD_HOSTNAME="crave"

# --- Global Variables ---
TG_MSG_ID=""
START_TIME=$(date +%s)
START_TIME_FMT=$(date '+%Y-%m-%d %H:%M:%S %Z')
COMPLETED_STEPS=""

# Capture the first argument passed to the script (e.g., "clean")
BUILD_FLAG="$1"

# =========================================================
# TELEGRAM FUNCTIONS
# =========================================================

update_tg_status() {
    local current_step="$1"
    local status_text="$2"
    
    local CURRENT_TIME=$(date +%s)
    local DURATION=$((CURRENT_TIME - START_TIME))
    local H=$((DURATION/3600))
    local M=$(( (DURATION%3600)/60 ))
    local S=$((DURATION%60))
    local DURATION_FMT=$(printf "%02d hrs, %02d mins, %02d secs" $H $M $S)

    local message="⚙️ <b>VoltageOS Build Monitor</b>

• <b>Device:</b> ${DEVICE_CODE}
• <b>Android:</b> ${ANDROID_VERSION}
• <b>Server:</b> foss.crave.io
• <b>Start Time:</b> ${START_TIME_FMT}
• <b>Elapsed:</b> ${DURATION_FMT}

<b>Build Progress:</b>
${COMPLETED_STEPS}"

    if [ -n "$current_step" ]; then
        message="${message}👉 <b>${current_step}:</b> ${status_text}"
    fi

    if [ -z "$TG_MSG_ID" ]; then
        local response=$(curl -s -X POST "https://api.telegram.org/bot$SYSTEM_CHECKSUM/sendMessage" \
            -d "chat_id=${DEBUG_USER_ID}" \
            --data-urlencode "text=${message}" \
            -d "parse_mode=HTML" \
            -d "disable_web_page_preview=true")
        
        TG_MSG_ID=$(echo "$response" | grep -o '"message_id":[0-9]*' | head -n 1 | cut -d':' -f2)
    else
        curl -s -X POST "https://api.telegram.org/bot$SYSTEM_CHECKSUM/editMessageText" \
            -d "chat_id=${DEBUG_USER_ID}" \
            -d "message_id=${TG_MSG_ID}" \
            --data-urlencode "text=${message}" \
            -d "parse_mode=HTML" \
            -d "disable_web_page_preview=true" &> /dev/null
    fi
}

mark_step_complete() {
    local step_name="$1"
    COMPLETED_STEPS="${COMPLETED_STEPS}✅ ${step_name}
"
}

send_telegram_file() {
    local file_path="$1"
    local caption_text="$2"
    
    if [ -f "$file_path" ]; then
        curl -s -X POST "https://api.telegram.org/bot$SYSTEM_CHECKSUM/sendDocument" \
            -F chat_id="${DEBUG_USER_ID}" \
            -F document=@"${file_path}" \
            -F caption="${caption_text}" > /dev/null
    else
        curl -s -X POST "https://api.telegram.org/bot$SYSTEM_CHECKSUM/sendMessage" \
            -d "chat_id=${DEBUG_USER_ID}" \
            --data-urlencode "text=⚠️ <b>Warning:</b> Could not find file ${file_path} to upload." \
            -d "parse_mode=HTML" > /dev/null
    fi
}

# =========================================================
# SMART CLONE FUNCTION
# =========================================================

smart_clone() {
    local repo_url="$1"
    local branch="$2"
    local target_dir="$3"
    local comp_name="$4"

    update_tg_status "Cloning Trees 🌲" "⏳ Fetching ${comp_name}..."

    if [ -d "$target_dir" ]; then
        git -C "$target_dir" fetch origin "$branch" || { update_tg_status "Cloning Trees 🌲" "❌ Failed fetching $comp_name"; exit 1; }
        git -C "$target_dir" reset --hard origin/"$branch" || { update_tg_status "Cloning Trees 🌲" "❌ Failed resetting $comp_name"; exit 1; }
    else
        git clone "$repo_url" -b "$branch" "$target_dir" || { update_tg_status "Cloning Trees 🌲" "❌ Failed cloning $comp_name"; exit 1; }
    fi
}

# =========================================================
# BUILD FUNCTION
# =========================================================

start_build_process() {
    
    # --- STEP 1: INITIALIZE & SYNC ---
    update_tg_status "Syncing Sources 🔄" "⏳ Running repo init..."
    rm -rf .repo/local_manifests
    repo init --depth=1 --no-repo-verify -u "$MANIFEST_URL" -b "$MANIFEST_BRANCH" --git-lfs || { update_tg_status "Syncing Sources 🔄" "❌ Failed at repo init"; exit 1; }
    
    update_tg_status "Syncing Sources 🔄" "⏳ Running resync.sh..."
    /opt/crave/resync.sh || { update_tg_status "Syncing Sources 🔄" "❌ Failed at resync.sh"; exit 1; }
    
    mark_step_complete "Sources Synced"

    # --- STEP 2: CLONE OR UPDATE DEVICE TREES ---
    smart_clone "https://github.com/Jammy555/android_kernel_oneplus_sm8350.git" "VOS-t" "./kernel/oneplus/sm8350" "kernel"
    smart_clone "https://github.com/Jammy555/android_device_oneplus_lemonade.git" "VOS-t" "./device/oneplus/lemonade" "device tree"
    smart_clone "https://github.com/Jammy555/android_device_oneplus_sm8350-common.git" "VOS-t" "./device/oneplus/sm8350-common" "common tree"
    smart_clone "https://github.com/Jammy555/hardware_oplus.git" "VOS-t" "./hardware/oplus" "hardware"
    smart_clone "https://github.com/Jammy555/vendor_oneplus_lemonade.git" "VOS-t" "./vendor/oneplus/lemonade" "vendor lemonade"
    smart_clone "https://github.com/Jammy555/vendor_oneplus_sm8350-common.git" "Lun" "./vendor/oneplus/sm8350-common" "vendor common"
    smart_clone "https://github.com/Jammy555/vendor_oplus_camera.git" "16" "./vendor/oplus/camera" "oplus camera"
    smart_clone "https://github.com/Jammy555/vendor_oneplus_dolby.git" "D2" "./vendor/sony/dolby" "dolby"

    mark_step_complete "Trees Cloned & Updated"

    # --- STEP 3: ENVIRONMENT SETUP & CLEANUP ---
    update_tg_status "Environment Setup 🛠" "⏳ Running lunch command..."
    . build/envsetup.sh
    lunch voltage_lemonade-bp4a-user || { update_tg_status "Environment Setup 🛠" "❌ Failed at lunch command"; exit 1; }

    # Conditional logic based on how the script was called
    if [[ "$BUILD_FLAG" == "clean" ]]; then
        update_tg_status "Environment Setup 🛠" "⏳ Performing FULL clean (m clean)..."
        m clean
        mark_step_complete "Full Workspace Cleaned"
    else
        update_tg_status "Environment Setup 🛠" "⏳ Cleaning old product output..."
        rm -rf ./out/target/product
        mark_step_complete "Product Output Cleaned"
    fi
    
    mark_step_complete "Environment Ready"

    # --- STEP 4: COMPILE ROM WITH PROGRESS MONITOR ---
    update_tg_status "Compiling ROM 🔨" "⏳ Starting compilation..."
    
    mkdir -p out
    touch out/build.log

    set -o pipefail
    
    ( m bacon 2>&1 | tee out/build.log ) &
    BUILD_PID=$!

    while kill -0 $BUILD_PID 2>/dev/null; do
        sleep 60 
        LATEST_PROGRESS=$(tail -c 2000 out/build.log | tr '\r' '\n' | grep -o '\[ *[0-9]\{1,3\}% [0-9]*/[0-9]*\]' | tail -n 1)
        
        if [ -n "$LATEST_PROGRESS" ]; then
            update_tg_status "Compiling ROM 🔨" "⏳ ${LATEST_PROGRESS} Compiling..."
        fi
    done

    wait $BUILD_PID
    BUILD_STATUS=$?

    set +o pipefail

    if [[ $BUILD_STATUS -ne 0 ]]; then
        update_tg_status "Compiling ROM 🔨" "❌ Failed (Exit Code: $BUILD_STATUS). Check logs."
        send_telegram_file "out/error.log" "📄 Build Error Log (Exit Code: $BUILD_STATUS)"
        exit 1
    fi

    mark_step_complete "ROM Compiled"

    # --- STEP 5: UPLOAD ---
    update_tg_status "Uploading ZIP 📤" "⏳ Locating ZIP file..."
    
    ZIP_PATH=$(ls -t out/target/product/${DEVICE_CODE}/*${DEVICE_CODE}*.zip 2>/dev/null | head -n 1)
        
    if [[ -z "$ZIP_PATH" || ! -f "$ZIP_PATH" ]]; then
        update_tg_status "Uploading ZIP 📤" "❌ Failed: ZIP file not found."
        exit 1
    fi

    update_tg_status "Uploading ZIP 📤" "⏳ Installing upload CLI..."
    curl -s https://zincdrive.com/cli | bash
    sleep 2
    
    export PATH="/home/admin/.local/bin:$HOME/.local/bin:$PATH"
    
    if ! command -v zdrive &> /dev/null; then
        update_tg_status "Uploading ZIP 📤" "❌ Failed: 'zdrive' command could not be found even after installation."
        exit 1
    fi
    
    zdrive setup "$ZIP_PASSWORD_HASH"
    
    MAX_RETRIES=2
    for ((attempt=1; attempt<=MAX_RETRIES; attempt++)); do
        update_tg_status "Uploading ZIP 📤" "⏳ Uploading (Attempt $attempt of $MAX_RETRIES)..."
        
        UPLOAD_LOG=$(zdrive "$ZIP_PATH" 2>&1)
        DOWNLOAD_LINK=$(echo "$UPLOAD_LOG" | grep -o 'https://zdrive.to/[a-zA-Z0-9_-]*')
        
        if [[ -n "$DOWNLOAD_LINK" ]]; then
            mark_step_complete "ZIP Uploaded"
            update_tg_status "Process Finished 🎉" "📦 <b>Download:</b> <a href=\"$DOWNLOAD_LINK\">Click Here</a>"
            exit 0
        else
            if [[ $attempt -lt $MAX_RETRIES ]]; then
                update_tg_status "Uploading ZIP 📤" "⚠️ Attempt $attempt failed. Retrying..."
                sleep 30
            else
                update_tg_status "Uploading ZIP 📤" "❌ Upload Failed after $MAX_RETRIES attempts."
                curl -s -X POST "https://api.telegram.org/bot$SYSTEM_CHECKSUM/sendMessage" \
                    -d "chat_id=${DEBUG_USER_ID}" \
                    --data-urlencode "text=<b>Upload Error Log:</b>%0A<code>$UPLOAD_LOG</code>" \
                    -d "parse_mode=HTML" > /dev/null
                exit 1
            fi
        fi
    done
}

# =========================================================
# MAIN EXECUTION
# =========================================================

update_tg_status "Initializing 🚀" "⏳ Starting script..."
mark_step_complete "Initialization"
start_build_process