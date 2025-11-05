#!/bin/bash

# Script copy trực tiếp Docker volumes từ VPS cũ sang VPS mới
# Nhanh hơn và hiệu quả hơn so với tar/untar

set -e

# Cấu hình
NEW_SERVER="hieupc@62.72.45.174"
SSH_PORT="18961"
REMOTE_DOCKER_VOLUMES="/var/lib/docker/volumes"

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
echo "   DIRECT VOLUME MIGRATION"
echo "============================================"
echo "🎯 Target: ${NEW_SERVER}:${SSH_PORT}"
echo "📦 Volumes: ${#VOLUMES[@]} volumes"
echo "⏰ Time: $(date)"
echo ""

# Kiểm tra kết nối SSH
echo "🔍 [1/5] Kiểm tra kết nối SSH..."
if ssh -p ${SSH_PORT} -o ConnectTimeout=5 ${NEW_SERVER} "echo 'OK'" > /dev/null 2>&1; then
    echo "   ✅ Kết nối SSH thành công!"
else
    echo "   ❌ KHÔNG thể kết nối SSH!"
    echo "   Vui lòng kiểm tra: ssh ${NEW_SERVER} -p ${SSH_PORT}"
    exit 1
fi

# Kiểm tra Docker trên VPS mới
echo ""
echo "🐳 [2/5] Kiểm tra Docker trên VPS mới..."
if ssh -p ${SSH_PORT} ${NEW_SERVER} "docker --version" > /dev/null 2>&1; then
    echo "   ✅ Docker đã được cài đặt"
else
    echo "   ❌ Docker chưa được cài đặt trên VPS mới!"
    echo "   Cài Docker: curl -fsSL https://get.docker.com | sh"
    exit 1
fi

# Copy config files trước
echo ""
echo "📋 [3/5] Copy config files..."
PLANE_APP_PATH="/home/hieupc/docker/plane/plane-app"
ssh -p ${SSH_PORT} ${NEW_SERVER} "mkdir -p ${PLANE_APP_PATH}"

rsync -avz --progress \
    -e "ssh -p ${SSH_PORT}" \
    docker-compose.yaml plane.env \
    ${NEW_SERVER}:${PLANE_APP_PATH}/

echo "   ✅ Đã copy config files"

# Tạo volumes trên VPS mới
echo ""
echo "💾 [4/5] Tạo volumes trên VPS mới..."
for volume in "${VOLUMES[@]}"; do
    echo "   📦 Tạo volume: ${volume}"
    ssh -p ${SSH_PORT} ${NEW_SERVER} "docker volume create ${volume}" > /dev/null 2>&1 || true
done
echo "   ✅ Đã tạo tất cả volumes"

# Copy volumes data
echo ""
echo "🚀 [5/5] Copy volumes data (có thể mất nhiều thời gian)..."
echo ""

for volume in "${VOLUMES[@]}"; do
    echo "📦 Copy volume: ${volume}"

    # Check xem volume có data không
    VOLUME_SIZE=$(docker run --rm -v ${volume}:/data alpine du -sh /data 2>/dev/null | cut -f1 || echo "0")
    echo "   📊 Kích thước: ${VOLUME_SIZE}"

    # Rsync trực tiếp volume data với sudo
    echo "   ⏳ Đang copy..."

    # Dùng rsync với sudo để copy trực tiếp folder volumes
    sudo rsync -avz --progress --delete \
        -e "ssh -p ${SSH_PORT}" \
        /var/lib/docker/volumes/${volume}/_data/ \
        ${NEW_SERVER}:/var/lib/docker/volumes/${volume}/_data/ \
        2>&1 | grep -E "sent|total size|speedup" || true

    if [ $? -eq 0 ]; then
        echo "   ✅ Đã copy ${volume}"
    else
        echo "   ⚠️  Lỗi khi copy ${volume}"
    fi
    echo ""
done

echo "============================================"
echo "✅ MIGRATION HOÀN TẤT!"
echo "============================================"
echo ""
echo "🎯 BƯỚC TIẾP THEO trên VPS mới:"
echo "   1. SSH vào VPS mới:"
echo "      ssh ${NEW_SERVER} -p ${SSH_PORT}"
echo ""
echo "   2. Kiểm tra volumes:"
echo "      docker volume ls | grep plane-app"
echo "      docker run --rm -v plane-app_pgdata:/data alpine du -sh /data"
echo ""
echo "   3. Start Plane services:"
echo "      cd ${PLANE_APP_PATH}"
echo "      docker compose up -d"
echo ""
echo "   4. Kiểm tra containers:"
echo "      docker compose ps"
echo "      docker compose logs -f"
echo ""
echo "💡 Lưu ý:"
echo "   - Tất cả volumes đã được copy trực tiếp"
echo "   - Không cần chạy restore script"
echo "   - Data đã sẵn sàng để sử dụng"
echo ""
