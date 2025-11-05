# Hướng dẫn Migration trực tiếp Docker Volumes

## So sánh các phương pháp Migration

Có **4 phương pháp** để migrate Plane sang VPS mới:

| Phương pháp | Tốc độ | Disk Usage | Cần Sudo? | Phức tạp | Khuyến nghị |
|------------|--------|------------|-----------|----------|-------------|
| **1. migrate-direct-fast.sh** | ⚡⚡⚡ Nhanh nhất | ✅ Không tốn disk | ❌ Không | ⭐ Đơn giản | **🏆 Khuyên dùng** |
| **2. migrate-direct-no-sudo.sh** | ⚡⚡ Khá nhanh | ⚠️ Tốn disk temp | ❌ Không | ⭐⭐ Trung bình | Dự phòng |
| **3. migrate-direct-volumes.sh** | ⚡⚡⚡ Rất nhanh | ✅ Không tốn disk | ✅ Cần | ⭐ Đơn giản | Nếu có sudo |
| **4. migrate-to-new-server.sh** | ⚡ Chậm | ⚠️⚠️ Tốn nhiều disk | ❌ Không | ⭐⭐⭐ Phức tạp | Backup thường |

---

## ⭐ Phương pháp 1: Fast SSH Pipe (Khuyên dùng)

**File:** `migrate-direct-fast.sh`

### Ưu điểm:
- ✅ **Nhanh nhất** - Stream trực tiếp qua SSH
- ✅ **Không tốn disk** - Không cần temp files
- ✅ **Không cần sudo**
- ✅ **Đơn giản** - Chỉ cần 1 lệnh
- ✅ **An toàn** - Data integrity được đảm bảo

### Cách hoạt động:
```
VPS Cũ                    SSH Pipe                    VPS Mới
--------                  ---------                   --------
Volume → tar → gzip → ||| SSH Stream ||| → untar → Volume
```

### Sử dụng:

```bash
cd /home/dev/docker/plane/plane-app
./migrate-direct-fast.sh
```

### Volumes được copy:
- ✅ `plane-app_pgdata` - PostgreSQL database files
- ✅ `plane-app_uploads` - User uploads
- ✅ `plane-app_redisdata` - Redis data
- ✅ `plane-app_rabbitmq_data` - RabbitMQ data
- ✅ `plane-app_proxy_config` - Proxy config
- ✅ `plane-app_proxy_data` - Proxy data
- ⚪ `plane-app_logs_*` - Log files (optional)

### Thời gian ước tính:
- Database 100MB: ~30 giây
- Uploads 1GB: ~5 phút
- Tổng cộng: ~10-20 phút (tùy data size)

---

## Phương pháp 2: No Sudo Version

**File:** `migrate-direct-no-sudo.sh`

### Khi nào dùng:
- Không có quyền sudo trên cả 2 VPS
- Cần backup an toàn hơn (có temp files)

### Cách hoạt động:
```
VPS Cũ
--------
Volume → Temp folder → rsync → VPS Mới Temp → Volume
```

### Sử dụng:

```bash
cd /home/dev/docker/plane/plane-app
./migrate-direct-no-sudo.sh
```

### Lưu ý:
- ⚠️ Cần disk space cho temp: `/tmp/plane-volumes-sync`
- ⏱️ Chậm hơn phương pháp 1 do phải write/read disk

---

## Phương pháp 3: Direct Rsync (Cần Sudo)

**File:** `migrate-direct-volumes.sh`

### Khi nào dùng:
- Có quyền sudo trên cả 2 VPS
- Muốn rsync trực tiếp folders

### Cách hoạt động:
```
VPS Cũ                              VPS Mới
--------                            --------
/var/lib/docker/volumes/xxx/ → rsync → /var/lib/docker/volumes/xxx/
```

### Sử dụng:

```bash
cd /home/dev/docker/plane/plane-app
./migrate-direct-volumes.sh
```

### Ưu điểm:
- ⚡ Rất nhanh với rsync
- ✅ Hỗ trợ incremental sync (chỉ copy diff)
- ✅ Resume được nếu bị ngắt

---

## Phương pháp 4: Traditional Backup/Restore

**File:** `migrate-to-new-server.sh`

Xem chi tiết tại: [BACKUP_MIGRATION_GUIDE.md](./BACKUP_MIGRATION_GUIDE.md)

### Khi nào dùng:
- Backup định kỳ
- Cần lưu trữ backup files
- Migrate sau này (không migrate ngay)

---

## Chi tiết từng bước - Phương pháp 1 (Khuyên dùng)

### Bước 1: Chuẩn bị VPS mới

```bash
# SSH vào VPS mới
ssh hieupc@62.72.45.174 -p 18961

# Cài Docker nếu chưa có
curl -fsSL https://get.docker.com | sh

# Thêm user vào docker group
sudo usermod -aG docker $USER

# Logout và login lại để apply
exit
ssh hieupc@62.72.45.174 -p 18961
```

### Bước 2: Chạy migration trên VPS cũ

```bash
cd /home/dev/docker/plane/plane-app
./migrate-direct-fast.sh
```

**Quá trình sẽ:**
1. ✅ Kiểm tra SSH connection
2. ✅ Kiểm tra Docker trên VPS mới
3. ✅ Copy config files (docker-compose.yaml, plane.env)
4. ✅ Tạo volumes trên VPS mới
5. ✅ Stream copy từng volume qua SSH pipe

**Output mẫu:**
```
============================================
   FAST DIRECT VOLUME MIGRATION
============================================
🚀 Phương pháp: SSH pipe stream
🎯 Target: hieupc@62.72.45.174:18961
📦 Volumes: 6 volumes chính
⏰ Time: Tue Nov  5 10:30:00 UTC 2024

🔍 [1/5] Kiểm tra kết nối SSH...
   ✅ Kết nối SSH thành công!

🐳 [2/5] Kiểm tra Docker...
   ✅ Docker OK

📋 [3/5] Copy config files...
   ✅ Đã copy config files

💾 [4/5] Tạo volumes trên VPS mới...
   ✅ Đã tạo volumes

🚀 [5/5] Copy volumes data (stream trực tiếp)...

📦 Copy volume: plane-app_pgdata
   📊 Kích thước: 125M
   ⏳ Đang copy...
   ✅ Đã copy plane-app_pgdata

📦 Copy volume: plane-app_uploads
   📊 Kích thước: 2.3G
   ⏳ Đang copy...
   ✅ Đã copy plane-app_uploads

...
```

### Bước 3: Verify trên VPS mới

```bash
# SSH vào VPS mới
ssh hieupc@62.72.45.174 -p 18961

# Kiểm tra volumes
docker volume ls | grep plane-app

# Kiểm tra data size
docker run --rm -v plane-app_pgdata:/data alpine du -sh /data
docker run --rm -v plane-app_uploads:/data alpine du -sh /data

# Expected output:
# 125M    /data   (pgdata)
# 2.3G    /data   (uploads)
```

### Bước 4: Start Plane trên VPS mới

```bash
# Vào thư mục plane-app
cd /home/hieupc/docker/plane/plane-app

# Start services
docker compose up -d

# Chờ các services khởi động (1-2 phút)
sleep 60

# Kiểm tra status
docker compose ps

# Expected: Tất cả containers đều "Up"
```

### Bước 5: Verify application

```bash
# Xem logs
docker compose logs -f

# Test database connection
docker compose exec api python manage.py check

# Test web interface
curl -I http://localhost:8080
```

### Bước 6: Cấu hình DNS & Firewall

```bash
# Mở ports
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 8080/tcp
sudo ufw allow 8443/tcp

# Hoặc nếu dùng iptables
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
```

Sau đó:
1. Trỏ DNS về IP mới
2. Chờ DNS propagate (~5-30 phút)
3. Test: `https://plane.openlearnhub.io.vn`

---

## Troubleshooting

### ❌ Lỗi: "Cannot connect to Docker daemon"

```bash
# Trên VPS mới, thêm user vào docker group
sudo usermod -aG docker $USER

# Logout và login lại
exit
ssh hieupc@62.72.45.174 -p 18961
```

### ❌ Lỗi: SSH connection timeout

```bash
# Test SSH connection
ssh -p 18961 hieupc@62.72.45.174 -v

# Check SSH key
ssh-add -l

# Re-add SSH key nếu cần
ssh-copy-id -p 18961 hieupc@62.72.45.174
```

### ❌ Volume copy bị lỗi giữa chừng

```bash
# Chạy lại script - nó sẽ overwrite
./migrate-direct-fast.sh

# Hoặc xóa volume và copy lại
ssh -p 18961 hieupc@62.72.45.174 "docker volume rm plane-app_pgdata"
# Rồi chạy lại script
```

### ❌ Database không start được

```bash
# Check logs
docker compose logs plane-db

# Nếu lỗi permissions, fix:
docker compose down
docker volume rm plane-app_pgdata
# Rồi copy lại volume pgdata
```

### ⚠️ Data size khác nhau trước/sau

```bash
# Kiểm tra trên VPS cũ
docker run --rm -v plane-app_pgdata:/data alpine du -sh /data

# Kiểm tra trên VPS mới
ssh -p 18961 hieupc@62.72.45.174 \
  "docker run --rm -v plane-app_pgdata:/data alpine du -sh /data"

# Nếu khác nhiều, copy lại volume đó
```

---

## Performance Tips

### 1. Stop containers trước khi copy (optional)

Để đảm bảo data consistency:

```bash
# Trên VPS cũ
cd /home/dev/docker/plane/plane-app
docker compose down

# Copy volumes
./migrate-direct-fast.sh

# Start lại nếu cần
docker compose up -d
```

### 2. Compress better

Nếu mạng chậm, edit script để tăng compression:

```bash
# Trong migrate-direct-fast.sh, thay:
tar czf - -C /data .

# Bằng:
tar cf - -C /data . | gzip -9
```

### 3. Parallel copy

Copy nhiều volumes cùng lúc (advanced):

```bash
# Copy pgdata
./migrate-direct-fast.sh &

# Copy uploads song song
# (cần modify script để accept volume name param)
```

---

## Rollback Plan

Nếu có vấn đề trên VPS mới:

### Plan A: Rollback DNS
1. Trỏ DNS về VPS cũ
2. VPS cũ vẫn hoạt động bình thường

### Plan B: Copy ngược lại
1. Giữ nguyên VPS cũ
2. Fix issue trên VPS mới
3. Copy lại nếu cần

### Plan C: Restore từ backup
1. Dùng script `migrate-to-new-server.sh` để backup
2. Restore từ backup files

---

## Checklist Migration

- [ ] Backup VPS cũ
- [ ] Test SSH connection đến VPS mới
- [ ] Cài Docker trên VPS mới
- [ ] Chạy migration script
- [ ] Verify volumes trên VPS mới
- [ ] Start Plane services
- [ ] Test application
- [ ] Cấu hình firewall
- [ ] Update DNS
- [ ] Monitor logs 24h
- [ ] Backup VPS mới
- [ ] (Optional) Shutdown VPS cũ sau 1 tuần

---

## Best Practices

1. **Luôn backup trước khi migrate**
   ```bash
   ./backup.sh
   ```

2. **Test migration trên volume nhỏ trước**
   ```bash
   # Test với log volume trước
   # Rồi mới copy volumes chính
   ```

3. **Monitor disk space**
   ```bash
   # VPS mới
   df -h
   docker system df
   ```

4. **Verify checksum (paranoid mode)**
   ```bash
   # VPS cũ
   docker run --rm -v plane-app_pgdata:/data alpine \
     sh -c "find /data -type f -exec md5sum {} \;" > checksums-old.txt

   # VPS mới
   ssh hieupc@62.72.45.174 -p 18961 \
     "docker run --rm -v plane-app_pgdata:/data alpine \
       sh -c 'find /data -type f -exec md5sum {} \;'" > checksums-new.txt

   # Compare
   diff checksums-old.txt checksums-new.txt
   ```

---

**Last updated:** 2024-11-05
**Recommended method:** `migrate-direct-fast.sh`
