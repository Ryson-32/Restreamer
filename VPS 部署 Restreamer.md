# 在 Ubuntu 22.04 VPS 部署 **Restreamer** 推流到 Mux（24×7 循环伪直播）——操作手册

> 本文面向：希望把 VPS 上的视频素材，通过 **Web UI** 配好“循环播放输入源（Loop）”，并**持续推流到 Mux（RTMPS/SRT）** 的用户。
> 关键步骤均以官方文档核对并附上引用链接；命令可直接复制执行。

---

## 目录

* [一、方案综述](https://chatgpt.com/c/68b03011-5c00-8327-af6a-284af96610a1?model=gpt-5-thinking#%E4%B8%80%E6%96%B9%E6%A1%88%E7%BB%BC%E8%BF%B0)
* [二、系统准备](https://chatgpt.com/c/68b03011-5c00-8327-af6a-284af96610a1?model=gpt-5-thinking#%E4%BA%8C%E7%B3%BB%E7%BB%9F%E5%87%86%E5%A4%87)
* [三、启动 Restreamer（Docker）](https://chatgpt.com/c/68b03011-5c00-8327-af6a-284af96610a1?model=gpt-5-thinking#%E4%B8%89%E5%90%AF%E5%8A%A8-restreamerdocker)
* [四、首次登录与向导](https://chatgpt.com/c/68b03011-5c00-8327-af6a-284af96610a1?model=gpt-5-thinking#%E5%9B%9B%E9%A6%96%E6%AC%A1%E7%99%BB%E5%BD%95%E4%B8%8E%E5%90%91%E5%AF%BC)
* [五、配置 24×7 循环播放源（Loop）](https://chatgpt.com/c/68b03011-5c00-8327-af6a-284af96610a1?model=gpt-5-thinking#%E4%BA%94%E9%85%8D%E7%BD%AE-24%C3%977-%E5%BE%AA%E7%8E%AF%E6%92%AD%E6%94%BE%E6%BA%90loop)
* [六、向 Mux 推流（RTMPS）](https://chatgpt.com/c/68b03011-5c00-8327-af6a-284af96610a1?model=gpt-5-thinking#%E5%85%AD%E5%90%91-mux-%E6%8E%A8%E6%B5%81rtmps)
* [七、可选：改用 SRT 推流到 Mux](https://chatgpt.com/c/68b03011-5c00-8327-af6a-284af96610a1?model=gpt-5-thinking#%E4%B8%83%E5%8F%AF%E9%80%89%E6%94%B9%E7%94%A8-srt-%E6%8E%A8%E6%B5%81%E5%88%B0-mux)
* [八、生产化与安全建议](https://chatgpt.com/c/68b03011-5c00-8327-af6a-284af96610a1?model=gpt-5-thinking#%E5%85%AB%E7%94%9F%E4%BA%A7%E5%8C%96%E4%B8%8E%E5%AE%89%E5%85%A8%E5%BB%BA%E8%AE%AE)
* [九、常见问题与排障](https://chatgpt.com/c/68b03011-5c00-8327-af6a-284af96610a1?model=gpt-5-thinking#%E4%B9%9D%E5%B8%B8%E8%A7%81%E9%97%AE%E9%A2%98%E4%B8%8E%E6%8E%92%E9%9A%9C)
* [十、Docker Compose 模板](https://chatgpt.com/c/68b03011-5c00-8327-af6a-284af96610a1?model=gpt-5-thinking#%E5%8D%81docker-compose-%E6%A8%A1%E6%9D%BF)
* [十一、附录：FFmpeg 预处理示例](https://chatgpt.com/c/68b03011-5c00-8327-af6a-284af96610a1?model=gpt-5-thinking#%E5%8D%81%E4%B8%80%E9%99%84%E5%BD%95ffmpeg-%E9%A2%84%E5%A4%84%E7%90%86%E7%A4%BA%E4%BE%8B)

---

## 一、方案综述

* **Restreamer** 提供完整 **Web UI**，开启容器后即可通过向导添加视频源，并通过 **Publication services** 将流发布到外部平台（RTMP/RTMPS/SRT）。([docs.datarhei.com](https://docs.datarhei.com/restreamer/getting-started/quick-start))
* 官方 **Quick Start** 给出标准端口与 Docker 运行示例（HTTP 80→容器 8080、HTTPS 443→容器 8181；常见还会映射 RTMP 1935、RTMPS 1936、SRT 6000/UDP）。([docs.datarhei.com](https://docs.datarhei.com/restreamer/getting-started/quick-start))

---

## 二、系统准备

```
# 1) 更新并安装 Docker（Ubuntu 22.04）
sudo apt-get update
sudo apt-get install -y docker.io docker-compose-plugin
sudo systemctl enable --now docker

# 2) 目录
sudo mkdir -p /opt/restreamer/{config,data}
```

---

## 三、启动 Restreamer（Docker）

> 下面命令与官方 Quick Start 端口映射一致，适合首启测试；生产环境建议配合反向代理/证书。([docs.datarhei.com](https://docs.datarhei.com/restreamer/getting-started/quick-start))

```
docker run -d --name restreamer --restart unless-stopped \
  -v /opt/restreamer/config:/core/config \
  -v /opt/restreamer/data:/core/data \
  -p 8080:8080 -p 8181:8181 \
  -p 1935:1935 -p 1936:1936 \
  -p 6000:6000/udp \
  datarhei/restreamer:latest
```

> 如需启用**内置 RTMP/RTMPS 服务器**并设发布 Token（更安全），可加环境变量：
> `-e CORE_RTMP_ENABLE=true -e CORE_RTMP_ENABLE_TLS=true -e CORE_RTMP_TOKEN=<长随机串>`（变量释义见官方页）。([docs.datarhei.com](https://docs.datarhei.com/restreamer/api/environment-variables))

---

## 四、首次登录与向导

* 浏览器访问 `http://<服务器IP>:8080`，进入 **图形界面**；
* 按 **Wizard** 提示添加视频源（后续随时可在“Stream settings”里编辑）。([docs.datarhei.com](https://docs.datarhei.com/restreamer/knowledge-base/manual/wizard?utm_source=chatgpt.com))

---

## 五、配置 24×7 循环播放源（Loop）

> 目标：让 Restreamer **以单个文件循环**输出连续直播。当前版本支持**循环本地文件**；**网络源暂不支持 Loop**。([GitHub](https://github.com/datarhei/restreamer/issues/697?utm_source=chatgpt.com))

### 5.1 在 UI 中创建 Loop 源

* 新建视频源时选择 **Loop / 循环**（若页面有上传限制，见下节“替换技巧”）。
* 如需**常驻 BGM**，UI 自 **v1.10.0** 起支持 **Audio Loop**（音频循环源）。([GitHub](https://github.com/datarhei/restreamer/releases?utm_source=chatgpt.com))

### 5.2 大文件上传限制与替换技巧

* 若 UI 上传 Loop 文件受限，可在**挂载目录**中将你的 `xxx.mp4` **改名为 `xxx.source`**，覆盖 UI 生成的小文件，再回到 UI 点击 **Probe/检查** 并保存即可；官方维护者确认此法可绕过上传限制（网络源 Loop 仍不支持）。([GitHub](https://github.com/datarhei/restreamer/issues/697?utm_source=chatgpt.com))

> **素材编码建议**：尽量使用 **H.264（Main）+AAC、恒定帧率**，便于“直通”推流与平台兼容。

---

## 六、向 Mux 推流（RTMPS）

1. 打开 **Publication services**，新建 **RTMP** 目标。([docs.datarhei.com](https://docs.datarhei.com/restreamer/knowledge-base/manual/publications?utm_source=chatgpt.com))
2. **Server URL**（二选一，推荐 RTMPS）：
  * `rtmps://global-live.mux.com:443/app`（安全入口）
  * `rtmp://global-live.mux.com:5222/app`（标准 RTMP，**端口 5222** 非 1935）
在 Mux 官方“配置推流软件”文档中明确给出上述地址与端口说明。([mux.com](https://www.mux.com/docs/guides/configure-broadcast-software))
3. **Stream Key**：填你在 Mux 后台该 Live Stream 的 **Stream Key**。Mux “开始直播”文档说明每条 Live Stream 都有唯一的 key，并与上述 Server URL 搭配使用。([mux.com](https://www.mux.com/docs/guides/start-live-streaming))
4. **编码起步参数（Mux 建议）**
  * 视频：**H.264（Main）1080p/30fps，5000 kbps，关键帧间隔 2s**
  * 音频：**AAC**
同页还建议上行码率**不超过可用带宽的 ~50%**。([mux.com](https://www.mux.com/docs/guides/configure-broadcast-software))

保存并**启动**该 Publication，Mux 后台应出现“连接/可预览”。

---

## 七、可选：改用 **SRT** 推流到 Mux

* 在 Publication 选择 **SRT**，填写 URL（**Caller 模式**），形如：

```
srt://<region>.live.mux.com:6001?streamid=<STREAM_KEY>&passphrase=<SRT_PASSPHRASE>
```

Mux 文档给出 **全局/区域** SRT Ingest URL 与 `streamid`/`passphrase` 规则；所有 RTMP 入口也支持 RTMPS。([mux.com](https://www.mux.com/docs/guides/configure-broadcast-software))

---

## 八、生产化与安全建议

* **容器自启动**：已在命令中使用 `--restart unless-stopped`。官方 Quick Start 也示例了“随系统拉起”的用法。([docs.datarhei.com](https://docs.datarhei.com/restreamer/getting-started/quick-start))
* **只开放必要端口**：面向公网建议仅开放管理/反向代理端口，将 1935/1936 仅在需要外部推入时放行。
* **RTMP/RTMPS Token**：若启用内置 RTMP/RTMPS 入口，务必设置 `CORE_RTMP_TOKEN` 以防止未授权推/拉流。([docs.datarhei.com](https://docs.datarhei.com/restreamer/api/environment-variables))

---

## 九、常见问题与排障

* **Mux 无画面/无法连接**：检查 **Server URL + Stream Key**；注意 Mux **RTMP 为 5222 端口**，RTMPS 为 443。([mux.com](https://www.mux.com/docs/guides/configure-broadcast-software))
* **UI 上传 Loop 文件过大**：采用 **`.source` 替换法**（见上文 5.2）。([GitHub](https://github.com/datarhei/restreamer/issues/697?utm_source=chatgpt.com))
* **无视频输出**：按官方“**No video**”条目逐步检查源可用性（可用 VLC 测试）、硬件/网络链路等。([docs.datarhei.com](https://docs.datarhei.com/restreamer/knowledge-base/troubleshooting/no-video?utm_source=chatgpt.com))
* **需要同时开多路外发**：Publication 支持创建多目标，按需启停。([docs.datarhei.com](https://docs.datarhei.com/restreamer/knowledge-base/manual/publications?utm_source=chatgpt.com))

---

## 十、Docker Compose 模板

```
# /opt/restreamer/docker-compose.yml
version: "3.8"
services:
  restreamer:
    image: datarhei/restreamer:latest
    container_name: restreamer
    restart: unless-stopped
    ports:
      - "8080:8080"   # UI / HTTP
      - "8181:8181"   # UI / HTTPS
      - "1935:1935"   # RTMP (可选)
      - "1936:1936"   # RTMPS (可选)
      - "6000:6000/udp" # SRT (可选)
    environment:
      - CORE_RTMP_ENABLE=true
      - CORE_RTMP_ENABLE_TLS=true
      - CORE_RTMP_TOKEN=${CORE_RTMP_TOKEN:-change_me}
    volumes:
      - /opt/restreamer/config:/core/config
      - /opt/restreamer/data:/core/data
```

> 端口与变量含义参见官方 **Quick Start / Environment Variables / RTMP 设置**。([docs.datarhei.com](https://docs.datarhei.com/restreamer/getting-started/quick-start))

---

## 十一、附录：FFmpeg 预处理示例

> 当素材不是 H.264/AAC 或参数与 Mux 推荐不符时，可先做转码，降低实时负载。

```
ffmpeg -i input.mp4 -vf "scale=-2:1080" -r 30 \
  -c:v libx264 -profile:v main -preset veryfast -b:v 5000k -maxrate 5500k -bufsize 10000k \
  -g 60 -keyint_min 60 -sc_threshold 0 \
  -c:a aac -b:a 128k -ar 48000 -ac 2 output_1080p30.mp4
```

* 以上参数对应 **1080p/30fps、≈5 Mbps、关键帧 2s**，与 Mux 的“**Recommended encoder settings**”一致。([mux.com](https://www.mux.com/docs/guides/configure-broadcast-software))

---

### 参考

* Restreamer：**Quick Start、Wizard、Publication services、Environment Variables、RTMP/RTMPS 设置、No video** 等。([docs.datarhei.com](https://docs.datarhei.com/restreamer/getting-started/quick-start))
* 功能/限制与变更：**Audio Loop（v1.10.0）**、**Loop 大文件与 `.source` 替换**、**网络源暂不支持 Loop**。([GitHub](https://github.com/datarhei/restreamer/releases?utm_source=chatgpt.com))
* Mux：**RTMP/RTMPS 入口与端口、编码建议、区域 Ingest 与 SRT URL 规则**。([mux.com](https://www.mux.com/docs/guides/configure-broadcast-software))

---

> 需要的话，我可以把你的**素材清单**转成示例播放/循环清单，并给出 **UFW/反代（Caddy/Nginx）** 最小化配置片段，直接拷贝即用。