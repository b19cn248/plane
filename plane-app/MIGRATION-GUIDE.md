# 🚀 Hướng dẫn Migration Plane sang VPS mới

## ✅ Yêu cầu trước khi chạy:

1. ✔️ SSH key đã được add vào VPS mới
2. ✔️ Test kết nối SSH: `ssh hieupc@62.72.45.174 -p 18961`
3. ✔️ VPS mới đã cài Docker (nếu chưa, script restore sẽ hướng dẫn)

---

## 🎯 CÁCH SỬ DỤNG:

### Bước 1: Chạy script migration (trên VPS cũ)

```bash
cd /home/dev/docker/plane/plane-app
./migrate-to-new-server.sh
```

**Script sẽ tự động:**
- ✅ Kiểm tra kết nối SSH
- ✅ Backup toàn bộ data (database, uploads, configs)
- ✅ Upload lên VPS mới tự động
- ✅ Tạo restore script cho VPS mới

**Thời gian:** Khoảng 5-30 phút tùy dung lượng data

---

### Bước 2: Restore trên VPS mới

```bash
# SSH vào VPS mới
ssh hieupc@62.72.45.174 -p 18961

# Vào thư mục backup
cd /home/hieupc/plane-backup

# Chạy restore script
chmod +x restore-on-new-server.sh
./restore-on-new-server.sh
```

**Script restore sẽ:**
- ✅ Kiểm tra Docker (hướng dẫn cài nếu chưa có)
- ✅ Tạo volumes
- ✅ Restore toàn bộ data
- ✅ Start Plane services

---

### Bước 3: Kiểm tra

```bash
# Xem trạng thái containers
docker compose ps

# Xem logs
docker compose logs -f

# Kiểm tra web
# Truy cập: http://IP-VPS-MỚI
```

---

## 📊 Những gì được backup:

- ✅ `docker-compose.yaml` - Cấu hình Docker
- ✅ `plane.env` - Biến môi trường
- ✅ `database.sql` - PostgreSQL database dump
- ✅ `pgdata.tar.gz` - PostgreSQL data files
- ✅ `uploads.tar.gz` - Files upload của users
- ✅ `rabbitmq_data.tar.gz` - RabbitMQ queues
- ✅ `redisdata.tar.gz` - Redis cache
- ✅ `proxy_config.tar.gz` - Nginx config
- ✅ `proxy_data.tar.gz` - SSL certificates

---

## 🔧 Troubleshooting

### Lỗi: "Connection refused"
```bash
# Kiểm tra SSH
ssh hieupc@62.72.45.174 -p 18961

# Nếu không kết nối được, check SSH key
ssh-add -l
```

### Lỗi: "rsync command not found"
```bash
# Cài rsync (trên VPS cũ)
sudo apt update && sudo apt install rsync -y
```

### Docker chưa có trên VPS mới
```bash
# Cài Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# Logout và login lại
```

### Port 80/443 đã được dùng
```bash
# Check process dùng port
sudo netstat -tlnp | grep -E ':(80|443)'

# Hoặc sửa port trong plane.env
LISTEN_HTTP_PORT=8080
LISTEN_HTTPS_PORT=8443
```

---

## 💡 Tips

**Nếu muốn test trước:**
- Chỉ backup không upload: Comment dòng rsync trong script
- Backup thủ công: Copy folder `backup-for-migration/`

**Tối ưu tốc độ upload:**
- Nén trước khi upload: `tar czf backup.tar.gz backup-for-migration/`
- Dùng screen: `screen -S migration` rồi chạy script

**Sau khi migrate thành công:**
- Xóa backup local: `rm -rf backup-for-migration/`
- Xóa backup trên VPS mới: `rm -rf /home/hieupc/plane-backup/`

---

## 📞 Support

Nếu gặp vấn đề:
1. Check logs: `docker compose logs -f`
2. Check containers: `docker compose ps`
3. Restart services: `docker compose restart`
4. Rebuild: `docker compose down && docker compose up -d`

---

**Created:** $(date)
**Script version:** 1.0
