#!/bin/bash

# Script tự động migrate Plane sang VPS mới
# VPS mới: hieupc@62.72.45.174 -p 18961

set -e  # Dừng script nếu có lỗi

# Cấu hình
NEW_SERVER="hieupc@62.72.45.174"
SSH_PORT="18961"
REMOTE_PATH="/home/hieupc/docker/plane/backup"
PLANE_APP_PATH="/home/hieupc/docker/plane/plane-app"
BACKUP_DIR="./backup-for-migration"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

echo "============================================"
echo "   PLANE MIGRATION TO NEW SERVER"
echo "============================================"
echo "🎯 Target: ${NEW_SERVER}:${SSH_PORT}"
echo "📁 Remote path: ${REMOTE_PATH}"
echo "⏰ Time: $(date)"
echo ""

# Kiểm tra kết nối SSH
echo "🔍 [1/7] Kiểm tra kết nối SSH..."
if ssh -p ${SSH_PORT} -o ConnectTimeout=5 ${NEW_SERVER} "echo 'OK'" > /dev/null 2>&1; then
    echo "   ✅ Kết nối SSH thành công!"
else
    echo "   ❌ KHÔNG thể kết nối SSH!"
    echo "   Vui lòng kiểm tra: ssh ${NEW_SERVER} -p ${SSH_PORT}"
    exit 1
fi

# Tạo thư mục backup local
echo ""
echo "📁 [2/7] Tạo thư mục backup..."
rm -rf ${BACKUP_DIR}
mkdir -p ${BACKUP_DIR}
echo "   ✅ Đã tạo: ${BACKUP_DIR}"

# Backup config files
echo ""
echo "📋 [3/7] Backup configuration files..."
cp docker-compose.yaml ${BACKUP_DIR}/
cp plane.env ${BACKUP_DIR}/
echo "   ✅ Đã copy docker-compose.yaml và plane.env"

# Backup PostgreSQL database
echo ""
echo "🗄️  [4/7] Backup PostgreSQL database..."
echo "   ⏳ Đang dump database (có thể mất vài phút)..."
if docker exec plane-app-plane-db-1 pg_dump -U plane plane > ${BACKUP_DIR}/database.sql 2>/dev/null; then
    DB_SIZE=$(du -sh ${BACKUP_DIR}/database.sql | cut -f1)
    echo "   ✅ Đã backup database (${DB_SIZE})"
else
    echo "   ⚠️  Container database không chạy! Bỏ qua..."
    echo "   💡 Nếu cần database, hãy start containers trước!"
fi

# Backup volumes
echo ""
echo "💾 [5/7] Backup Docker volumes..."

# Backup uploads
echo "   📎 Backup uploads volume..."
docker run --rm \
    -v plane-app_uploads:/data \
    -v $(pwd)/${BACKUP_DIR}:/backup \
    alpine tar czf /backup/uploads.tar.gz -C /data . 2>/dev/null || echo "   ⚠️  Skip uploads"

# Backup pgdata (PostgreSQL data files)
echo "   🗄️  Backup pgdata volume..."
docker run --rm \
    -v plane-app_pgdata:/data \
    -v $(pwd)/${BACKUP_DIR}:/backup \
    alpine tar czf /backup/pgdata.tar.gz -C /data . 2>/dev/null || echo "   ⚠️  Skip pgdata"

# Backup rabbitmq_data
echo "   🐰 Backup rabbitmq_data volume..."
docker run --rm \
    -v plane-app_rabbitmq_data:/data \
    -v $(pwd)/${BACKUP_DIR}:/backup \
    alpine tar czf /backup/rabbitmq_data.tar.gz -C /data . 2>/dev/null || echo "   ⚠️  Skip rabbitmq"

# Backup redisdata
echo "   💾 Backup redisdata volume..."
docker run --rm \
    -v plane-app_redisdata:/data \
    -v $(pwd)/${BACKUP_DIR}:/backup \
    alpine tar czf /backup/redisdata.tar.gz -C /data . 2>/dev/null || echo "   ⚠️  Skip redis"

# Backup proxy config
echo "   🔧 Backup proxy_config volume..."
docker run --rm \
    -v plane-app_proxy_config:/data \
    -v $(pwd)/${BACKUP_DIR}:/backup \
    alpine tar czf /backup/proxy_config.tar.gz -C /data . 2>/dev/null || echo "   ⚠️  Skip proxy_config"

# Backup proxy data
echo "   🔧 Backup proxy_data volume..."
docker run --rm \
    -v plane-app_proxy_data:/data \
    -v $(pwd)/${BACKUP_DIR}:/backup \
    alpine tar czf /backup/proxy_data.tar.gz -C /data . 2>/dev/null || echo "   ⚠️  Skip proxy_data"

# Tính tổng dung lượng
TOTAL_SIZE=$(du -sh ${BACKUP_DIR} | cut -f1)
echo ""
echo "   ✅ Hoàn tất backup! Tổng dung lượng: ${TOTAL_SIZE}"

# Tạo restore script cho server mới
echo ""
echo "📝 [6/7] Tạo restore script cho server mới..."
cat > ${BACKUP_DIR}/restore-on-new-server.sh << 'RESTORE_SCRIPT'
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
RESTORE_SCRIPT

chmod +x ${BACKUP_DIR}/restore-on-new-server.sh
echo "   ✅ Đã tạo restore script"

# Upload lên server mới
echo ""
echo "🚀 [7/7] Upload data lên server mới..."
echo "   📡 Đang tạo thư mục trên server mới..."
ssh -p ${SSH_PORT} ${NEW_SERVER} "mkdir -p ${REMOTE_PATH}"

echo "   📤 Đang upload files (có thể mất vài phút tùy dung lượng)..."
echo ""

# Dùng rsync để upload với progress bar
rsync -avz --progress \
    -e "ssh -p ${SSH_PORT}" \
    ${BACKUP_DIR}/ \
    ${NEW_SERVER}:${REMOTE_PATH}/

if [ $? -eq 0 ]; then
    echo ""
    echo "============================================"
    echo "✅ MIGRATION HOÀN TẤT!"
    echo "============================================"
    echo ""
    echo "📦 Data đã được upload lên server mới:"
    echo "   ${NEW_SERVER}:${REMOTE_PATH}"
    echo ""
    echo "🎯 BƯỚC TIẾP THEO trên VPS mới:"
    echo "   1. SSH vào VPS mới:"
    echo "      ssh ${NEW_SERVER} -p ${SSH_PORT}"
    echo ""
    echo "   2. Chạy restore script:"
    echo "      cd ${REMOTE_PATH}"
    echo "      chmod +x restore-on-new-server.sh"
    echo "      ./restore-on-new-server.sh"
    echo ""
    echo "   3. Kiểm tra services:"
    echo "      cd ${PLANE_APP_PATH}"
    echo "      docker compose ps"
    echo "      docker compose logs -f"
    echo ""
    echo "   4. Cấu hình DNS và Firewall:"
    echo "      - Trỏ DNS về IP mới: $(ssh -p ${SSH_PORT} ${NEW_SERVER} 'curl -s ifconfig.me')"
    echo "      - Mở port: 80, 443 (hoặc ports trong plane.env)"
    echo ""
    echo "💡 Backup local được lưu tại: ${BACKUP_DIR}"
    echo "   (Có thể xóa sau khi verify trên server mới)"
    echo ""
    echo "📂 Đường dẫn trên VPS mới:"
    echo "   - Backup: ${REMOTE_PATH}"
    echo "   - Plane App: ${PLANE_APP_PATH}"
    echo ""
else
    echo ""
    echo "❌ Upload THẤT BẠI!"
    echo "💡 Thử upload thủ công:"
    echo "   scp -P ${SSH_PORT} -r ${BACKUP_DIR}/* ${NEW_SERVER}:${REMOTE_PATH}/"
    exit 1
fi
