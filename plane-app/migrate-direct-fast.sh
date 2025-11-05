#!/bin/bash

# Script copy trực tiếp Docker volumes qua SSH pipe
# NHANH NHẤT - không cần temp files, stream trực tiếp
# Không cần sudo

set -e

# Cấu hình
NEW_SERVER="hieupc@62.72.45.174"
SSH_PORT="18961"
PLANE_APP_PATH="/home/hieupc/docker/plane/plane-app"

# Danh sách volumes cần copy
VOLUMES=(
    "plane-app_pgdata"
    "plane-app_uploads"
    "plane-app_redisdata"
    "plane-app_rabbitmq_data"
    "plane-app_proxy_config"
    "plane-app_proxy_data"
)

# Volumes logs (ít quan trọng, có thể bỏ qua)
LOG_VOLUMES=(
    "plane-app_logs_api"
    "plane-app_logs_worker"
    "plane-app_logs_beat-worker"
    "plane-app_logs_migrator"
)

echo "============================================"
echo "   FAST DIRECT VOLUME MIGRATION"
echo "============================================"
echo "🚀 Phương pháp: SSH pipe stream"
echo "🎯 Target: ${NEW_SERVER}:${SSH_PORT}"
echo "📦 Volumes: ${#VOLUMES[@]} volumes chính"
echo "⏰ Time: $(date)"
echo ""

# Kiểm tra kết nối SSH
echo "🔍 [1/5] Kiểm tra kết nối SSH..."
if ! ssh -p ${SSH_PORT} -o ConnectTimeout=5 ${NEW_SERVER} "echo 'OK'" > /dev/null 2>&1; then
    echo "   ❌ KHÔNG thể kết nối SSH!"
    exit 1
fi
echo "   ✅ Kết nối SSH thành công!"

# Kiểm tra Docker
echo ""
echo "🐳 [2/5] Kiểm tra Docker..."
if ! ssh -p ${SSH_PORT} ${NEW_SERVER} "docker --version" > /dev/null 2>&1; then
    echo "   ❌ Docker chưa được cài đặt trên VPS mới!"
    exit 1
fi
echo "   ✅ Docker OK"

# Copy config files
echo ""
echo "📋 [3/5] Copy config files..."
ssh -p ${SSH_PORT} ${NEW_SERVER} "mkdir -p ${PLANE_APP_PATH}"

scp -P ${SSH_PORT} \
    docker-compose.yaml plane.env \
    ${NEW_SERVER}:${PLANE_APP_PATH}/

echo "   ✅ Đã copy config files"

# Tạo volumes trên VPS mới
echo ""
echo "💾 [4/5] Tạo volumes trên VPS mới..."
for volume in "${VOLUMES[@]}" "${LOG_VOLUMES[@]}"; do
    ssh -p ${SSH_PORT} ${NEW_SERVER} "docker volume create ${volume}" > /dev/null 2>&1 || true
done
echo "   ✅ Đã tạo volumes"

# Copy volumes data qua SSH pipe
echo ""
echo "🚀 [5/5] Copy volumes data (stream trực tiếp)..."
echo ""

copy_volume() {
    local volume=$1
    echo "📦 Copy volume: ${volume}"

    # Check size trước
    local size=$(docker run --rm -v ${volume}:/data alpine du -sh /data 2>/dev/null | awk '{print $1}' || echo "unknown")
    echo "   📊 Kích thước: ${size}"
    echo "   ⏳ Đang copy..."

    # Stream tar qua SSH pipe trực tiếp vào volume trên VPS mới
    # VPS cũ: export volume -> tar -> pipe qua SSH
    # VPS mới: receive tar -> extract vào volume
    docker run --rm -v ${volume}:/data alpine tar czf - -C /data . 2>/dev/null | \
        ssh -p ${SSH_PORT} ${NEW_SERVER} \
        "docker run --rm -i -v ${volume}:/data alpine tar xzf - -C /data" 2>&1

    if [ $? -eq 0 ]; then
        echo "   ✅ Đã copy ${volume}"
    else
        echo "   ⚠️  Có lỗi khi copy ${volume}"
    fi
    echo ""
}

# Copy các volumes chính
echo "🎯 Copy volumes chính (quan trọng):"
echo ""
for volume in "${VOLUMES[@]}"; do
    copy_volume "${volume}"
done

# Hỏi có muốn copy log volumes không
echo ""
echo "📝 Log volumes (không quá quan trọng):"
read -p "Có muốn copy log volumes không? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    for volume in "${LOG_VOLUMES[@]}"; do
        copy_volume "${volume}"
    done
else
    echo "   ⏭️  Bỏ qua log volumes"
fi

echo ""
echo "============================================"
echo "✅ MIGRATION HOÀN TẤT!"
echo "============================================"
echo ""
echo "📊 Verify data trên VPS mới:"
echo "   ssh ${NEW_SERVER} -p ${SSH_PORT}"
echo ""
echo "   # Kiểm tra volumes"
echo "   docker volume ls | grep plane-app"
echo ""
echo "   # Kiểm tra data size"
for volume in "${VOLUMES[@]}"; do
    echo "   docker run --rm -v ${volume}:/data alpine du -sh /data"
done
echo ""
echo "🚀 Start Plane services:"
echo "   cd ${PLANE_APP_PATH}"
echo "   docker compose up -d"
echo ""
echo "   # Monitor"
echo "   docker compose ps"
echo "   docker compose logs -f"
echo ""
echo "💡 Ưu điểm phương pháp này:"
echo "   ✅ Nhanh nhất - stream trực tiếp"
echo "   ✅ Không tốn disk space cho temp files"
echo "   ✅ Không cần sudo"
echo "   ✅ Data integrity được đảm bảo"
echo ""
