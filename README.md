# 名称
内部服务网关-通过gateway将松散的服务应用，在入口层面服务划分，给中台和后台服务提供HTTP统一网关和服务治理

# 目标
服务负载均衡，内部应用服务统一使用*.i.gateway.com，*即服务在内部的代号（APP_NAME）,此处内部服务网关承担请求对具体应用服务器的分发和负载均衡工作  
服务管理，所有应用都在内部服务网关有注册，内部服务网关给应用分配APP_NAME和SECRET，用来服务在内部流转证明和信息加密  
服务访问控制，此处内部服务网关承担AUTH和ACL校验功能，提供IP白名单和黑名单功能，如果失败返回403  
服务健康检查，负载均衡健康检查策略  
服务追踪，为后期的追踪系统提供统一依据  
服务限流，对来访的每个应用可以做限流，目标应用可以分别设置每个请求应用的请求限制速率和允许突发请求速率，超过请求限制速率但是小于允许突发请求速率的请求会被延迟处理  
服务降级，如果服务故障，全部或者部分在入口处返回错误，控制流量进入  
服务HTTP防火墙，对http进行识别，将风险项统一处理，可以在一定程度上阻止常见的 SQL 注入、Git 及 SVN 文件泄露、目录遍历攻击，并拦截常见的扫描工具。

# 实现
基于lua_nginx_module(openrestry)开发，集成在 Nginx 中运行，扩展了 Nginx 本身的功能。具有高性能和高可靠的特征。  
具体见dockerfile

# 需要依赖
## rate-limiting插件
流量控制
```
opm get openresty/lua-resty-limit-traffic
```
## ip-restriction插件
ip限制
```
opm get hamishforbes/lua-resty-iputils
```
判断location
```
opm get firesnow/lua-resty-location-match
```
## balancer插件
```
opm get firesnow/lua-resty-checkups
```