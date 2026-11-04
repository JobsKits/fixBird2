#!/usr/bin/env node
// 自述：仅连接显式指定的隔离回环服务；使用合成账号新增独立测试工单。
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { AdminStore } from '../../../../代码/前端/后台管理端/Web/core.mjs';
const target=process.env.WB_INTEGRATION_URL;
if(!target)throw Error('请设置 WB_INTEGRATION_URL 为隔离测试服务地址');
const url=new URL(target);
if(url.hostname!=='127.0.0.1'||!url.port||['8098','8099'].includes(url.port))throw Error('只允许显式隔离回环端口，不连接日常实例');
const spec=JSON.parse(await readFile(new URL('../../../../代码/前端/后台管理端/共享契约/admin-ui.json',import.meta.url)));
const s=new AdminStore(spec);s.base=target;
await s.login('admin','Demo-Repair-2026!');assert.equal(s.demo,false);assert.equal(s.actor.role,'admin');console.log('PASS 真实登录与身份锚点');
const customer=(await s.request('/accounts')).find(a=>a.id==='customer');
const created=await s.create({type:'onsite',customer:customer.name,customerId:customer.id,companyId:customer.companyId,project:'管理端隔离回归',device:'合成控制柜',description:'API适配器真实创建后读回'});
const read=await s.detail(created.id);assert.equal(read.id,created.id);assert.equal(read.isSummary,undefined);console.log('PASS 创建并独立读回完整详情');
const next=await s.act(read,'intake',{ownerId:'dispatcher',assigneeId:'engineer'});assert.equal(next.status,'pending_arrangement');assert.ok(next.version>read.version);console.log('PASS 动作版本递增与合法阶段');
await assert.rejects(s.act(read,'intake',{ownerId:'dispatcher',assigneeId:'engineer'}));console.log('PASS 旧版本冲突明确拒绝');
const result=await s.request('/export');assert.equal(result.actor.id,s.actor.id);assert.ok(result.orders.some(o=>o.id===created.id));console.log('PASS 当前身份授权导出');
await s.request('/logout',{});await assert.rejects(s.request('/session'),e=>e.status===401);s.logout();assert.equal(s.actor,null);console.log('PASS 退出与旧会话撤销');
console.log('RESULT cases=6 failures=0 skips=0');
