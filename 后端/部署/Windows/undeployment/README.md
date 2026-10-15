# [**Windows**](https://www.microsoft.com/windows) 停止与反部署预留

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

## 🔥 <span id="前言">前言</span>

当前没有自动反部署或删除脚本。此目录只说明停止方式和后续实现边界，不代表已经完成卸载。

## 一、<span id="stop-service">当前停止方式</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

当前没有在本系统实现服务安装或运行入口，因此这里也没有可自动停止或卸载的已登记项目服务。后续须先辨认用户实际部署的资源，再提供只针对本项目的操作。

## 二、<span id="retain">后续反部署默认保留</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

默认保留业务数据、上传附件、密钥、环境配置、数据库及备份。停止进程、移除服务注册或清除构建产物应与数据删除分开；删除必须由用户明确选择对应路径及资源，先确认备份和恢复方式，禁止默认清空整个运行目录或删除共享依赖。

当前没有实现上述自动操作。返回 [本系统部署文档](../部署文档.md) 或 [部署入口](../deployment/README.md)。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>

