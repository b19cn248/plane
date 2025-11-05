#!/bin/bash

echo "============================================"
echo "   RESTORE PLANE ON NEW SERVER"
echo "============================================"

set -e  # Dừng nếu có lỗi

# Kiểm tra Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker chưa được cài đặt!"
    echo "💡 Cài Docker: curl -fsSL https://get.docker.com | sh"
    exit 1
fi

# Lấy đường dẫn hiện tại (backup folder)
BACKUP_DIR=$(pwd)
PLANE_DIR="/home/hieupc/docker/plane/plane-app"

echo ""
echo "📋 [1/5] Copy config files..."
mkdir -p ${PLANE_DIR}
cp ${BACKUP_DIR}/docker-compose.yaml ${PLANE_DIR}/
cp ${BACKUP_DIR}/plane.env ${PLANE_DIR}/
echo "   ✅ Đã copy config files vào ${PLANE_DIR}"

# Tạo volumes và restore data
echo ""
echo "💾 [2/5] Tạo Docker volumes..."
docker volume create plane-app_pgdata
docker volume create plane-app_redisdata
docker volume create plane-app_uploads
docker volume create plane-app_rabbitmq_data
docker volume create plane-app_proxy_config
docker volume create plane-app_proxy_data
docker volume create plane-app_logs_api
docker volume create plane-app_logs_worker
docker volume create plane-app_logs_beat-worker
docker volume create plane-app_logs_migrator
echo "   ✅ Đã tạo volumes"

# Restore volumes
echo ""
echo "📦 [3/5] Restore volumes data..."

if [ -f "${BACKUP_DIR}/pgdata.tar.gz" ]; then
    echo "   🗄️  Restore pgdata..."
    docker run --rm -v plane-app_pgdata:/data -v ${BACKUP_DIR}:/backup alpine sh -c "cd /data && tar xzf /backup/pgdata.tar.gz"
fi

if [ -f "${BACKUP_DIR}/uploads.tar.gz" ]; then
    echo "   📎 Restore uploads..."
    docker run --rm -v plane-app_uploads:/data -v ${BACKUP_DIR}:/backup alpine sh -c "cd /data && tar xzf /backup/uploads.tar.gz"
fi

if [ -f "${BACKUP_DIR}/rabbitmq_data.tar.gz" ]; then
    echo "   🐰 Restore rabbitmq_data..."
    docker run --rm -v plane-app_rabbitmq_data:/data -v ${BACKUP_DIR}:/backup alpine sh -c "cd /data && tar xzf /backup/rabbitmq_data.tar.gz"
fi

if [ -f "${BACKUP_DIR}/redisdata.tar.gz" ]; then
    echo "   💾 Restore redisdata..."
    docker run --rm -v plane-app_redisdata:/data -v ${BACKUP_DIR}:/backup alpine sh -c "cd /data && tar xzf /backup/redisdata.tar.gz"
fi

if [ -f "${BACKUP_DIR}/proxy_config.tar.gz" ]; then
    echo "   🔧 Restore proxy_config..."
    docker run --rm -v plane-app_proxy_config:/data -v ${BACKUP_DIR}:/backup alpine sh -c "cd /data && tar xzf /backup/proxy_config.tar.gz"
fi

if [ -f "${BACKUP_DIR}/proxy_data.tar.gz" ]; then
    echo "   🔧 Restore proxy_data..."
    docker run --rm -v plane-app_proxy_data:/data -v ${BACKUP_DIR}:/backup alpine sh -c "cd /data && tar xzf /backup/proxy_data.tar.gz"
fi

echo "   ✅ Đã restore volumes"

# Import database nếu có file SQL
echo ""
echo "🗄️  [4/5] Import PostgreSQL database..."
if [ -f "${BACKUP_DIR}/database.sql" ]; then
    echo "   ⏳ Đang start PostgreSQL container..."
    cd ${PLANE_DIR}
    docker compose up -d plane-db

    echo "   ⏳ Chờ PostgreSQL khởi động (30 giây)..."
    sleep 30

    echo "   📥 Đang import database..."
    docker exec -i $(docker compose ps -q plane-db) psql -U plane plane < ${BACKUP_DIR}/database.sql
    echo "   ✅ Đã import database"
else
    echo "   ℹ️  Không tìm thấy database.sql, bỏ qua..."
fi

# Start services
echo ""
echo "🚀 [5/5] Start tất cả Plane services..."
cd ${PLANE_DIR}
docker compose up -d

echo ""
echo "============================================"
echo "✅ RESTORE HOÀN TẤT!"
echo "============================================"
echo ""
echo "📊 Kiểm tra status:"
echo "   cd ${PLANE_DIR}"
echo "   docker compose ps"
echo ""
echo "📝 Xem logs:"
echo "   docker compose logs -f"
echo ""
echo "🔍 Kiểm tra health của containers:"
echo "   docker compose ps"
echo "   docker compose logs api | tail -50"
echo ""
echo "🌐 Cấu hình domain trong plane.env:"
echo "   APP_DOMAIN=$(grep APP_DOMAIN ${PLANE_DIR}/plane.env | cut -d= -f2)"
echo ""
echo "⚠️  LƯU Ý:"
echo "   - Kiểm tra DNS đã trỏ về IP mới chưa"
echo "   - Cấu hình firewall mở port 80, 443 (hoặc custom ports)"
echo "   - Nếu dùng SSL, kiểm tra CERT_EMAIL trong plane.env"
echo ""
