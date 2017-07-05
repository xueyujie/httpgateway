# HTTP 消息总线
> IPC即进程间通信（Inter-Porcess Communication）。微服务架构中有两类IPC机制可选：异步消息机制和同步请求/响应机制

在同步请求/响应机制里，假设服务之间直接通讯。每个服务暴露一组REST API，外部的服务或者客户端通过REST API来调用。明显的，这种模型对于简单的微服务架构应用有效。但是随着服务数量的增加，它会慢慢变得复杂。这也是为什么在SOA里面要用ESB来避免杂乱的点对点的连接。让我们试着总结一下点对点模式的弊端。

- 非功能需求，比如用户认证、流控、监控等必须在每个微服务里实现；
- 由于通用功能的重复，每个微服务的实现变得复杂；
- 在服务和客户端之间没有通讯控制（甚至对于监控、跟踪、过滤等都没有）；
- 对于大的微服务实现来说直接的通讯形式通常被认为是[反模式](http://www.infoq.com/articles/seven-uservices-antipatterns)。


因此， 在复杂的微服务应用场景下，不要使用点对点直连或者中央的ESB，我们可以使用一个**轻量级的中央消息总线**给所有微服务提供一个抽象层，而且可以用来实现各种非功能的能力。这种风格也叫做API Gateway风格。

![](http://img.dockerinfo.net/2016/07/20160718114652.jpg)

#### 功能点

1. 授权认证和访问控制
1. 流控、`熔断`
1. 日志、跟踪
1. 健康检查


#### 实现

基于[openrestry](https://openresty.org/en/)开发，集成在 Nginx 中运行，扩展了 Nginx 本身的功能。具有高性能和高可靠的特征。
代码结构参考[kong](https://github.com/Mashape/kong)

#### 安装运行

dockerhub地址
> https://hub.docker.com/r/ifintech/httpgateway/

docker启动
> docker run -itd --name httpgateway ifintech/httpgateway

docker进入
> docker exec -it httpgateway /bin/bash

测试用例

```bash
curl -v -H 'Host:demo.i.com' -H 'x-source:test' -H 'x-time:1499162113' -H 'x-m:3c21c58c1db30f685d0c51273ef9107b' 'http://127.0.0.1/'
* About to connect() to 127.0.0.1 port 80 (#0)
*   Trying 127.0.0.1... connected
* Connected to 127.0.0.1 (127.0.0.1) port 80 (#0)
> GET / HTTP/1.1
> User-Agent: curl/7.19.7 (x86_64-redhat-linux-gnu) libcurl/7.19.7 NSS/3.21 Basic ECC zlib/1.2.3 libidn/1.18 libssh2/1.4.2
> Accept: */*
> Host:demo.i.com
> x-source:test
> x-time:1499162113
> x-m:3c21c58c1db30f685d0c51273ef9107b
>
< HTTP/1.1 200 OK
< Server: openresty/1.11.2.3
< Date: Tue, 04 Jul 2017 10:13:13 GMT
< Content-Type: text/html
< Transfer-Encoding: chunked
< Connection: keep-alive
< Vary: Accept-Encoding
< x-rid: 6757db031aead165d03be763efbfabc0
<
<p>hello, world</p>
* Connection #0 to host 127.0.0.1 left intact
* Closing connection #0
```

ab测试
```bash
[root@5f36496f0229 nginx]# ab -c 100 -n 10000 -H 'Host:demo.i.com' -H 'x-source:test' -H 'x-time:1499162113' -H 'x-m:3c21c58c1db30f685d0c51273ef9107b' http://127.0.0.1/
This is ApacheBench, Version 2.3 <$Revision: 655654 $>
Copyright 1996 Adam Twiss, Zeus Technology Ltd, http://www.zeustech.net/
Licensed to The Apache Software Foundation, http://www.apache.org/

Benchmarking 127.0.0.1 (be patient)
Completed 1000 requests
Completed 2000 requests
Completed 3000 requests
Completed 4000 requests
Completed 5000 requests
Completed 6000 requests
Completed 7000 requests
Completed 8000 requests
Completed 9000 requests
Completed 10000 requests
Finished 10000 requests


Server Software:        openresty/1.11.2.3
Server Hostname:        127.0.0.1
Server Port:            80

Document Path:          /
Document Length:        20 bytes

Concurrency Level:      100
Time taken for tests:   0.903 seconds
Complete requests:      10000
Failed requests:        0
Write errors:           0
Total transferred:      2090000 bytes
HTML transferred:       200000 bytes
Requests per second:    11072.90 [#/sec] (mean)
Time per request:       9.031 [ms] (mean)
Time per request:       0.090 [ms] (mean, across all concurrent requests)
Transfer rate:          2260.00 [Kbytes/sec] received

Connection Times (ms)
              min  mean[+/-sd] median   max
Connect:        0    1   1.5      0      11
Processing:     1    8   1.8      8      20
Waiting:        0    8   1.6      8      16
Total:          3    9   2.5      8      29

Percentage of the requests served within a certain time (ms)
  50%      8
  66%      9
  75%      9
  80%     10
  90%     10
  95%     12
  98%     19
  99%     20
 100%     29 (longest request)
```
