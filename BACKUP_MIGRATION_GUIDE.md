# Hướng dẫn Backup và Migration Plane

## Tổng quan

Folder này chứa các script tự động để backup và migrate Plane sang VPS mới.

### Các scripts có sẵn:

1. **`backup.sh`** - Script backup đơn giản cho backup định kỳ
2. **`migrate-to-new-server.sh`** - Script tự động migrate toàn bộ Plane sang VPS mới

---

## 1. Backup định kỳ (Local)

Script `backup.sh` giúp bạn backup Plane định kỳ vào folder local.

### Cách sử dụng:

```bash
cd /home/dev/docker/plane/plane-app
./backup.sh
```

### Backup bao gồm:

- ✅ Config files (docker-compose.yaml, plane.env)
- ✅ PostgreSQL database (SQL dump)
- ✅ Docker volumes:
  - uploads (file uploads của users)
  - pgdata (PostgreSQL data files)
  - rabbitmq_data
  - redisdata
  - proxy_config
  - proxy_data

### Backup được lưu tại:

```
./backups/plane_backup_YYYYMMDD_HHMMSS/
```

### Dọn dẹp backups cũ:

```bash
# Xem danh sách backups
ls -lt backups/

# Xóa backup cũ
rm -rf backups/plane_backup_20241104_120000
```

---

## 2. Migration sang VPS mới

Script `migrate-to-new-server.sh` tự động:
1. Backup toàn bộ data từ VPS hiện tại
2. Upload lên VPS mới qua SSH/rsync
3. Tạo restore script để restore trên VPS mới

### Yêu cầu:

- ✅ SSH key đã được add vào VPS mới
- ✅ Có thể SSH vào VPS mới: `ssh hieupc@62.72.45.174 -p 18961`
- ✅ VPS mới đã cài Docker

### Cách sử dụng:

#### Bước 1: Chạy script migration trên VPS hiện tại

```bash
cd /home/dev/docker/plane/plane-app
./migrate-to-new-server.sh
```

Script sẽ:
- Kiểm tra kết nối SSH
- Backup toàn bộ data
- Upload lên VPS mới tại: `/home/hieupc/docker/plane/backup`
- Tạo restore script

#### Bước 2: Restore trên VPS mới

SSH vào VPS mới:

```bash
ssh hieupc@62.72.45.174 -p 18961
```

Chạy restore script:

```bash
cd /home/hieupc/docker/plane/backup
chmod +x restore-on-new-server.sh
./restore-on-new-server.sh
```

Restore script sẽ:
1. Copy config files vào `/home/hieupc/docker/plane/plane-app`
2. Tạo tất cả Docker volumes
3. Restore data vào các volumes
4. Import PostgreSQL database
5. Start tất cả Plane services

#### Bước 3: Kiểm tra và verify

```bash
cd /home/hieupc/docker/plane/plane-app
docker compose ps
docker compose logs -f
```

#### Bước 4: Cấu hình DNS và Firewall

- Trỏ DNS về IP mới
- Mở port 80, 443 (hoặc custom ports trong plane.env)
- Kiểm tra SSL certificate nếu có

---

## 3. Cấu hình Migration Script

Nếu bạn muốn thay đổi cấu hình, edit file `migrate-to-new-server.sh`:

```bash
# Cấu hình
NEW_SERVER="hieupc@62.72.45.174"         # SSH user@host
SSH_PORT="18961"                          # SSH port
REMOTE_PATH="/home/hieupc/docker/plane/backup"  # Đường dẫn backup trên VPS mới
PLANE_APP_PATH="/home/hieupc/docker/plane/plane-app"  # Đường dẫn Plane app trên VPS mới
```

---

## 4. Troubleshooting

### Lỗi SSH connection

```bash
# Test kết nối SSH
ssh hieupc@62.72.45.174 -p 18961

# Nếu lỗi, check SSH key
ssh-copy-id -p 18961 hieupc@62.72.45.174
```

### Database backup thất bại

```bash
# Kiểm tra container database
docker ps | grep plane-db

# Start lại nếu cần
docker compose up -d plane-db

# Test connection
docker exec plane-app-plane-db-1 psql -U plane -d plane -c "SELECT version();"
```

### Upload thất bại

```bash
# Thử upload thủ công với rsync
rsync -avz --progress \
  -e "ssh -p 18961" \
  ./backup-for-migration/ \
  hieupc@62.72.45.174:/home/hieupc/docker/plane/backup/
```

### Restore database lỗi

```bash
# Check PostgreSQL logs
docker compose logs plane-db

# Drop và recreate database nếu cần
docker exec -it plane-app-plane-db-1 psql -U plane -c "DROP DATABASE plane;"
docker exec -it plane-app-plane-db-1 psql -U plane -c "CREATE DATABASE plane;"

# Import lại
docker exec -i plane-app-plane-db-1 psql -U plane plane < database.sql
```

---

## 5. Backup tự động (Cron job)

Để tự động backup định kỳ, thêm vào crontab:

```bash
# Edit crontab
crontab -e

# Thêm dòng này để backup mỗi ngày lúc 2AM
0 2 * * * cd /home/dev/docker/plane/plane-app && ./backup.sh >> /tmp/plane_backup.log 2>&1

# Cleanup backups cũ hơn 7 ngày
0 3 * * * find /home/dev/docker/plane/plane-app/backups -type d -name "plane_backup_*" -mtime +7 -exec rm -rf {} \;
```

---

## 6. Cấu trúc thư mục

### VPS hiện tại:
```
/home/dev/docker/plane/
├── plane-app/
│   ├── docker-compose.yaml
│   ├── plane.env
│   ├── backup.sh
│   ├── migrate-to-new-server.sh
│   ├── backups/              # Backups định kỳ
│   └── backup-for-migration/ # Backup cho migration
└── BACKUP_MIGRATION_GUIDE.md
```

### VPS mới (sau migration):
```
/home/hieupc/docker/plane/
├── plane-app/
│   ├── docker-compose.yaml
│   ├── plane.env
│   └── (các file khác sẽ được copy từ backup)
└── backup/                   # Backup từ VPS cũ
    ├── docker-compose.yaml
    ├── plane.env
    ├── database.sql
    ├── uploads.tar.gz
    ├── pgdata.tar.gz
    └── restore-on-new-server.sh
```

---

## 7. Lưu ý quan trọng

⚠️ **QUAN TRỌNG:**

1. **Trước khi migrate:**
   - Backup lần cuối trên VPS hiện tại
   - Stop containers để đảm bảo data consistency (nếu cần downtime)
   - Test SSH connection đến VPS mới

2. **Trong quá trình migrate:**
   - Kiểm tra dung lượng đĩa trên VPS mới
   - Monitor quá trình upload (có thể mất thời gian nếu data lớn)

3. **Sau khi migrate:**
   - Verify data integrity
   - Test tất cả chức năng
   - Cập nhật DNS
   - Giữ VPS cũ trong vài ngày để rollback nếu cần

4. **Security:**
   - Thay đổi các SECRET_KEY, passwords trong plane.env trên VPS mới
   - Cấu hình firewall đúng cách
   - Enable SSL với Let's Encrypt

---

## 8. Contacts & Support

Nếu có vấn đề, check:
- Plane documentation: https://docs.plane.so
- Docker logs: `docker compose logs -f`
- System logs: `journalctl -u docker -n 100`

---

**Last updated:** 2024-11-05
