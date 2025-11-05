#!/bin/bash

# Script test migration - Kiểm tra mọi thứ trước khi migrate thật

set -e

NEW_SERVER="hieupc@62.72.45.174"
SSH_PORT="18961"

echo "============================================"
echo "   MIGRATION PRE-CHECK"
echo "============================================"
echo ""

# Test 1: SSH Connection
echo "✅ Test 1: SSH Connection"
if ssh -p ${SSH_PORT} -o ConnectTimeout=5 ${NEW_SERVER} "echo 'SSH OK'" > /dev/null 2>&1; then
    echo "   ✅ PASS - SSH connection works"
else
    echo "   ❌ FAIL - Cannot connect via SSH"
    echo "   Fix: ssh-copy-id -p ${SSH_PORT} ${NEW_SERVER}"
    exit 1
fi
echo ""

# Test 2: Docker on VPS mới
echo "✅ Test 2: Docker on New VPS"
DOCKER_VERSION=$(ssh -p ${SSH_PORT} ${NEW_SERVER} "docker --version" 2>/dev/null || echo "NOT_INSTALLED")
if [ "$DOCKER_VERSION" != "NOT_INSTALLED" ]; then
    echo "   ✅ PASS - Docker installed: ${DOCKER_VERSION}"
else
    echo "   ❌ FAIL - Docker not installed"
    echo "   Fix: ssh ${NEW_SERVER} -p ${SSH_PORT} 'curl -fsSL https://get.docker.com | sh'"
    exit 1
fi
echo ""

# Test 3: Docker permissions
echo "✅ Test 3: Docker Permissions"
if ssh -p ${SSH_PORT} ${NEW_SERVER} "docker ps" > /dev/null 2>&1; then
    echo "   ✅ PASS - User can run docker without sudo"
else
    echo "   ⚠️  WARNING - Need sudo for docker"
    echo "   Fix: ssh ${NEW_SERVER} -p ${SSH_PORT} 'sudo usermod -aG docker \$USER && exit'"
    echo "   Then logout and login again"
fi
echo ""

# Test 4: Disk space on VPS mới
echo "✅ Test 4: Disk Space on New VPS"
DISK_AVAIL=$(ssh -p ${SSH_PORT} ${NEW_SERVER} "df -h / | tail -1 | awk '{print \$4}'" 2>/dev/null || echo "unknown")
echo "   📊 Available space: ${DISK_AVAIL}"

# Calculate total volume size
TOTAL_SIZE=0
echo "   📦 Calculating volumes size..."
for volume in plane-app_pgdata plane-app_uploads plane-app_redisdata plane-app_rabbitmq_data plane-app_proxy_config plane-app_proxy_data; do
    SIZE=$(docker run --rm -v ${volume}:/data alpine du -sm /data 2>/dev/null | awk '{print $1}' || echo "0")
    TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
done
echo "   📊 Total volumes size: ~${TOTAL_SIZE}MB (~$((TOTAL_SIZE/1024))GB)"
echo ""

# Test 5: Network speed
echo "✅ Test 5: Network Speed Test"
echo "   ⏳ Testing upload speed (10MB test file)..."
dd if=/dev/zero bs=1M count=10 2>/dev/null | \
    time ssh -p ${SSH_PORT} ${NEW_SERVER} "cat > /tmp/speedtest.bin" 2>&1 | \
    grep real || echo "Speed test failed"
ssh -p ${SSH_PORT} ${NEW_SERVER} "rm -f /tmp/speedtest.bin"
echo ""

# Test 6: Check volumes trên VPS cũ
echo "✅ Test 6: Volumes on Current VPS"
VOLUMES_COUNT=$(docker volume ls | grep -c "plane-app_" || echo "0")
echo "   📦 Found ${VOLUMES_COUNT} volumes"
docker volume ls | grep "plane-app_"
echo ""

# Test 7: Check containers running
echo "✅ Test 7: Running Containers"
RUNNING=$(docker compose ps --services --filter "status=running" 2>/dev/null | wc -l)
TOTAL=$(docker compose ps --services 2>/dev/null | wc -l)
echo "   🐳 Running: ${RUNNING}/${TOTAL} containers"
if [ ${RUNNING} -eq ${TOTAL} ]; then
    echo "   ✅ All containers are running"
    echo "   💡 Khuyến nghị: Stop containers trước khi migrate để đảm bảo data consistency"
    echo "      Command: docker compose down"
else
    echo "   ⚠️  Some containers are not running"
fi
echo ""

# Summary
echo "============================================"
echo "   SUMMARY"
echo "============================================"
echo ""
echo "📊 Migration estimates:"
echo "   - Data size: ~${TOTAL_SIZE}MB (~$((TOTAL_SIZE/1024))GB)"
echo "   - Time estimate: ~$((TOTAL_SIZE/100)) minutes (assuming 100MB/min)"
echo "   - Disk needed on VPS mới: ~$((TOTAL_SIZE*2/1024))GB (with buffer)"
echo ""
echo "🎯 Recommended method:"
echo "   ./migrate-direct-fast.sh"
echo ""
echo "⚠️  Before migration:"
echo "   1. Backup current VPS:"
echo "      ./backup.sh"
echo ""
echo "   2. Stop containers (optional, for data consistency):"
echo "      docker compose down"
echo ""
echo "   3. Run migration:"
echo "      ./migrate-direct-fast.sh"
echo ""
echo "   4. Verify on new VPS and start services"
echo ""

# Check if ready
echo "❓ Ready to migrate? (y/N)"
read -p "Run migration now? " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "🚀 Starting migration..."
    echo ""
    exec ./migrate-direct-fast.sh
else
    echo ""
    echo "👍 Đã cancel. Chạy lại khi sẵn sàng:"
    echo "   ./test-migration.sh"
    echo ""
fi
