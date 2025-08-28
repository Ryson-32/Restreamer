#!/bin/bash

# Restreamer 多项目VPS部署脚本
# 使用方法: chmod +x deploy.sh && ./deploy.sh

set -e

echo "=== Restreamer 多项目VPS部署脚本 ==="
echo

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查是否为root用户
check_root() {
    if [[ $EUID -eq 0 ]]; then
        echo -e "${RED}请不要使用root用户运行此脚本${NC}"
        echo "建议使用普通用户，脚本会在需要时提示输入sudo密码"
        exit 1
    fi
}

# 检查Docker是否安装
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}Docker未安装，正在安装...${NC}"
        sudo apt-get update
        sudo apt-get install -y docker.io docker-compose-plugin
        sudo systemctl enable --now docker
        sudo usermod -aG docker $USER
        echo -e "${GREEN}Docker安装完成，请重新登录后再运行此脚本${NC}"
        exit 0
    fi
}

# 检查端口是否被占用
check_port() {
    local port=$1
    if sudo lsof -i :$port &> /dev/null; then
        return 1  # 端口被占用
    else
        return 0  # 端口可用
    fi
}

# 寻找可用端口
find_available_port() {
    local base_port=$1
    local port=$base_port
    
    while ! check_port $port; do
        ((port++))
        if [ $port -gt $((base_port + 1000)) ]; then
            echo -e "${RED}无法找到可用端口，请手动指定${NC}"
            exit 1
        fi
    done
    
    echo $port
}

# 显示当前端口使用情况
show_port_usage() {
    echo -e "${YELLOW}当前端口使用情况：${NC}"
    echo "监听的端口："
    sudo ss -tlnp | grep LISTEN | head -20
    echo
}

# 主函数
main() {
    check_root
    check_docker
    
    echo -e "${GREEN}开始部署Restreamer...${NC}"
    echo
    
    # 显示端口使用情况
    show_port_usage
    
    # 寻找可用端口
    echo -e "${YELLOW}正在寻找可用端口...${NC}"
    
    HTTP_PORT=$(find_available_port 18080)
    HTTPS_PORT=$(find_available_port 18181)
    RTMP_PORT=$(find_available_port 11935)
    RTMPS_PORT=$(find_available_port 11936)
    SRT_PORT=$(find_available_port 16000)
    
    echo "找到的可用端口："
    echo "  HTTP: $HTTP_PORT"
    echo "  HTTPS: $HTTPS_PORT"
    echo "  RTMP: $RTMP_PORT"
    echo "  RTMPS: $RTMPS_PORT"
    echo "  SRT: $SRT_PORT"
    echo
    
    # 询问用户是否继续
    read -p "是否使用这些端口继续部署？(y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "部署已取消"
        exit 1
    fi
    
    # 创建部署目录
    echo -e "${YELLOW}创建部署目录...${NC}"
    sudo mkdir -p /opt/restreamer/{config,data,videos}
    sudo chown -R $USER:$USER /opt/restreamer
    
    # 生成随机Token
    RTMP_TOKEN=$(openssl rand -hex 32)
    
    # 创建docker-compose.yml
    echo -e "${YELLOW}创建Docker Compose配置...${NC}"
    cat > /opt/restreamer/docker-compose.yml << EOF
version: "3.8"
services:
  restreamer:
    image: datarhei/restreamer:latest
    container_name: restreamer
    restart: unless-stopped
    ports:
      - "${HTTP_PORT}:8080"   # Web UI HTTP
      - "${HTTPS_PORT}:8181"   # Web UI HTTPS
      - "${RTMP_PORT}:1935"   # RTMP
      - "${RTMPS_PORT}:1936"   # RTMPS
      - "${SRT_PORT}:6000/udp" # SRT
    environment:
      - CORE_RTMP_ENABLE=true
      - CORE_RTMP_ENABLE_TLS=true
      - CORE_RTMP_TOKEN=${RTMP_TOKEN}
      - TZ=Asia/Shanghai
    volumes:
      - ./config:/core/config
      - ./data:/core/data
      - ./videos:/videos
    networks:
      - restreamer_net

networks:
  restreamer_net:
    driver: bridge
EOF
    
    # 创建环境变量文件
    cat > /opt/restreamer/.env << EOF
# Restreamer 配置
HTTP_PORT=${HTTP_PORT}
HTTPS_PORT=${HTTPS_PORT}
RTMP_PORT=${RTMP_PORT}
RTMPS_PORT=${RTMPS_PORT}
SRT_PORT=${SRT_PORT}
RTMP_TOKEN=${RTMP_TOKEN}
EOF
    
    # 启动服务
    echo -e "${YELLOW}启动Restreamer服务...${NC}"
    cd /opt/restreamer
    docker-compose up -d
    
    # 等待服务启动
    echo -e "${YELLOW}等待服务启动...${NC}"
    sleep 10
    
    # 检查服务状态
    if docker-compose ps | grep -q "Up"; then
        echo -e "${GREEN}✓ Restreamer部署成功！${NC}"
        echo
        echo "访问信息："
        echo "  Web界面: http://$(curl -s ifconfig.me):${HTTP_PORT}"
        echo "  本地访问: http://localhost:${HTTP_PORT}"
        echo
        echo "RTMP配置："
        echo "  RTMP URL: rtmp://$(curl -s ifconfig.me):${RTMP_PORT}/live"
        echo "  RTMPS URL: rtmps://$(curl -s ifconfig.me):${RTMPS_PORT}/live"
        echo "  Stream Key: ${RTMP_TOKEN}"
        echo
        echo "SRT配置："
        echo "  SRT URL: srt://$(curl -s ifconfig.me):${SRT_PORT}"
        echo
        echo "配置文件位置: /opt/restreamer/"
        echo "视频文件目录: /opt/restreamer/videos/"
        echo
        echo "常用命令："
        echo "  查看日志: cd /opt/restreamer && docker-compose logs -f"
        echo "  重启服务: cd /opt/restreamer && docker-compose restart"
        echo "  停止服务: cd /opt/restreamer && docker-compose down"
        echo
    else
        echo -e "${RED}✗ 服务启动失败，请检查日志${NC}"
        docker-compose logs
        exit 1
    fi
    
    # 询问是否配置防火墙
    echo
    read -p "是否配置防火墙规则？(y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}配置防火墙规则...${NC}"
        sudo ufw allow ${HTTP_PORT}/tcp
        sudo ufw allow ${HTTPS_PORT}/tcp
        sudo ufw allow ${RTMP_PORT}/tcp
        sudo ufw allow ${RTMPS_PORT}/tcp
        sudo ufw allow ${SRT_PORT}/udp
        echo -e "${GREEN}防火墙规则配置完成${NC}"
    fi
    
    echo
    echo -e "${GREEN}部署完成！请访问Web界面进行进一步配置。${NC}"
}

# 运行主函数
main "$@"
