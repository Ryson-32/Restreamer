# Restreamer VPS 部署工具包

这是一个专为多项目VPS环境设计的Restreamer部署工具包，可以自动检测端口冲突并选择可用端口进行部署。

## 🚀 快速开始

### 1. 上传文件到VPS

将以下文件上传到你的VPS：
- `deploy.sh` - 自动部署脚本
- `manage.sh` - 服务管理脚本
- `多项目VPS部署指南.md` - 详细部署指南

```bash
# 赋予执行权限
chmod +x deploy.sh manage.sh
```

### 2. 一键部署

```bash
# 运行部署脚本
./deploy.sh
```

脚本会自动：
- ✅ 检查Docker环境
- ✅ 扫描端口使用情况
- ✅ 自动选择可用端口
- ✅ 创建Docker Compose配置
- ✅ 启动Restreamer服务
- ✅ 生成安全的RTMP Token

### 3. 访问Web界面

部署完成后，脚本会显示访问地址：
```
访问信息：
  Web界面: http://你的VPS-IP:端口号
  本地访问: http://localhost:端口号
```

## 🛠️ 服务管理

使用管理脚本进行日常维护：

```bash
# 交互式管理界面
./manage.sh

# 或直接使用命令
./manage.sh status    # 查看状态
./manage.sh logs      # 查看日志
./manage.sh restart   # 重启服务
./manage.sh backup    # 备份数据
```

## 📁 目录结构

```
/opt/restreamer/
├── docker-compose.yml  # Docker配置文件
├── .env                # 环境变量
├── config/             # Restreamer配置
├── data/               # 数据目录
└── videos/             # 视频文件目录
```

## 🎥 视频文件管理

### 上传视频文件

```bash
# 方法1：直接复制到videos目录
cp your-video.mp4 /opt/restreamer/videos/

# 方法2：使用.source文件技巧（适用于大文件）
# 在Web界面创建Loop源后，替换生成的文件
mv your-large-video.mp4 /opt/restreamer/data/your-stream.source
```

### 视频格式建议

为了最佳兼容性，建议使用：
- **视频编码**: H.264 (Main Profile)
- **音频编码**: AAC
- **分辨率**: 1080p
- **帧率**: 30fps
- **码率**: 5000kbps

## 🔧 常见问题

### Q: 端口被占用怎么办？
A: 部署脚本会自动检测并选择可用端口，无需手动处理。

### Q: 如何上传大视频文件？
A: 使用`.source`文件替换技巧，详见部署指南。

### Q: 如何推流到Mux？
A: 在Web界面的Publication services中配置：
- Server URL: `rtmps://global-live.mux.com:443/app`
- Stream Key: 你的Mux Stream Key

### Q: 服务异常怎么排查？
A: 使用 `./manage.sh logs` 查看详细日志。

## 🔒 安全建议

1. **更改默认端口**: 脚本会自动选择非标准端口
2. **使用HTTPS**: 建议配置Nginx反向代理
3. **防火墙配置**: 只开放必要端口
4. **定期备份**: 使用 `./manage.sh backup` 备份配置

## 📖 详细文档

- [多项目VPS部署指南.md](./多项目VPS部署指南.md) - 完整部署文档
- [VPS 部署 Restreamer.md](./VPS%20部署%20Restreamer.md) - 原始部署文档

## 🆘 获取帮助

如果遇到问题：

1. 查看日志: `./manage.sh logs`
2. 检查状态: `./manage.sh status`
3. 重启服务: `./manage.sh restart`
4. 查看详细文档: `多项目VPS部署指南.md`

## 📋 系统要求

- Ubuntu 22.04 LTS (推荐)
- Docker 20.10+
- 至少2GB内存
- 至少10GB可用磁盘空间

---

**注意**: 这个工具包专为多项目VPS环境设计，会自动避免端口冲突，确保与现有服务和谐共存。
