#!/bin/bash

# Script copy trực tiếp Docker volumes KHÔNG CẦN SUDO
# Dùng Docker containers để access và copy volumes
# Phù hợp khi không có quyền sudo trên VPS

set -e

# Cấu hình
NEW_SERVER="hieupc@62.72.45.174"
SSH_PORT="18961"
TEMP_BACKUP_DIR="/tmp/plane-volumes-sync"
REMOTE_TEMP_DIR="/tmp/plane-volumes-sync"

# Danh sách volumes cần copy
VOLUMES=(
    "plane-app_pgdata"
    "plane-app_uploads"
    "plane-app_redisdata"
    "plane-app_rabbitmq_data"
    "plane-app_proxy_config"
    "plane-app_proxy_data"
    "plane-app_logs_api"
    "plane-app_logs_worker"
    "plane-app_logs_beat-worker"
    "plane-app_logs_migrator"
)

echo "============================================"
echo "   DIRECT VOLUME MIGRATION (NO SUDO)"
echo "============================================"
echo "🎯 Target: ${NEW_SERVER}:${SSH_PORT}"
echo "📦 Volumes: ${#VOLUMES[@]} volumes"
echo "⏰ Time: $(date)"
echo ""

# Kiểm tra kết nối SSH
echo "🔍 [1/6] Kiểm tra kết nối SSH..."
if ssh -p ${SSH_PORT} -o ConnectTimeout=5 ${NEW_SERVER} "echo 'OK'" > /dev/null 2>&1; then
    echo "   ✅ Kết nối SSH thành công!"
else
    echo "   ❌ KHÔNG thể kết nối SSH!"
    exit 1
fi

# Tạo thư mục temp
echo ""
echo "📁 [2/6] Tạo thư mục temp..."
mkdir -p ${TEMP_BACKUP_DIR}
ssh -p ${SSH_PORT} ${NEW_SERVER} "mkdir -p ${REMOTE_TEMP_DIR}"
echo "   ✅ Đã tạo thư mục temp"

# Copy config files
echo ""
echo "📋 [3/6] Copy config files..."
PLANE_APP_PATH="/home/hieupc/docker/plane/plane-app"
ssh -p ${SSH_PORT} ${NEW_SERVER} "mkdir -p ${PLANE_APP_PATH}"

rsync -avz --progress \
    -e "ssh -p ${SSH_PORT}" \
    docker-compose.yaml plane.env \
    ${NEW_SERVER}:${PLANE_APP_PATH}/

echo "   ✅ Đã copy config files"

# Tạo volumes trên VPS mới
echo ""
echo "💾 [4/6] Tạo volumes trên VPS mới..."
for volume in "${VOLUMES[@]}"; do
    echo "   📦 Tạo volume: ${volume}"
    ssh -p ${SSH_PORT} ${NEW_SERVER} "docker volume create ${volume}" > /dev/null 2>&1 || true
done
echo "   ✅ Đã tạo tất cả volumes"

# Copy volumes data qua rsync
echo ""
echo "🚀 [5/6] Copy volumes data..."
echo ""

for volume in "${VOLUMES[@]}"; do
    echo "📦 Copy volume: ${volume}"

    # Export volume data ra temp folder trên VPS cũ
    echo "   📤 Export ${volume} từ VPS cũ..."
    VOLUME_BACKUP="${TEMP_BACKUP_DIR}/${volume}"
    mkdir -p ${VOLUME_BACKUP}

    # Dùng docker để copy data ra temp folder
    docker run --rm \
        -v ${volume}:/source:ro \
        -v ${VOLUME_BACKUP}:/dest \
        alpine sh -c "cp -a /source/. /dest/" > /dev/null 2>&1

    # Check size
    VOLUME_SIZE=$(du -sh ${VOLUME_BACKUP} 2>/dev/null | cut -f1 || echo "0")
    echo "   📊 Kích thước: ${VOLUME_SIZE}"

    # Rsync sang VPS mới
    echo "   ⏳ Rsync sang VPS mới..."
    rsync -avz --progress --delete \
        -e "ssh -p ${SSH_PORT}" \
        ${VOLUME_BACKUP}/ \
        ${NEW_SERVER}:${REMOTE_TEMP_DIR}/${volume}/ \
        2>&1 | grep -E "sent|total size|speedup" || true

    # Import vào volume trên VPS mới
    echo "   📥 Import vào volume trên VPS mới..."
    ssh -p ${SSH_PORT} ${NEW_SERVER} \
        "docker run --rm \
            -v ${volume}:/dest \
            -v ${REMOTE_TEMP_DIR}/${volume}:/source:ro \
            alpine sh -c 'cp -a /source/. /dest/'" > /dev/null 2>&1

    echo "   ✅ Đã copy ${volume}"

    # Clean up temp trên VPS cũ
    rm -rf ${VOLUME_BACKUP}
    echo ""
done

# Clean up
echo ""
echo "🧹 [6/6] Dọn dẹp..."
rm -rf ${TEMP_BACKUP_DIR}
ssh -p ${SSH_PORT} ${NEW_SERVER} "rm -rf ${REMOTE_TEMP_DIR}"
echo "   ✅ Đã dọn dẹp temp folders"

echo ""
echo "============================================"
echo "✅ MIGRATION HOÀN TẤT!"
echo "============================================"
echo ""
echo "🎯 BƯỚC TIẾP THEO trên VPS mới:"
echo "   1. SSH vào VPS mới:"
echo "      ssh ${NEW_SERVER} -p ${SSH_PORT}"
echo ""
echo "   2. Verify volumes:"
echo "      docker volume ls | grep plane-app"
echo ""
echo "   3. Check data size:"
for volume in "${VOLUMES[@]}"; do
    echo "      docker run --rm -v ${volume}:/data alpine du -sh /data"
done
echo ""
echo "   4. Start Plane services:"
echo "      cd ${PLANE_APP_PATH}"
echo "      docker compose up -d"
echo ""
echo "   5. Monitor logs:"
echo "      docker compose logs -f"
echo ""
echo "💡 Lưu ý:"
echo "   - Tất cả volumes đã được copy trực tiếp"
echo "   - Data đã sẵn sàng để sử dụng"
echo "   - Không cần restore script"
echo ""
