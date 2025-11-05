# 🚀 Plane Migration Scripts

Bộ scripts tự động để backup và migrate Plane từ VPS cũ sang VPS mới.

## 📦 Tổng quan các scripts

```
plane-app/
├── test-migration.sh              # ⭐ CHẠY ĐẦU TIÊN - Kiểm tra trước khi migrate
├── migrate-direct-fast.sh         # 🏆 KHUYÊN DÙNG - Migration nhanh nhất
├── migrate-direct-no-sudo.sh      # ⚡ Không cần sudo
├── migrate-direct-volumes.sh      # 💪 Dùng rsync trực tiếp (cần sudo)
├── migrate-to-new-server.sh       # 📦 Traditional backup/restore
└── backup.sh                      # 💾 Backup định kỳ
```

## 🎯 Quick Start

### Bước 1: Test trước khi migrate

```bash
cd /home/dev/docker/plane/plane-app
./test-migration.sh
```

Script này sẽ kiểm tra:
- ✅ SSH connection
- ✅ Docker trên VPS mới
- ✅ Disk space
- ✅ Network speed
- ✅ Volumes size
- ✅ Containers status

### Bước 2: Chọn phương pháp migration

#### 🏆 Phương pháp A: Fast SSH Pipe (Khuyên dùng)

**Nhanh nhất - Stream trực tiếp qua SSH**

```bash
./migrate-direct-fast.sh
```

**Ưu điểm:**
- ⚡⚡⚡ Nhanh nhất
- ✅ Không tốn disk cho temp files
- ✅ Không cần sudo
- ✅ Đơn giản nhất

**Thời gian:** ~10-20 phút (tùy data size)

---

#### ⚡ Phương pháp B: No Sudo Version

**Khi không có sudo**

```bash
./migrate-direct-no-sudo.sh
```

**Khi nào dùng:**
- Không có quyền sudo
- Cần backup an toàn (có temp files)

---

#### 💪 Phương pháp C: Direct Rsync

**Cần sudo, rất nhanh**

```bash
./migrate-direct-volumes.sh
```

**Khi nào dùng:**
- Có sudo trên cả 2 VPS
- Muốn dùng rsync trực tiếp

---

#### 📦 Phương pháp D: Traditional

**Backup và restore riêng biệt**

```bash
./migrate-to-new-server.sh
```

**Khi nào dùng:**
- Backup định kỳ
- Cần lưu backup files
- Migrate sau

---

## 📖 Chi tiết từng bước

### Migration đầy đủ với phương pháp Fast (Khuyên dùng)

```bash
# 1. Vào thư mục plane-app
cd /home/dev/docker/plane/plane-app

# 2. (Optional) Backup trước khi migrate
./backup.sh

# 3. (Optional) Stop containers để đảm bảo data consistency
docker compose down

# 4. Test migration
./test-migration.sh

# 5. Chạy migration
./migrate-direct-fast.sh

# Script sẽ:
# - ✅ Copy config files
# - ✅ Tạo volumes trên VPS mới
# - ✅ Stream copy từng volume
# - ✅ Verify data
```

### Sau khi migration - Trên VPS mới

```bash
# SSH vào VPS mới
ssh hieupc@62.72.45.174 -p 18961

# Verify volumes
docker volume ls | grep plane-app

# Check data size
docker run --rm -v plane-app_pgdata:/data alpine du -sh /data
docker run --rm -v plane-app_uploads:/data alpine du -sh /data

# Vào thư mục plane-app
cd /home/hieupc/docker/plane/plane-app

# Start services
docker compose up -d

# Chờ khởi động (1-2 phút)
sleep 60

# Check status
docker compose ps

# Monitor logs
docker compose logs -f
```

### Cấu hình DNS & Firewall

```bash
# Mở firewall ports
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 8080/tcp
sudo ufw allow 8443/tcp

# Hoặc với iptables
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
```

Sau đó:
1. Trỏ DNS về IP VPS mới
2. Chờ DNS propagate (~5-30 phút)
3. Test: https://plane.openlearnhub.io.vn

---

## 📚 Tài liệu chi tiết

### Hướng dẫn migration trực tiếp
👉 **[DIRECT_MIGRATION_GUIDE.md](./DIRECT_MIGRATION_GUIDE.md)**

Bao gồm:
- So sánh 4 phương pháp migration
- Chi tiết từng bước
- Troubleshooting
- Performance tips
- Rollback plan
- Best practices

### Hướng dẫn backup/restore traditional
👉 **[BACKUP_MIGRATION_GUIDE.md](./BACKUP_MIGRATION_GUIDE.md)**

Bao gồm:
- Backup định kỳ
- Restore từ backup
- Cron job tự động
- Troubleshooting

---

## 🔧 Cấu hình

### Thông tin VPS mới

Mặc định trong các scripts:

```bash
NEW_SERVER="hieupc@62.72.45.174"
SSH_PORT="18961"
PLANE_APP_PATH="/home/hieupc/docker/plane/plane-app"
```

Để thay đổi, edit file script tương ứng.

### Volumes được migrate

Tất cả scripts đều migrate các volumes sau:

```bash
# Volumes quan trọng (luôn được copy)
plane-app_pgdata           # PostgreSQL database files
plane-app_uploads          # User uploads
plane-app_redisdata        # Redis data
plane-app_rabbitmq_data    # RabbitMQ data
plane-app_proxy_config     # Proxy config
plane-app_proxy_data       # Proxy data

# Log volumes (optional trong fast version)
plane-app_logs_api
plane-app_logs_worker
plane-app_logs_beat-worker
plane-app_logs_migrator
```

---

## ⚠️ Lưu ý quan trọng

### Trước khi migrate

1. **Backup VPS cũ**
   ```bash
   ./backup.sh
   ```

2. **Test SSH connection**
   ```bash
   ssh hieupc@62.72.45.174 -p 18961
   ```

3. **Kiểm tra disk space trên VPS mới**
   ```bash
   ssh -p 18961 hieupc@62.72.45.174 "df -h"
   ```

4. **(Optional) Stop containers**
   ```bash
   docker compose down
   ```

### Trong quá trình migrate

- ⏱️ Có thể mất 10-30 phút tùy data size
- 📊 Monitor progress trong terminal
- ⚠️ KHÔNG tắt terminal giữa chừng
- 💾 Đảm bảo disk space đủ

### Sau khi migrate

1. **Verify data integrity**
2. **Test tất cả chức năng**
3. **Monitor logs 24h**
4. **Backup VPS mới**
5. **Giữ VPS cũ ít nhất 1 tuần để rollback nếu cần**

---

## 🐛 Troubleshooting

### Lỗi thường gặp

#### ❌ Cannot connect to Docker daemon

```bash
# Trên VPS mới
sudo usermod -aG docker $USER
# Logout và login lại
```

#### ❌ SSH connection timeout

```bash
# Test SSH
ssh -p 18961 hieupc@62.72.45.174 -v

# Re-add SSH key
ssh-copy-id -p 18961 hieupc@62.72.45.174
```

#### ❌ Volume copy failed

```bash
# Xóa volume và copy lại
ssh -p 18961 hieupc@62.72.45.174 "docker volume rm plane-app_pgdata"
./migrate-direct-fast.sh
```

#### ❌ Database không start

```bash
# Check logs
docker compose logs plane-db

# Reset và copy lại
docker compose down
docker volume rm plane-app_pgdata
# Copy lại volume
```

### Xem thêm

Chi tiết troubleshooting: **[DIRECT_MIGRATION_GUIDE.md](./DIRECT_MIGRATION_GUIDE.md#troubleshooting)**

---

## 📊 So sánh phương pháp

| Phương pháp | Script | Tốc độ | Disk | Sudo | Khuyến nghị |
|------------|--------|--------|------|------|-------------|
| Fast SSH Pipe | migrate-direct-fast.sh | ⚡⚡⚡ | ✅ | ❌ | 🏆 Khuyên dùng |
| No Sudo | migrate-direct-no-sudo.sh | ⚡⚡ | ⚠️ | ❌ | Backup |
| Direct Rsync | migrate-direct-volumes.sh | ⚡⚡⚡ | ✅ | ✅ | Nếu có sudo |
| Traditional | migrate-to-new-server.sh | ⚡ | ⚠️⚠️ | ❌ | Backup thường |

---

## 📞 Support

Nếu gặp vấn đề:

1. Đọc troubleshooting trong guides
2. Check logs: `docker compose logs -f`
3. Verify volumes: `docker volume ls`
4. Test containers: `docker compose ps`

---

## 📝 Checklist Migration

Copy checklist này và tick khi hoàn thành:

```
VPS Cũ (hiện tại):
[ ] Backup hiện tại: ./backup.sh
[ ] Test migration: ./test-migration.sh
[ ] (Optional) Stop containers: docker compose down
[ ] Chạy migration: ./migrate-direct-fast.sh
[ ] Verify migration thành công

VPS Mới:
[ ] SSH vào VPS mới
[ ] Verify volumes: docker volume ls | grep plane-app
[ ] Check data size: docker run --rm -v plane-app_pgdata:/data alpine du -sh /data
[ ] Start services: docker compose up -d
[ ] Check status: docker compose ps
[ ] Monitor logs: docker compose logs -f
[ ] Test application
[ ] Mở firewall ports: 80, 443
[ ] Update DNS
[ ] Monitor 24h
[ ] Backup VPS mới

Cleanup (sau 1 tuần):
[ ] Verify VPS mới hoạt động ổn định
[ ] Xóa backup cũ nếu không cần
[ ] (Optional) Shutdown VPS cũ
```

---

## 🎓 Best Practices

1. **Luôn backup trước khi migrate**
2. **Test với data nhỏ trước**
3. **Stop containers để đảm bảo consistency**
4. **Verify checksum sau khi copy**
5. **Monitor logs sau migration**
6. **Giữ VPS cũ để rollback nếu cần**
7. **Backup VPS mới ngay sau migrate**

---

**Version:** 1.0
**Last updated:** 2024-11-05
**Recommended:** `migrate-direct-fast.sh`

---

## 📁 Cấu trúc files

```
/home/dev/docker/plane/
├── README_MIGRATION.md                    # ⭐ File này
├── DIRECT_MIGRATION_GUIDE.md             # Chi tiết migration trực tiếp
├── BACKUP_MIGRATION_GUIDE.md             # Chi tiết backup/restore
└── plane-app/
    ├── docker-compose.yaml
    ├── plane.env
    ├── test-migration.sh                 # Test trước khi migrate
    ├── migrate-direct-fast.sh            # 🏆 Migration nhanh nhất
    ├── migrate-direct-no-sudo.sh         # Migration không sudo
    ├── migrate-direct-volumes.sh         # Migration với rsync
    ├── migrate-to-new-server.sh          # Traditional migration
    ├── backup.sh                         # Backup định kỳ
    ├── backups/                          # Backup files
    └── backup-for-migration/             # Backup cho migration
```

---

Chúc bạn migration thành công! 🎉
