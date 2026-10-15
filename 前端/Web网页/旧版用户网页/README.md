# <font id=前言>用户／师傅 [**Web**](https://developer.mozilla.org/en-US/docs/Web) 端</font>

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

本目录保留旧版 `/api/v1` 用户／师傅网页，与 [旧 Go API](../../../后端/Go服务端/README.md) 配套；当前 V3.8 主页面为 [维修工作台](../维修工作台/index.html)，接口为 `/api/v38`。目录整理不扩展旧业务能力，也不修复第五轮 17 组问题。

PC 浏览器入口由 API 同源托管于 `/portal/`，与 `/admin/` 运营后台分离。用于验证用户／师傅多端登录及基本工单流程，不代表 Windows 或 macOS 原生客户端已经实现。

## 一、扫码与多端登录 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

PC 页面生成两分钟登录二维码，完成授权需要已登录且具备手机授权权限的配套客户端。旧接口保留核对 PC 信息后确认／拒绝的流程；本次 [iOS 目录](../../iOS/README.md) 仅预留，未提供手机工程。页面“模拟器联调”复制二维码内容只作旧接口联调辅助；仅 pending、网络失败或 consumed 均不能当成登录成功，领取响应丢失需重新生成二维码。

手机批准后 PC 原子领取独立会话；手机退出只撤销手机会话，PC 在自己的有效期内继续登录。手机可从“登录设备”撤销指定设备；PC 收到401时清除本页凭据和账号数据。PC 扫码会话没有手机的设备管理／授权权限。

账号密码登录是备用入口，PC 始终申请 desktop 会话。凭据只存浏览器 `sessionStorage`，支持当前标签页刷新；关闭该浏览器会话后重新登录。禁用存储时只保留页面内存。密码和二维码轮询证明不持久化；会话按环境及服务地址隔离，切换后重新登录，旧请求不能覆盖新页面。

二维码由本地打包的 [**QRCodeJS**](https://github.com/davidshimjs/qrcodejs) 生成，不把扫码内容发送给图片生成网站。来源、固定提交和校验摘要位于 [`ThirdParty/QRCodeJS/source.json`](./ThirdParty/QRCodeJS/source.json)，MIT许可随包保留；供应商代码不修改。

## 二、业务与无服务器预览 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

用户可提交报修、确认报价；审核通过的师傅可查看待接订单及本人工单，接单、登记到场、提交报价与完工。本人账务查询当前使用模拟账本，服务端强制当前主体范围。列表按游标加载下一页；空列表提供本地 Logo 和重新加载入口。

每次进入／刷新、每个写操作仍请求 API，连接和正文读取默认2秒超时。业务失败时只在独立本地副本演示，保留失败／结果未知提示，不自动重发；报修未知结果保留原表单与 Idempotency-Key。登录、扫码、授权与真实账务不会伪造成功。接口恢复后下一次成功响应覆盖为服务端数据。

`environment.js` 保留测试和空线上地址，默认复用 `/portal/` 的同源地址；修改测试地址后点击保存。线上尚未配置时明确提示。直接打开 `index.html` 可看离线业务预览，实际登录需使用 Go 托管的同源页面。所有 Logo 随页面本地打包，未新增网络图片依赖。

## 三、验证 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

项目根目录运行，无构建步骤或 npm 安装：

```sh
node --test 前端/Web网页/旧版用户网页/tests/*.test.cjs
```

使用 [**Node.js**](https://nodejs.org) 内置测试验证登录失败、扫码待确认／一次兑换、服务切换丢弃迟到结果、PC退出／撤销清除、标签页刷新会话保留。实际手机相机扫描仍需真机验证。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
