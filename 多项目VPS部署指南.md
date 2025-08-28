# 多项目VPS环境下部署Restreamer指南

> 本指南专门针对已有多个项目运行的VPS环境，解决端口冲突问题并提供安全的部署方案。

## 一、部署前准备

### 1.1 检查当前端口使用情况

```bash
# 检查所有监听端口
sudo netstat -tlnp | grep LISTEN

# 或使用ss命令（推荐）
sudo ss -tlnp | grep LISTEN

# 检查特定端口是否被占用
sudo lsof -i :8080
sudo lsof -i :8181
sudo lsof -i :1935
sudo lsof -i :1936
sudo lsof -i :6000
```

### 1.2 选择可用端口

根据检查结果，为Restreamer选择未被占用的端口：

```bash
# 建议的端口映射（根据实际情况调整）
# Web UI HTTP: 8080 → 18080
# Web UI HTTPS: 8181 → 18181  
# RTMP: 1935 → 11935
# RTMPS: 1936 → 11936
# SRT: 6000 → 16000
```

## 二、创建部署目录和配置

```bash
# 创建项目目录
sudo mkdir -p /opt/restreamer/{config,data,videos}
sudo chown -R $USER:$USER /opt/restreamer

# 创建docker-compose配置目录
cd /opt/restreamer
```

## 三、Docker Compose部署（推荐）

创建 `docker-compose.yml` 文件：

```yaml
version: "3.8"
services:
  restreamer:
    image: datarhei/restreamer:latest
    container_name: restreamer
    restart: unless-stopped
    ports:
      # 调整为未被占用的端口
      - "18080:8080"   # Web UI HTTP
      - "18181:8181"   # Web UI HTTPS
      - "11935:1935"   # RTMP (可选)
      - "11936:1936"   # RTMPS (可选)
      - "16000:6000/udp" # SRT (可选)
    environment:
      - CORE_RTMP_ENABLE=true
      - CORE_RTMP_ENABLE_TLS=true
      - CORE_RTMP_TOKEN=your_secure_random_token_here
      # 可选：设置时区
      - TZ=Asia/Shanghai
    volumes:
      - ./config:/core/config
      - ./data:/core/data
      - ./videos:/videos  # 视频文件存储目录
    networks:
      - restreamer_net

networks:
  restreamer_net:
    driver: bridge
```

## 四、启动服务

```bash
# 启动服务
docker-compose up -d

# 查看日志
docker-compose logs -f

# 检查服务状态
docker-compose ps
```

## 五、Nginx反向代理配置（推荐）

如果你的VPS已经有Nginx，可以通过反向代理避免端口冲突：

### 5.1 创建Nginx配置文件

```bash
sudo nano /etc/nginx/sites-available/restreamer
```

```nginx
server {
    listen 80;
    server_name restreamer.yourdomain.com;  # 替换为你的域名
    
    # 重定向到HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name restreamer.yourdomain.com;  # 替换为你的域名
    
    # SSL证书配置（使用Let's Encrypt或其他证书）
    ssl_certificate /path/to/your/cert.pem;
    ssl_certificate_key /path/to/your/key.pem;
    
    # 安全头
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    
    location / {
        proxy_pass http://localhost:18080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket支持
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

### 5.2 启用配置

```bash
# 启用站点
sudo ln -s /etc/nginx/sites-available/restreamer /etc/nginx/sites-enabled/

# 测试配置
sudo nginx -t

# 重载Nginx
sudo systemctl reload nginx
```

## 六、防火墙配置

```bash
# 如果使用ufw
sudo ufw allow 18080/tcp  # Web UI HTTP
sudo ufw allow 18181/tcp  # Web UI HTTPS
sudo ufw allow 11935/tcp  # RTMP (如需外部推流)
sudo ufw allow 11936/tcp  # RTMPS (如需外部推流)
sudo ufw allow 16000/udp  # SRT (如需外部推流)

# 如果使用反向代理，只需开放80和443
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

## 七、首次配置

1. 访问Web界面：
   - 直接访问：`http://your-vps-ip:18080`
   - 通过反向代理：`https://restreamer.yourdomain.com`

2. 按照向导完成初始配置

3. 上传视频文件到 `/opt/restreamer/videos` 目录

## 八、视频文件管理

### 8.1 上传大文件的技巧

```bash
# 方法1：直接复制到挂载目录
cp your-video.mp4 /opt/restreamer/data/

# 方法2：使用.source文件替换技巧
# 在UI中创建Loop源后，将大文件重命名为.source文件
mv your-large-video.mp4 /opt/restreamer/data/your-stream.source
```

### 8.2 视频预处理（可选）

```bash
# 转换为Mux推荐格式
ffmpeg -i input.mp4 -vf "scale=-2:1080" -r 30 \
  -c:v libx264 -profile:v main -preset veryfast -b:v 5000k -maxrate 5500k -bufsize 10000k \
  -g 60 -keyint_min 60 -sc_threshold 0 \
  -c:a aac -b:a 128k -ar 48000 -ac 2 output_1080p30.mp4
```

## 九、监控和维护

### 9.1 日志监控

```bash
# 查看容器日志
docker-compose logs -f restreamer

# 查看系统资源使用
docker stats restreamer
```

### 9.2 备份配置

```bash
# 备份配置和数据
tar -czf restreamer-backup-$(date +%Y%m%d).tar.gz /opt/restreamer/config /opt/restreamer/data
```

## 十、故障排除

### 10.1 端口冲突

```bash
# 如果启动失败，检查端口冲突
docker-compose logs restreamer

# 修改docker-compose.yml中的端口映射
# 重新启动
docker-compose down && docker-compose up -d
```

### 10.2 性能优化

```bash
# 限制容器资源使用
# 在docker-compose.yml中添加：
deploy:
  resources:
    limits:
      memory: 2G
      cpus: '1.0'
```

## 十一、安全建议

1. **更改默认端口**：避免使用标准端口
2. **设置强密码**：为RTMP Token设置复杂密码
3. **使用HTTPS**：通过反向代理启用SSL
4. **限制访问**：只开放必要的端口
5. **定期更新**：保持Docker镜像最新

## 十二、常用命令

```bash
# 重启服务
docker-compose restart

# 更新镜像
docker-compose pull && docker-compose up -d

# 查看容器状态
docker-compose ps

# 进入容器
docker-compose exec restreamer bash

# 停止服务
docker-compose down

# 完全清理（谨慎使用）
docker-compose down -v
```

---

这个配置方案可以让你在不影响现有项目的情况下成功部署Restreamer。记得根据你的实际端口使用情况调整配置文件中的端口映射。
