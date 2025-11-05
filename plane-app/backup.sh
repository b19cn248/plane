#!/bin/bash

# Script backup đơn giản cho Plane
# Dùng cho việc backup định kỳ local

set -e  # Dừng script nếu có lỗi

# Cấu hình
BACKUP_BASE_DIR="./backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="${BACKUP_BASE_DIR}/plane_backup_${TIMESTAMP}"

echo "============================================"
echo "   PLANE BACKUP SCRIPT"
echo "============================================"
echo "⏰ Thời gian: $(date)"
echo "📁 Backup folder: ${BACKUP_DIR}"
echo ""

# Tạo thư mục backup
echo "📁 [1/3] Tạo thư mục backup..."
mkdir -p ${BACKUP_DIR}
echo "   ✅ Đã tạo: ${BACKUP_DIR}"

# Backup config files
echo ""
echo "📋 [2/3] Backup configuration files..."
cp docker-compose.yaml ${BACKUP_DIR}/
cp plane.env ${BACKUP_DIR}/
echo "   ✅ Đã copy docker-compose.yaml và plane.env"

# Backup PostgreSQL database
echo ""
echo "🗄️  [3/3] Backup data..."
echo ""

# Backup database
echo "   🗄️  Backup PostgreSQL database..."
if docker exec plane-app-plane-db-1 pg_dump -U plane plane > ${BACKUP_DIR}/database.sql 2>/dev/null; then
    DB_SIZE=$(du -sh ${BACKUP_DIR}/database.sql | cut -f1)
    echo "      ✅ Database (${DB_SIZE})"
else
    echo "      ⚠️  Container database không chạy! Bỏ qua..."
fi

# Backup uploads
echo "   📎 Backup uploads volume..."
if docker run --rm \
    -v plane-app_uploads:/data \
    -v $(pwd)/${BACKUP_DIR}:/backup \
    alpine tar czf /backup/uploads.tar.gz -C /data . 2>/dev/null; then
    UPLOAD_SIZE=$(du -sh ${BACKUP_DIR}/uploads.tar.gz | cut -f1)
    echo "      ✅ Uploads (${UPLOAD_SIZE})"
else
    echo "      ⚠️  Skip uploads"
fi

# Backup pgdata
echo "   🗄️  Backup pgdata volume..."
if docker run --rm \
    -v plane-app_pgdata:/data \
    -v $(pwd)/${BACKUP_DIR}:/backup \
    alpine tar czf /backup/pgdata.tar.gz -C /data . 2>/dev/null; then
    PGDATA_SIZE=$(du -sh ${BACKUP_DIR}/pgdata.tar.gz | cut -f1)
    echo "      ✅ PGData (${PGDATA_SIZE})"
else
    echo "      ⚠️  Skip pgdata"
fi

# Backup rabbitmq_data
echo "   🐰 Backup rabbitmq_data volume..."
if docker run --rm \
    -v plane-app_rabbitmq_data:/data \
    -v $(pwd)/${BACKUP_DIR}:/backup \
    alpine tar czf /backup/rabbitmq_data.tar.gz -C /data . 2>/dev/null; then
    RABBITMQ_SIZE=$(du -sh ${BACKUP_DIR}/rabbitmq_data.tar.gz | cut -f1)
    echo "      ✅ RabbitMQ (${RABBITMQ_SIZE})"
else
    echo "      ⚠️  Skip rabbitmq"
fi

# Backup redisdata
echo "   💾 Backup redisdata volume..."
if docker run --rm \
    -v plane-app_redisdata:/data \
    -v $(pwd)/${BACKUP_DIR}:/backup \
    alpine tar czf /backup/redisdata.tar.gz -C /data . 2>/dev/null; then
    REDIS_SIZE=$(du -sh ${BACKUP_DIR}/redisdata.tar.gz | cut -f1)
    echo "      ✅ Redis (${REDIS_SIZE})"
else
    echo "      ⚠️  Skip redis"
fi

# Backup proxy config
echo "   🔧 Backup proxy_config volume..."
if docker run --rm \
    -v plane-app_proxy_config:/data \
    -v $(pwd)/${BACKUP_DIR}:/backup \
    alpine tar czf /backup/proxy_config.tar.gz -C /data . 2>/dev/null; then
    echo "      ✅ Proxy config"
else
    echo "      ⚠️  Skip proxy_config"
fi

# Backup proxy data
echo "   🔧 Backup proxy_data volume..."
if docker run --rm \
    -v plane-app_proxy_data:/data \
    -v $(pwd)/${BACKUP_DIR}:/backup \
    alpine tar czf /backup/proxy_data.tar.gz -C /data . 2>/dev/null; then
    echo "      ✅ Proxy data"
else
    echo "      ⚠️  Skip proxy_data"
fi

# Tính tổng dung lượng
echo ""
TOTAL_SIZE=$(du -sh ${BACKUP_DIR} | cut -f1)
echo "============================================"
echo "✅ BACKUP HOÀN TẤT!"
echo "============================================"
echo "📦 Tổng dung lượng: ${TOTAL_SIZE}"
echo "📁 Vị trí: ${BACKUP_DIR}"
echo ""
echo "💡 Để dọn dẹp backups cũ:"
echo "   ls -lt ${BACKUP_BASE_DIR}"
echo "   rm -rf ${BACKUP_BASE_DIR}/plane_backup_YYYYMMDD_HHMMSS"
echo ""
