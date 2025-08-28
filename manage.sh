#!/bin/bash

# Restreamer 管理脚本
# 使用方法: chmod +x manage.sh && ./manage.sh

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

RESTREAMER_DIR="/opt/restreamer"

# 检查是否已部署
check_deployment() {
    if [ ! -d "$RESTREAMER_DIR" ] || [ ! -f "$RESTREAMER_DIR/docker-compose.yml" ]; then
        echo -e "${RED}Restreamer未部署，请先运行 deploy.sh${NC}"
        exit 1
    fi
}

# 显示状态
show_status() {
    echo -e "${BLUE}=== Restreamer 服务状态 ===${NC}"
    cd $RESTREAMER_DIR
    docker-compose ps
    echo
    
    # 显示资源使用情况
    if docker ps | grep -q restreamer; then
        echo -e "${BLUE}=== 资源使用情况 ===${NC}"
        docker stats restreamer --no-stream
        echo
    fi
    
    # 显示端口信息
    if [ -f ".env" ]; then
        echo -e "${BLUE}=== 端口配置 ===${NC}"
        source .env
        echo "HTTP端口: $HTTP_PORT"
        echo "HTTPS端口: $HTTPS_PORT"
        echo "RTMP端口: $RTMP_PORT"
        echo "RTMPS端口: $RTMPS_PORT"
        echo "SRT端口: $SRT_PORT"
        echo
    fi
}

# 显示日志
show_logs() {
    echo -e "${BLUE}=== 实时日志 (按Ctrl+C退出) ===${NC}"
    cd $RESTREAMER_DIR
    docker-compose logs -f
}

# 重启服务
restart_service() {
    echo -e "${YELLOW}重启Restreamer服务...${NC}"
    cd $RESTREAMER_DIR
    docker-compose restart
    echo -e "${GREEN}服务重启完成${NC}"
}

# 停止服务
stop_service() {
    echo -e "${YELLOW}停止Restreamer服务...${NC}"
    cd $RESTREAMER_DIR
    docker-compose down
    echo -e "${GREEN}服务已停止${NC}"
}

# 启动服务
start_service() {
    echo -e "${YELLOW}启动Restreamer服务...${NC}"
    cd $RESTREAMER_DIR
    docker-compose up -d
    echo -e "${GREEN}服务启动完成${NC}"
}

# 更新服务
update_service() {
    echo -e "${YELLOW}更新Restreamer...${NC}"
    cd $RESTREAMER_DIR
    docker-compose pull
    docker-compose up -d
    echo -e "${GREEN}更新完成${NC}"
}

# 备份数据
backup_data() {
    local backup_dir="/opt/restreamer-backups"
    local backup_file="restreamer-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    
    echo -e "${YELLOW}创建备份...${NC}"
    sudo mkdir -p $backup_dir
    
    cd /opt
    sudo tar -czf "$backup_dir/$backup_file" restreamer/config restreamer/data
    
    echo -e "${GREEN}备份完成: $backup_dir/$backup_file${NC}"
    
    # 显示备份大小
    ls -lh "$backup_dir/$backup_file"
}

# 恢复数据
restore_data() {
    local backup_dir="/opt/restreamer-backups"
    
    echo -e "${BLUE}可用的备份文件：${NC}"
    ls -la $backup_dir/*.tar.gz 2>/dev/null || {
        echo -e "${RED}没有找到备份文件${NC}"
        return 1
    }
    
    echo
    read -p "请输入要恢复的备份文件名: " backup_file
    
    if [ ! -f "$backup_dir/$backup_file" ]; then
        echo -e "${RED}备份文件不存在${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}停止服务...${NC}"
    cd $RESTREAMER_DIR
    docker-compose down
    
    echo -e "${YELLOW}恢复数据...${NC}"
    cd /opt
    sudo tar -xzf "$backup_dir/$backup_file"
    
    echo -e "${YELLOW}启动服务...${NC}"
    cd $RESTREAMER_DIR
    docker-compose up -d
    
    echo -e "${GREEN}恢复完成${NC}"
}

# 清理日志
clean_logs() {
    echo -e "${YELLOW}清理Docker日志...${NC}"
    docker system prune -f
    echo -e "${GREEN}日志清理完成${NC}"
}

# 显示访问信息
show_access_info() {
    if [ -f "$RESTREAMER_DIR/.env" ]; then
        source "$RESTREAMER_DIR/.env"
        local external_ip=$(curl -s ifconfig.me 2>/dev/null || echo "获取失败")
        
        echo -e "${BLUE}=== 访问信息 ===${NC}"
        echo "外网访问: http://$external_ip:$HTTP_PORT"
        echo "内网访问: http://localhost:$HTTP_PORT"
        echo
        echo -e "${BLUE}=== RTMP推流信息 ===${NC}"
        echo "RTMP URL: rtmp://$external_ip:$RTMP_PORT/live"
        echo "RTMPS URL: rtmps://$external_ip:$RTMPS_PORT/live"
        echo "Stream Key: $RTMP_TOKEN"
        echo
        echo -e "${BLUE}=== SRT推流信息 ===${NC}"
        echo "SRT URL: srt://$external_ip:$SRT_PORT"
        echo
    else
        echo -e "${RED}配置文件不存在${NC}"
    fi
}

# 监控服务
monitor_service() {
    echo -e "${BLUE}=== 服务监控 (每5秒刷新，按Ctrl+C退出) ===${NC}"
    while true; do
        clear
        echo -e "${BLUE}=== $(date) ===${NC}"
        show_status
        sleep 5
    done
}

# 显示菜单
show_menu() {
    echo -e "${GREEN}=== Restreamer 管理脚本 ===${NC}"
    echo
    echo "1. 显示服务状态"
    echo "2. 查看实时日志"
    echo "3. 重启服务"
    echo "4. 停止服务"
    echo "5. 启动服务"
    echo "6. 更新服务"
    echo "7. 备份数据"
    echo "8. 恢复数据"
    echo "9. 清理日志"
    echo "10. 显示访问信息"
    echo "11. 监控服务"
    echo "0. 退出"
    echo
}

# 主函数
main() {
    check_deployment
    
    if [ $# -eq 0 ]; then
        # 交互模式
        while true; do
            show_menu
            read -p "请选择操作 (0-11): " choice
            echo
            
            case $choice in
                1) show_status ;;
                2) show_logs ;;
                3) restart_service ;;
                4) stop_service ;;
                5) start_service ;;
                6) update_service ;;
                7) backup_data ;;
                8) restore_data ;;
                9) clean_logs ;;
                10) show_access_info ;;
                11) monitor_service ;;
                0) echo "退出"; exit 0 ;;
                *) echo -e "${RED}无效选择${NC}" ;;
            esac
            
            echo
            read -p "按回车键继续..."
            clear
        done
    else
        # 命令行模式
        case $1 in
            status) show_status ;;
            logs) show_logs ;;
            restart) restart_service ;;
            stop) stop_service ;;
            start) start_service ;;
            update) update_service ;;
            backup) backup_data ;;
            restore) restore_data ;;
            clean) clean_logs ;;
            info) show_access_info ;;
            monitor) monitor_service ;;
            *) 
                echo "用法: $0 [status|logs|restart|stop|start|update|backup|restore|clean|info|monitor]"
                echo "或直接运行 $0 进入交互模式"
                ;;
        esac
    fi
}

# 运行主函数
main "$@"
