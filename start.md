  - 启动：docker compose up -d  
  --d 表示后台启动                                                              
  - 查看状态：docker compose ps                                                             
  - 看日志：docker compose logs -f app docreader postgres                                   
  - 停止（保留数据）：docker compose down                             
  - 停止并清理孤儿容器：docker compose down --remove-orphans                                
  - 重启单个服务（例如 app）：docker compose restart app   

  docker exec -it ollama ollama list 查看模型运行



docker compose up -d --build app frontend   
docker compose up -d --build --no-deps app frontend 
docker compose up -d --build


docker compose down

网络问题先做好配置：
$env:HTTP_PROXY="http://127.0.0.1:7890"
$env:HTTPS_PROXY="http://127.0.0.1:7890"

# 测试是否能够访问：注意是 curl.exe 不是 curl
curl.exe -I https://registry-1.docker.io/v2/


docker compose build --build-arg HTTP_PROXY=http://host.docker.internal:7890 --build-arg HTTPS_PROXY=http://host.docker.internal:7890 app frontend



git -C "D:/AAAlimenAI/wechat_bot/WeKnora/.worktrees/model-usage-filters" commit -m "feat: add model usage filters"  
git -C "D:/AAAlimenAI/wechat_bot/WeKnora/.worktrees/model-usage-card-drilldown" merge   
  feature/model-usage-filters

环境变量设置
# 避免debian 502错误
$env:APT_MIRROR = "https://mirrors.aliyun.com"

$env:PIP_INDEX_URL = "https://mirrors.aliyun.com/pypi/simple/"
$env:UV_INDEX_URL = "https://mirrors.aliyun.com/pypi/simple/"
$env:GOPROXY = "https://goproxy.cn,direct"


docker compose build --no-cache `
  --build-arg APK_MIRROR_ARG=mirrors.aliyun.com `
  --build-arg GOPROXY=https://goproxy.cn,direct `
  --build-arg PIP_INDEX_URL=https://mirrors.aliyun.com/pypi/simple/ `
  --build-arg UV_INDEX_URL=https://mirrors.aliyun.com/pypi/simple/

docker compose build `
  --build-arg APK_MIRROR_ARG=mirrors.cloud.tencent.com `
  --build-arg GOPROXY=https://goproxy.cn,direct `
  --build-arg PIP_INDEX_URL=https://mirrors.cloud.tencent.com/pypi/simple/ `
  --build-arg UV_INDEX_URL=https://mirrors.cloud.tencent.com/pypi/simple/


开发模式：
docker compose -f docker-compose.dev.yml up -d