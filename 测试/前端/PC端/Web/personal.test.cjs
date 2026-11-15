/* Jobs · 真实个人模块的私密草稿、附件、日历并发与单次提醒行为回归。 */
const test = require("node:test");
const assert = require("node:assert/strict");
const { spawnSync } = require("node:child_process");
const path = require("node:path");
const P = require("../../../../代码/前端/PC端/Web/维修工作台/personal.js");
const flush = async () => { for (let index = 0; index < 8; index++) await new Promise(setImmediate); };
const deferred = () => { let resolve, reject; const promise = new Promise((yes, no) => { resolve = yes; reject = no; }); return { promise, resolve, reject }; };
const decode = text => String(text).replace(/&lt;/g,"<").replace(/&gt;/g,">").replace(/&quot;/g,'"').replace(/&#39;/g,"'").replace(/&amp;/g,"&");

function browser() {
  const nodes = new Map(), events = new Map(), windowEvents = new Map(), created = [], revoked = [];
  let focuses = 0;
  function node(id) {
    if (!nodes.has(id)) {
      let html = "";
      const children = new Set();
      const attributes = new Map();
      const value = { id, value:"", disabled:false, dataset:{}, textContent:"", open:false,
        setAttribute(name,content){attributes.set(name,String(content));},getAttribute(name){return attributes.get(name)||null;},
        showModal(){value.open=true;},close(){value.open=false;value.onclose?.();},
        focus(){ focuses++; doc.activeElement = value; } };
      Object.defineProperty(value,"innerHTML",{
        get:()=>html,
        set:next=>{
          for(const child of children) nodes.delete(child);
          children.clear(); html=next;
          const expressions=[
            /<textarea[^>]*id="([^"]+)"[^>]*>([\s\S]*?)<\/textarea>/g,
            /<(?:input|select|form|section|div|p|button|dialog|span|h2|h3|time)[^>]*id="([^"]+)"[^>]*>/g
          ];
          for(const expression of expressions) for(const match of next.matchAll(expression)){
            const child=node(match[1]);children.add(match[1]);
            child.value=expression===expressions[0]?decode(match[2]):decode(match[0].match(/value="([^"]*)"/)?.[1]||"");
            const selected=next.match(new RegExp('<select[^>]*id="'+match[1]+'"[^>]*>([\\s\\S]*?)</select>'))?.[1];
            if(selected)child.value=selected.match(/<option value="([^"]+)" selected/)?.[1]||"";
          }
        }
      });
      value.insertAdjacentHTML=(_where,extra)=>{value.innerHTML=value.innerHTML+extra;};
      nodes.set(id,value);
    }
    return nodes.get(id);
  }
  const doc={documentElement:{lang:"zh-CN"},visibilityState:"visible",activeElement:null,
    querySelector:selector=>selector.startsWith("#")?nodes.get(selector.slice(1))||null:null,
    addEventListener(type,fn){if(!events.has(type))events.set(type,[]);events.get(type).push(fn);}
  };
  ["worklogsView","personalReminders","personalTips"].forEach(node);
  const timers=[];
  const env={document:doc,now:()=>Date.parse("2026-11-14T02:00:00Z"),Blob,btoa,atob,
    URL:{createObjectURL(blob){const url="blob:private-"+created.length;created.push({url,blob});return url;},revokeObjectURL(url){revoked.push(url);}},
    setInterval(fn){timers.push(fn);return timers.length;},clearInterval(){},setTimeout(fn){fn();},
    addEventListener(type,fn){windowEvents.set(type,fn);},
    localStorage:{setItem(){throw Error("private persistence forbidden");},getItem(){throw Error("private persistence forbidden");}}
  };
  async function emit(type,target={},extra={}){
    const event={target,preventDefault(){event.prevented=true;},...extra};
    for(const listener of events.get(type)||[])listener(event);
    await flush();return event;
  }
  const click=dataset=>emit("click",{dataset,closest(){return this;}});
  const input=async(id,value)=>{const target=node(id);target.value=value;return emit("input",target);};
  return {env,doc,nodes,node,events,timers,windowEvents,created,revoked,click,input,emit,getFocuses:()=>focuses};
}

function service() {
  const logs=new Map(),media=new Map(),reminders=new Map(),calls=[];
  let serial=0;
  const timestamp="2026-11-14T02:00:00Z";
  function actor(id="alice",role="dispatcher"){return{id,role,companyId:"company-a",authVersion:1};}
  const log=(owner,date)=>logs.get(owner+":"+date)||{ownerId:owner,date,text:"",media:[],version:0,updatedAt:""};
  function detail(record,identity,zone){return structuredClone({...record,today:"2026-11-14",timeZone:zone||"Asia/Shanghai",readOnly:record.ownerId!==identity.id});}
  async function request(identity,route,options={}){
    calls.push({identity:identity.id,route,options});
    const url=new URL(route,"https://fixture"),pathname=url.pathname,body=options.body?JSON.parse(options.body):{};
    const owner=url.searchParams.get("ownerId")||identity.id,zone=url.searchParams.get("timeZone")||"Asia/Shanghai";
    const reject=status=>{throw Object.assign(Error("rejected"),{status});};
    if(owner!==identity.id&&identity.role!=="admin")reject(403);
    if(pathname==="/work-logs"){
      if(url.searchParams.get("scope")==="all"){
        const page=Number(url.searchParams.get("page")),pageSize=Number(url.searchParams.get("pageSize"));
        const all=[...logs.values()].filter(item=>item.ownerId===owner&&!item.deleted).sort((a,b)=>b.date.localeCompare(a.date));
        return{scope:"all",ownerId:owner,today:"2026-11-14",timeZone:zone,readOnly:owner!==identity.id,
          owners:identity.role==="admin"?[{id:identity.id,name:identity.id,role:"admin"},{id:"bob",name:"Bob",role:"engineer"}]:[],
          page,pageSize,total:all.length,hasMore:page*pageSize<all.length,items:structuredClone(all.slice((page-1)*pageSize,page*pageSize))};
      }
      const month=url.searchParams.get("month");
      return{ownerId:owner,month,today:"2026-11-14",timeZone:zone,readOnly:owner!==identity.id,
        owners:identity.role==="admin"?[{id:identity.id,name:identity.id,role:"admin"},{id:"bob",name:"Bob",role:"engineer"}]:[],
        items:[...logs.values()].filter(item=>item.ownerId===owner&&!item.deleted&&item.date.startsWith(month+"-")).map(item=>structuredClone(item))};
    }
    const entry=pathname.match(/^\/work-logs\/(\d{4}-\d{2}-\d{2})(\/media)?$/);
    if(entry){
      const date=entry[1],key=owner+":"+date,previous=log(owner,date);
      if(!options.method)return detail(previous,identity,zone);
      if(owner!==identity.id)reject(403);
      if(body.version!==previous.version)reject(409);
      if(options.method==="DELETE"){
        if(!previous.version||previous.deleted)reject(404);
        logs.set(key,{ownerId:owner,date,text:"",media:[],version:previous.version+1,updatedAt:timestamp,deleted:true});
        for(const item of previous.media)media.delete(item.id);
        return{ok:true,ownerId:owner,date,version:previous.version+1,deleted:true};
      }
      let next;
      if(entry[2]){
        const bytes=Buffer.from(body.dataBase64,"base64"),id="media-"+(++serial);
        const metadata={id,name:body.name,mime:body.mime,size:bytes.length};
        media.set(id,{...metadata,ownerId:owner,date,dataBase64:body.dataBase64});
        next={...previous,media:[...previous.media,metadata],version:previous.version+1,updatedAt:timestamp};
      }else next={...previous,text:body.text,media:body.mediaIds.map(id=>previous.media.find(item=>item.id===id)),version:previous.version+1,updatedAt:timestamp};
      delete next.deleted;logs.set(key,next);return detail(next,identity,body.timeZone);
    }
    if(pathname.startsWith("/work-log-media/")){
      const value=media.get(pathname.split("/")[2]);if(!value)reject(404);
      if(value.ownerId!==identity.id&&identity.role!=="admin")reject(403);
      return structuredClone(value);
    }
    if(pathname==="/reminders"){
      if(!options.method)return{items:[...reminders.values()].filter(item=>item.ownerId===identity.id).map(item=>structuredClone(item)),serverNow:timestamp};
      const item={...body,id:"reminder-"+(++serial),ownerId:identity.id,status:"pending",version:1,createdAt:timestamp,updatedAt:timestamp};
      reminders.set(item.id,item);return structuredClone(item);
    }
    const parts=pathname.split("/"),previous=reminders.get(parts[2]);
    if(!previous||previous.ownerId!==identity.id)reject(404);
    if(parts[3]==="fire"){
      const claimed=previous.status==="pending"&&previous.version===body.version&&Date.parse(previous.dueAt)<=Date.parse(timestamp);
      if(claimed){previous.status="notified";previous.version++;previous.notifiedAt=timestamp;previous.updatedAt=timestamp;}
      return{claimed,reminder:structuredClone(previous)};
    }
    if(previous.version!==body.version)reject(409);
    if(options.method==="DELETE"){reminders.delete(previous.id);return{ok:true,id:previous.id,ownerId:identity.id};}
    const item={...previous,...body,version:previous.version+1,updatedAt:timestamp};
    if(body.dueAt!==previous.dueAt)item.status="pending";
    reminders.set(item.id,item);return structuredClone(item);
  }
  return{actor,logs,media,reminders,calls,request,log,detail,timestamp};
}

async function fixture({role="dispatcher",view="worklogs",mode="server",server=service(),override}={}){
  const b=browser();
  let context={actor:server.actor("alice",role),epoch:1,mode,connected:true,view,timeZone:"Asia/Shanghai"};
  const bridge={getContext:()=>context,request:(route,options)=>override?override(route,options,context,server):server.request(context.actor,route,options),
    navigate(next){context={...context,view:next};controller.sync();}};
  const controller=P.createController(bridge,b.env);
  controller.sync();await flush();
  return{...b,controller,server,getContext:()=>context,setContext(next){context={...context,...next};controller.sync();}};
}
function mediaFile(name,mime,bytes=Uint8Array.from([1,2,3])){
  const file=new Blob([bytes],{type:mime});Object.defineProperty(file,"name",{value:name});return file;
}
const reminder=(server,id="event-1")=>({id,ownerId:"alice",title:"私有事件",body:"不跨账号",dueAt:"2026-11-14T01:00:00Z",timeZone:"Asia/Shanghai",status:"pending",version:1,createdAt:server.timestamp,updatedAt:server.timestamp});

test("日历覆盖闰日、月末、跨月和本地时间往返，夏令时不存在的时刻不静默移动",()=>{
  assert.equal(P.validDate("2028-02-29"),true);assert.equal(P.validDate("2026-02-29"),false);
  const cells=P.monthCells("2026-11");assert.equal(cells.length,42);assert.equal(cells[0],"2026-10-26");assert.ok(cells.includes("2026-11-30"));
  assert.equal(P.shiftMonth("2026-12",1),"2027-01");assert.equal(P.shiftMonth("2026-01",-1),"2025-12");
  const value="2026-11-30T23:45";assert.equal(P.localInput(P.inputToISO(value)),value);
  const source=path.resolve(__dirname,"../../../../代码/前端/PC端/Web/维修工作台/personal.js");
  const result=spawnSync(process.execPath,["-e","const p=require(process.argv[1]);process.stdout.write(String(p.inputToISO('2026-03-08T02:30'))) ",source],{env:{...process.env,TZ:"America/New_York"},encoding:"utf8"});
  assert.equal(result.stdout,"null");
});

test("当前身份的正文按纯文本保存，失败保留内存草稿且不写浏览器持久缓存",async()=>{
  let fail=false;const h=await fixture({override:async(route,options,context,server)=>{
    if(fail&&options?.method==="PUT")throw Object.assign(Error("offline"),{status:0});
    return server.request(context.actor,route,options);
  }});
  await h.input("personalLogText","<script>private</script>");
  await h.controller.saveLog();
  assert.equal(h.server.logs.get("alice:2026-11-14").text,"<script>private</script>");
  assert.match(h.node("personalEditor").innerHTML,/&lt;script&gt;private/);
  fail=true;await h.input("personalLogText","只属于Alice的草稿");await h.controller.saveLog();
  assert.equal(h.controller.getState().context.mode,"server");assert.equal(h.controller.getState().draft.text,"只属于Alice的草稿");
  assert.equal(h.server.logs.get("alice:2026-11-14").text,"<script>private</script>");
  assert.match(h.controller.getState().logMessage,/尚未确认/);
  h.controller.destroy();
});

test("同账号网络epoch变化保留草稿，换号清理正文Blob并丢弃迟到结果",async()=>{
  const h=await fixture();await h.input("personalLogText","Alice private");
  await h.controller.addFiles([mediaFile("private.png","image/png")]);assert.equal(h.created.length,1);
  h.setContext({epoch:2,connected:false});assert.equal(h.controller.getState().draft.text,"Alice private");
  const pending=deferred(),server=h.server;
  const late=await fixture({server,override:async(route,options,context,s)=>{
    if(route.startsWith("/work-logs/2026-11-13"))return pending.promise;
    return s.request(context.actor,route,options);
  }});
  const job=late.controller.loadDay("2026-11-13");
  late.setContext({actor:server.actor("bob"),epoch:3});await flush();
  pending.resolve(server.detail({...server.log("alice","2026-11-13"),text:"old Alice result"},server.actor(),"Asia/Shanghai"));await job;await flush();
  assert.equal(late.controller.getState().context.actor.id,"bob");assert.doesNotMatch(late.node("worklogsView").innerHTML,/old Alice result/);
  h.setContext({actor:server.actor("bob"),epoch:3});await flush();
  assert.ok(h.revoked.includes(h.created[0].url));assert.notEqual(h.controller.getState().draft.text,"Alice private");
  h.controller.destroy();late.controller.destroy();
});

test("日与月请求独立排序，旧日期迟到不能覆盖新选择或丢失日期草稿",async()=>{
  const pending=new Map();
  const h=await fixture({override:async(route,options,context,server)=>{
    const day=route.match(/^\/work-logs\/(2026-11-1[23])/);
    if(day){const wait=deferred();pending.set(day[1],wait);return wait.promise;}
    return server.request(context.actor,route,options);
  }});
  const first=h.controller.loadDay("2026-11-12"),second=h.controller.loadDay("2026-11-13");
  pending.get("2026-11-13").resolve(h.server.detail({...h.server.log("alice","2026-11-13"),text:"newer day"},h.getContext().actor,"Asia/Shanghai"));await second;
  pending.get("2026-11-12").resolve(h.server.detail({...h.server.log("alice","2026-11-12"),text:"older day"},h.getContext().actor,"Asia/Shanghai"));await first;
  assert.equal(h.controller.getState().selected,"2026-11-13");assert.equal(h.controller.getState().draft.text,"newer day");
  await h.input("personalLogText","keep this date");
  await h.controller.loadDay("2026-11-14");const returning=h.controller.loadDay("2026-11-13");
  assert.equal(h.controller.getState().draft.text,"keep this date");
  pending.get("2026-11-13").resolve(h.server.detail({...h.server.log("alice","2026-11-13"),text:"newer day"},h.getContext().actor,"Asia/Shanghai"));await returning;
  h.controller.destroy();
});

test("剪贴板图片和本地视频共用上传校验，上传返回旧正文不覆盖编辑稿",async()=>{
  const h=await fixture();
  const image=mediaFile("paste.png","image/png"),video=mediaFile("clip.mp4","video/mp4",Uint8Array.from([4,5,6,7]));
  const pasted=await h.emit("paste",{}, {clipboardData:{items:[{kind:"file",type:"image/png",getAsFile:()=>image}]}});
  assert.equal(pasted.prevented,true);await h.controller.addFiles([video]);
  await h.input("personalLogText","尚未保存的图文备忘");await h.controller.saveLog();
  const stored=h.server.logs.get("alice:2026-11-14");assert.equal(stored.text,"尚未保存的图文备忘");assert.equal(stored.media.length,2);
  assert.equal(h.server.calls.filter(call=>call.route.includes("/media?")).length,2);
  assert.equal(h.controller.getState().draft.dirty,false);
  await h.controller.addFiles([mediaFile("unsafe.svg","image/svg+xml")]);
  assert.match(h.controller.getState().logMessage,/无法识别/);
  h.controller.destroy();
});

test("管理员查看他人日志只读且附件仍按owner/date核验",async()=>{
  const server=service();server.logs.set("bob:2026-11-14",{ownerId:"bob",date:"2026-11-14",text:"Bob only",media:[],version:1,updatedAt:server.timestamp});
  const h=await fixture({role:"admin",server});
  await h.emit("change",{id:"personalOwner",value:"bob"});assert.equal(h.controller.getState().readOnly,true);
  assert.match(h.node("personalEditor").innerHTML,/ readonly/);assert.equal(h.controller.getState().draft.text,"Bob only");
  const before=server.calls.length;await h.controller.saveLog();await h.controller.addFiles([mediaFile("x.png","image/png")]);
  assert.equal(server.calls.length,before);assert.equal(server.logs.get("bob:2026-11-14").text,"Bob only");
  h.controller.destroy();
});

test("管理员只读他人后换普通账户，归属栏立即清除只读提示并恢复本人编辑",async()=>{
  const h=await fixture({role:"admin"});
  await h.emit("change",{id:"personalOwner",value:"bob"});
  assert.equal(h.controller.getState().readOnly,true);
  assert.match(h.node("worklogsView").innerHTML,/只读查看/);
  h.setContext({actor:h.server.actor("dispatcher","dispatcher"),epoch:2});
  await flush();
  assert.equal(h.controller.getState().targetOwner,"dispatcher");
  assert.equal(h.controller.getState().readOnly,false);
  assert.doesNotMatch(h.node("worklogsView").innerHTML,/只读查看/);
  assert.doesNotMatch(h.node("personalEditor").innerHTML,/ readonly/);
  assert.doesNotMatch(h.node("personalEditor").innerHTML,/data-personal="save-log" disabled/);
  h.controller.destroy();
});

test("保存结果未知时不重发，重新读取确认已提交结果后才显示成功",async()=>{
  let lose=true;
  const h=await fixture({override:async(route,options,context,server)=>{
    const value=await server.request(context.actor,route,options);
    if(lose&&options?.method==="PUT"&&route.startsWith("/work-logs/"))throw Object.assign(Error("lost response"),{status:0});
    return value;
  }});
  await h.input("personalLogText","committed but response lost");await h.controller.saveLog();
  const before=h.server.calls.filter(call=>call.options?.method==="PUT").length;
  await h.controller.saveLog();assert.equal(h.server.calls.filter(call=>call.options?.method==="PUT").length,before);
  lose=false;await h.controller.loadDay();assert.equal(h.controller.getState().draft.dirty,false);assert.equal(h.controller.getState().logMessage,"日志已保存");
  h.controller.destroy();
});

test("双标签同版本到期提醒只允许一处tips且不抢焦点，关闭不完成待办",async()=>{
  const server=service();server.reminders.set("event-1",reminder(server));
  const first=await fixture({server,view:"tasks"}),second=await fixture({server,view:"tasks"});
  await Promise.all([first.controller.pollReminders(),second.controller.pollReminders()]);await flush();
  assert.equal(first.controller.getState().notices.length+second.controller.getState().notices.length,1);
  assert.equal(first.getFocuses()+second.getFocuses(),0);
  const shown=first.controller.getState().notices.length?first:second;
  await shown.click({personal:"close-tip",reminder:"event-1"});assert.equal(shown.controller.getState().notices.length,0);
  assert.equal(server.reminders.get("event-1").status,"notified");
  await shown.controller.pollReminders();assert.equal(shown.controller.getState().notices.length,0);
  first.controller.destroy();second.controller.destroy();
});

test("隐藏页面暂停到期检查，恢复可见补检；取消与完成均停止旧提醒",async()=>{
  const h=await fixture({view:"tasks"});h.doc.visibilityState="hidden";
  h.server.reminders.set("event-1",reminder(h.server));
  const before=h.server.calls.length;await h.controller.pollReminders();assert.equal(h.server.calls.length,before);
  h.doc.visibilityState="visible";await h.emit("visibilitychange");assert.equal(h.controller.getState().notices.length,1);
  await h.controller.completeReminder("event-1");assert.equal(h.server.reminders.get("event-1").status,"done");assert.equal(h.controller.getState().notices.length,0);
  const event=reminder(h.server,"event-2");h.server.reminders.set(event.id,event);await h.controller.loadReminders();await h.controller.cancelReminder(event.id);
  assert.equal(h.server.reminders.has(event.id),false);await h.controller.pollReminders();assert.equal(h.controller.getState().notices.length,0);
  h.controller.destroy();
});

test("私有响应拒绝错账户、重复媒体、坏时间与非法类型，不能把错误2xx当成功",()=>{
  const actor={id:"alice",role:"dispatcher"},server=service();
  const item=reminder(server);
  assert.equal(P.validateResponse("/reminders",{}, {items:[item],serverNow:server.timestamp},actor),true);
  assert.equal(P.validateResponse("/reminders",{}, {items:[{...item,ownerId:"bob"}],serverNow:server.timestamp},actor),false);
  assert.equal(P.validateResponse("/work-logs/2026-11-14?timeZone=Asia%2FShanghai",{},server.detail(server.log("bob","2026-11-14"),actor,"Asia/Shanghai"),actor),false);
  assert.equal(P.validMedia({id:"x",name:"x.svg",mime:"image/svg+xml",size:100}),false);
  assert.equal(P.validReminder({...item,dueAt:"bad"},actor.id),false);
});

test("旧日期保存成功不冒充当前草稿成功，保存结束恢复当前日期控件", async()=>{
  const pause=deferred();let committed;
  const h=await fixture({override:async(route,options,context,server)=>{
    if(options?.method==="PUT"&&route.startsWith("/work-logs/2026-11-14")){
      committed=await server.request(context.actor,route,options);return pause.promise;
    }
    return server.request(context.actor,route,options);
  }});
  await h.input("personalLogText","old-date-saved");const saving=h.controller.saveLog();await flush();
  await h.controller.loadDay("2026-11-15");await h.input("personalLogText","new-date-draft");
  pause.resolve(committed);await saving;
  assert.equal(h.controller.getState().selected,"2026-11-15");assert.equal(h.controller.getState().draft.text,"new-date-draft");
  assert.equal(h.controller.getState().draft.dirty,true);assert.notEqual(h.controller.getState().logMessage,"日志已保存");
  assert.doesNotMatch(h.node("personalEditor").innerHTML,/data-personal="save-log" disabled/);
  h.controller.destroy();
});

test("同日旧GET迟到不能把已确认保存的正文版本从v2降回v1",async()=>{
  const server=service();server.logs.set("alice:2026-11-14",{ownerId:"alice",date:"2026-11-14",text:"before",media:[],version:1,updatedAt:server.timestamp});
  const pause=deferred();let hold=false,old;
  const h=await fixture({server,override:async(route,options,context,s)=>{
    const result=await s.request(context.actor,route,options);
    if(hold&&!options?.method&&route.startsWith("/work-logs/2026-11-14")){old=result;return pause.promise;}
    return result;
  }});
  hold=true;const reading=h.controller.loadDay();await flush();
  await h.input("personalLogText","saved-new");await h.controller.saveLog();
  assert.equal(h.controller.getState().draft.version,2);
  pause.resolve(old);await reading;
  assert.equal(h.controller.getState().draft.text,"saved-new");assert.equal(h.controller.getState().draft.version,2);
  h.controller.destroy();
});

test("提醒A保存迟到不把正在编辑的B草稿改绑A，同账号epoch变化不永久卡busy",async()=>{
  const server=service();for(const id of ["A","B"])server.reminders.set(id,{...reminder(server,id),title:id,dueAt:"2026-12-01T01:00:00Z"});
  const pause=deferred();let saved;
  const h=await fixture({server,view:"tasks",override:async(route,options,context,s)=>{
    const result=await s.request(context.actor,route,options);
    if(route==="/reminders/A"&&options?.method==="PUT"){saved=result;return pause.promise;}
    return result;
  }});
  await h.click({personal:"edit-reminder",reminder:"A"});await h.input("personalReminderTitle","A changed");
  const sending=h.controller.saveReminder();await flush();
  await h.click({personal:"edit-reminder",reminder:"B"});
  pause.resolve(saved);await sending;
  assert.equal(h.controller.getState().reminderDraft.id,"B");assert.equal(h.controller.getState().reminderDraft.title,"B");
  h.setContext({epoch:2,connected:false});
  await h.input("personalReminderTitle","B changed");await h.controller.saveReminder();
  assert.equal(server.reminders.get("B").title,"B changed");
  h.controller.destroy();
});

test("fire迟到响应不能复活已取消提醒或弹出取消后的tips",async()=>{
  const server=service();server.reminders.set("event-1",reminder(server));
  const pause=deferred();let claimed;
  const h=await fixture({server,view:"tasks",override:async(route,options,context,s)=>{
    const result=await s.request(context.actor,route,options);
    if(route.endsWith("/fire")){claimed=result;return pause.promise;}
    return result;
  }});
  await h.controller.loadReminders();await h.controller.cancelReminder("event-1");
  assert.equal(server.reminders.has("event-1"),false);
  if(claimed)pause.resolve(claimed);await flush();
  assert.equal(h.controller.getState().reminders.length,0);assert.equal(h.controller.getState().notices.length,0);
  h.controller.destroy();
});

test("迟到pending列表不能覆盖本端已确认的完成高版本",async()=>{
  const server=service();server.reminders.set("future",{...reminder(server,"future"),dueAt:"2026-12-01T01:00:00Z"});
  const pause=deferred();let hold=false,old;
  const h=await fixture({server,view:"tasks",override:async(route,options,context,s)=>{
    const result=await s.request(context.actor,route,options);
    if(hold&&route==="/reminders"&&!options?.method){old=result;return pause.promise;}
    return result;
  }});
  hold=true;const reading=h.controller.pollReminders();await flush();
  await h.controller.completeReminder("future");pause.resolve(old);await reading;
  assert.equal(h.controller.getState().reminders[0].status,"done");assert.equal(h.controller.getState().reminders[0].version,2);
  h.controller.destroy();
});

test("提醒POST结果未知时阻止新正文重提，读到原记录后改稿沿用同一事件",async()=>{
  let lose=true;
  const h=await fixture({view:"tasks",override:async(route,options,context,server)=>{
    const result=await server.request(context.actor,route,options);
    if(lose&&route==="/reminders"&&options?.method==="POST")throw Object.assign(Error("lost response"),{status:0});
    return result;
  }});
  await h.input("personalReminderTitle","original event");await h.input("personalReminderDue","2026-12-01T08:30");
  await h.controller.saveReminder();assert.match(h.controller.getState().reminderMessage,/尚未确认/);
  await h.input("personalReminderTitle","changed while unknown");await h.controller.saveReminder();
  assert.equal(h.server.calls.filter(call=>call.route==="/reminders"&&call.options?.method==="POST").length,1);
  lose=false;await h.controller.loadReminders();
  assert.ok(h.controller.getState().reminderDraft.id);assert.equal(h.controller.getState().reminderDraft.title,"changed while unknown");
  await h.controller.saveReminder();
  assert.equal(h.server.reminders.size,1);assert.equal([...h.server.reminders.values()][0].title,"changed while unknown");
  h.controller.destroy();
});

test("原提醒未落盘时仅显式重试同一路径同一请求体，不自动生成新意图",async()=>{
  let rejectFirst=true;const attempts=[];
  const h=await fixture({view:"tasks",override:async(route,options,context,server)=>{
    if(route==="/reminders"&&options?.method==="POST"){
      attempts.push(options.body);
      if(rejectFirst){rejectFirst=false;throw Object.assign(Error("offline"),{status:0});}
    }
    return server.request(context.actor,route,options);
  }});
  await h.input("personalReminderTitle","original");await h.input("personalReminderDue","2026-12-01T08:30");await h.controller.saveReminder();
  await h.input("personalReminderTitle","new draft");await h.controller.saveReminder();assert.equal(attempts.length,1);
  await h.controller.retryUnknownReminder();
  assert.equal(attempts.length,2);assert.equal(attempts[0],attempts[1]);
  assert.equal(h.server.reminders.size,1);assert.equal(h.controller.getState().reminderDraft.title,"new draft");
  h.controller.destroy();
});

test("语言变更只更新日历和展示时间，不重建正文输入或改变焦点",async()=>{
  const h=await fixture();await h.input("personalLogText","业务原文 never translate");
  const input=h.node("personalLogText");input.focus();const before=h.getFocuses();
  h.doc.documentElement.lang="de-DE";await h.emit("repair-locale-change");
  assert.equal(h.node("personalLogText"),input);assert.equal(h.doc.activeElement,input);assert.equal(h.getFocuses(),before);
  assert.equal(h.controller.getState().draft.text,"业务原文 never translate");
  h.controller.destroy();
});

test("只修改提醒标题保留原时刻秒精度与原时区，不把分钟显示回写成新时间",async()=>{
  const server=service(),item={...reminder(server,"precise"),dueAt:"2026-12-01T01:00:30.123Z",timeZone:"Europe/Paris"};
  server.reminders.set(item.id,item);
  const h=await fixture({server,view:"tasks"});
  await h.click({personal:"edit-reminder",reminder:item.id});await h.input("personalReminderTitle","title only");
  await h.controller.saveReminder();
  assert.equal(server.reminders.get(item.id).dueAt,item.dueAt);
  assert.equal(server.reminders.get(item.id).timeZone,item.timeZone);
  h.controller.destroy();
});

test("同账号在保存中切epoch后可核对原意图并继续创建下一提醒，不被旧busy永久锁住",async()=>{
  const server=service();server.reminders.set("A",{...reminder(server,"A"),dueAt:"2026-12-01T01:00:00Z"});
  const pause=deferred();let saved;
  const h=await fixture({server,view:"tasks",override:async(route,options,context,s)=>{
    const result=await s.request(context.actor,route,options);
    if(route==="/reminders/A"&&options?.method==="PUT"){saved=result;return pause.promise;}
    return result;
  }});
  await h.click({personal:"edit-reminder",reminder:"A"});await h.input("personalReminderTitle","A changed");
  const sending=h.controller.saveReminder();await flush();
  h.setContext({epoch:2,connected:false});await flush();
  assert.equal(h.controller.getState().reminderSaving,false);
  await h.input("personalReminderTitle","new after epoch");await h.input("personalReminderDue","2026-12-02T08:30");
  await h.controller.saveReminder();pause.resolve(saved);await sending;
  assert.equal([...server.reminders.values()].some(item=>item.title==="new after epoch"),true);
  assert.equal(h.controller.getState().reminderSaving,false);
  h.controller.destroy();
});

test("提醒时间面板确认只回填草稿，取消和Escape不改值，保存提醒才提交",async()=>{
  const h=await fixture({view:"tasks"});
  await h.input("personalReminderTitle","确认后再提交");
  await h.input("personalReminderBody","保留正文");
  const writes=()=>h.server.calls.filter(call=>call.options.method).length;
  const count=writes();
  await h.click({personal:"open-reminder-time"});
  assert.equal(h.node("personalReminderTimeDialog").open,true);
  assert.match(h.node("personalReminderTimeDialog").innerHTML,/确认时间/);
  h.node("personalReminderTimeHour").value="15";h.node("personalReminderTimeMinute").value="42";
  await h.click({personal:"reminder-time-date",timeDate:"2026-12-03"});
  assert.equal(h.node("personalReminderDue").value,"");
  await h.click({personal:"cancel-reminder-time"});
  assert.equal(h.controller.getState().reminderDraft.due,"");
  assert.equal(h.doc.activeElement.id,"personalReminderTimeTrigger");
  await h.click({personal:"open-reminder-time"});
  await h.emit("keydown",{dataset:{}},{key:"Escape"});
  assert.equal(h.node("personalReminderTimeDialog").open,false);
  assert.equal(h.doc.activeElement.id,"personalReminderTimeTrigger");
  await h.click({personal:"open-reminder-time"});
  h.node("personalReminderTimeHour").value="15";h.node("personalReminderTimeMinute").value="42";
  await h.click({personal:"reminder-time-date",timeDate:"2026-12-03"});
  await h.click({personal:"confirm-reminder-time"});
  assert.equal(h.controller.getState().reminderDraft.due,"2026-12-03T15:42");
  assert.equal(h.node("personalReminderDue").value,"2026-12-03T15:42");
  assert.equal(h.controller.getState().reminderDraft.title,"确认后再提交");
  assert.equal(h.controller.getState().reminderDraft.body,"保留正文");
  assert.equal(writes(),count);
  await h.controller.saveReminder();
  const saved=[...h.server.reminders.values()][0];
  assert.equal(saved.title,"确认后再提交");assert.equal(P.localInput(saved.dueAt),"2026-12-03T15:42");
  h.controller.destroy();
});

test("提醒时间日期可键盘跨月，换号关闭面板且不向新身份回填或抢焦点",async()=>{
  const h=await fixture({view:"tasks"});
  await h.click({personal:"open-reminder-time"});
  await h.emit("keydown",{dataset:{timeDate:"2026-11-30"}},{key:"ArrowRight"});
  assert.match(h.node("personalReminderTimeDialog").innerHTML,/data-time-date="2026-12-01"[^>]*aria-pressed="true"/);
  await h.click({personal:"reminder-time-next"});assert.equal(h.doc.activeElement.id,"personalReminderTimeNext");
  const focuses=h.getFocuses();
  h.setContext({actor:h.server.actor("bob"),epoch:2});await flush();
  assert.equal(h.controller.getState().reminderDraft.due,"");
  assert.equal(h.getFocuses(),focuses);
  await h.click({personal:"confirm-reminder-time"});
  assert.equal(h.controller.getState().reminderDraft.due,"");
  h.controller.destroy();
});

test("今日新草稿显示稳定时分秒，历史空日不借用当前时刻，已有日志显示真实保存时间",async()=>{
  const h=await fixture();
  const header=h.node("personalEditor").innerHTML;
  assert.match(header,/<h2[^>]*>[^<]*\d{2}:\d{2}:\d{2}<\/h2>/);
  assert.match(header,/当前编辑时刻/);
  const started=h.controller.getState().draft.startedAt;
  h.env.now=()=>Date.parse("2026-11-14T02:35:50Z");
  await h.controller.loadDay();
  assert.equal(h.controller.getState().draft.startedAt,started);
  await h.controller.loadDay("2026-11-13");
  assert.doesNotMatch(h.node("personalEditor").innerHTML,/当前编辑时刻|最近保存/);
  h.server.logs.set("alice:2026-11-12",{ownerId:"alice",date:"2026-11-12",text:"已保存",media:[],version:1,updatedAt:"2026-11-13T04:05:06Z"});
  await h.controller.loadDay("2026-11-12");
  assert.match(h.node("personalEditor").innerHTML,/最近保存/);
  assert.match(h.node("personalEditor").innerHTML,/datetime="2026-11-13T04:05:06Z"/);
  assert.match(h.node("personalEditor").innerHTML,/\d{2}:\d{2}:06/);
  assert.doesNotMatch(h.node("personalEditor").innerHTML,/当前编辑时刻/);
  h.controller.destroy();
});

test("全部日志跨月按日期分页，详情切换既有编辑器且摘要按纯文本呈现",async()=>{
  const server=service();
  for(const month of ["10","11"])for(let day=1;day<=12;day++){
    const date="2026-"+month+"-"+String(day).padStart(2,"0");
    server.logs.set("alice:"+date,{ownerId:"alice",date,text:"<img onerror=alert(1)> "+date,media:[],version:1,updatedAt:server.timestamp});
  }
  const h=await fixture({server});
  assert.equal(h.controller.getState().historyTotal,24);assert.equal(h.controller.getState().historyItems.length,20);
  assert.equal(h.controller.getState().historyItems[0].date,"2026-11-12");
  assert.match(h.node("personalLogHistory").innerHTML,/&lt;img onerror/);
  await h.click({personal:"history-next"});assert.equal(h.controller.getState().historyPage,2);assert.equal(h.controller.getState().historyItems.length,4);
  const date=h.controller.getState().historyItems[0].date;
  await h.click({personal:"open-log",logDate:date});assert.equal(h.controller.getState().selected,date);assert.equal(h.controller.getState().month,"2026-10");
  assert.equal(h.node("personalLogText").value,"<img onerror=alert(1)> "+date);
  await h.click({personal:"history-previous"});assert.equal(h.controller.getState().historyPage,1);
  h.controller.destroy();
});

test("管理员他人全部日志只读，不显示删除且伪造删除点击不发请求",async()=>{
  const server=service();server.logs.set("bob:2026-10-01",{ownerId:"bob",date:"2026-10-01",text:"他人日志",media:[],version:2,updatedAt:server.timestamp});
  const h=await fixture({server,role:"admin"});await h.emit("change",{id:"personalOwner",value:"bob"});
  assert.equal(h.controller.getState().historyItems.length,1);assert.equal(h.controller.getState().readOnly,true);
  assert.doesNotMatch(h.node("personalLogHistory").innerHTML,/data-personal="delete-log"/);
  await h.click({personal:"delete-log",logDate:"2026-10-01"});await h.click({personal:"confirm-delete-log"});
  assert.equal(server.calls.filter(call=>call.options.method==="DELETE").length,0);
  h.controller.destroy();
});

test("删除先确认，冲突保留日志，成功清日历列表媒体并以墓碑版本重建",async()=>{
  const server=service(),date="2026-11-14",metadata={id:"private-media",name:"private.png",mime:"image/png",size:3};
  server.logs.set("alice:"+date,{ownerId:"alice",date,text:"已存内容",media:[metadata],version:1,updatedAt:server.timestamp});
  server.media.set(metadata.id,{...metadata,ownerId:"alice",date,dataBase64:"AQID"});
  let conflict=true;
  const h=await fixture({server,override:(route,options,context,s)=>{
    if(options?.method==="DELETE"&&conflict)throw Object.assign(Error("version conflict"),{status:409});
    return s.request(context.actor,route,options);
  }});
  await h.controller.previewMedia(0);assert.equal(h.created.length,1);
  await h.input("personalLogText","未保存内容");
  await h.click({personal:"delete-log",logDate:date});assert.equal(h.node("personalLogDeleteDialog").open,true);
  await h.click({personal:"cancel-delete-log"});assert.equal(h.controller.getState().draft.text,"未保存内容");
  assert.equal(server.calls.filter(call=>call.options.method==="DELETE").length,0);
  await h.click({personal:"delete-log",logDate:date});await h.click({personal:"confirm-delete-log"});
  assert.match(h.node("personalLogDeleteError").textContent,/日志已更新/);assert.equal(h.controller.getState().historyItems.length,1);
  assert.equal(server.logs.get("alice:"+date).deleted,undefined);
  conflict=false;await h.click({personal:"cancel-delete-log"});await h.click({personal:"delete-log",logDate:date});await h.click({personal:"confirm-delete-log"});
  assert.equal(server.logs.get("alice:"+date).deleted,true);assert.equal(h.controller.getState().historyItems.length,0);
  assert.equal(h.controller.getState().draft.text,"");assert.equal(h.controller.getState().draft.version,2);
  assert.equal(h.doc.activeElement.id,"personalLogDateHeading");
  assert.ok(h.revoked.includes(h.created[0].url));assert.doesNotMatch(h.node("personalCalendar").innerHTML,/has-entry/);
  await h.input("personalLogText","重建");await h.controller.saveLog();await flush();
  assert.equal(server.logs.get("alice:"+date).version,3);assert.equal(server.logs.get("alice:"+date).deleted,undefined);
  assert.equal(h.controller.getState().historyItems.length,1);
  h.controller.destroy();
});

test("全部日志迟到响应与删除迟到结果不能覆盖切换后的账户",async()=>{
  const server=service(),pause=deferred();let delayed=true;
  server.logs.set("alice:2026-11-14",{ownerId:"alice",date:"2026-11-14",text:"Alice private",media:[],version:1,updatedAt:server.timestamp});
  const h=await fixture({server,override:async(route,options,context,s)=>{
    const value=await s.request(context.actor,route,options);
    if(delayed&&route.includes("scope=all")&&context.actor.id==="alice"){delayed=false;await pause.promise;}
    return value;
  }});
  h.setContext({actor:server.actor("bob"),epoch:2});await flush();pause.resolve();await flush();
  assert.equal(h.controller.getState().historyItems.length,0);assert.doesNotMatch(h.node("personalLogHistory").innerHTML,/Alice private/);
  h.controller.destroy();
  const pending=deferred();let deleting=false;
  const second=await fixture({server,override:async(route,options,context,s)=>{
    const value=await s.request(context.actor,route,options);
    if(options?.method==="DELETE"){deleting=true;await pending.promise;}
    return value;
  }});
  await second.click({personal:"delete-log",logDate:"2026-11-14"});
  const operation=second.controller.deleteLog();await flush();assert.equal(deleting,true);
  second.setContext({actor:server.actor("bob"),epoch:2});await flush();pending.resolve();await operation;await flush();
  assert.equal(second.controller.getState().context.actor.id,"bob");assert.equal(second.controller.getState().draft.text,"");
  assert.equal(second.controller.getState().historyItems.length,0);assert.equal(second.controller.getState().deleting,false);
  second.controller.destroy();
});

test("全部日志与删除响应校验拒绝越权owner、坏分页及未确认删除结果",async()=>{
  const server=service(),actor=server.actor(),route="/work-logs?scope=all&page=1&pageSize=20&timeZone=Asia%2FShanghai";
  const value=await server.request(actor,route);
  assert.equal(P.validateResponse(route,{},value,actor),true);
  assert.equal(P.validateResponse(route,{}, {...value,ownerId:"bob"},actor),false);
  assert.equal(P.validateResponse(route,{}, {...value,page:2},actor),false);
  const removed={ok:true,ownerId:"alice",date:"2026-11-14",version:2,deleted:true};
  assert.equal(P.validateResponse("/work-logs/2026-11-14",{method:"DELETE"},removed,actor),true);
  assert.equal(P.validateResponse("/work-logs/2026-11-14",{method:"DELETE"},{...removed,deleted:false},actor),false);
});

test("删除后迟到的媒体读取不能重新创建已移除附件的Blob",async()=>{
  const server=service(),pause=deferred(),date="2026-11-14",item={id:"deleted-media",name:"private.png",mime:"image/png",size:3};
  server.logs.set("alice:"+date,{ownerId:"alice",date,text:"删除测试",media:[item],version:1,updatedAt:server.timestamp});
  server.media.set(item.id,{...item,ownerId:"alice",date,dataBase64:"AQID"});
  const h=await fixture({server,override:async(route,options,context,s)=>{
    const value=await s.request(context.actor,route,options);if(route.startsWith("/work-log-media/"))await pause.promise;return value;
  }});
  const loading=h.controller.previewMedia(0);await flush();
  await h.click({personal:"delete-log",logDate:date});await h.click({personal:"confirm-delete-log"});
  pause.resolve();await loading;await flush();
  assert.equal(h.created.length,0);assert.equal(h.controller.getState().draft.media.length,0);
  h.controller.destroy();
});


test("另一标签重建的高版本日志可重新出现在本地墓碑的月历中",async()=>{
  const server=service(),date="2026-11-14";
  server.logs.set("alice:"+date,{ownerId:"alice",date,text:"原日志",media:[],version:1,updatedAt:server.timestamp});
  const h=await fixture({server});await h.click({personal:"delete-log",logDate:date});await h.click({personal:"confirm-delete-log"});
  assert.equal(h.controller.getState().draft.version,2);
  server.logs.set("alice:"+date,{ownerId:"alice",date,text:"另一标签重建",media:[],version:3,updatedAt:server.timestamp});
  await h.controller.loadMonth();await h.controller.loadLogHistory();
  assert.match(h.node("personalCalendar").innerHTML,/has-entry/);assert.equal(h.controller.getState().historyItems[0].version,3);
  h.controller.destroy();
});

test("日志下一页读取失败保留当前页及其范围，不把旧内容标成新页",async()=>{
  const server=service();for(let day=1;day<=25;day++){
    const date="2026-10-"+String(day).padStart(2,"0");server.logs.set("alice:"+date,{ownerId:"alice",date,text:date,media:[],version:1,updatedAt:server.timestamp});
  }
  const h=await fixture({server,override:(route,options,context,s)=>{
    if(route.includes("scope=all&page=2"))throw Object.assign(Error("offline"),{status:0});return s.request(context.actor,route,options);
  }});
  const previous=h.controller.getState().historyItems[0].date;await h.click({personal:"history-next"});
  assert.equal(h.controller.getState().historyPage,1);assert.equal(h.controller.getState().historyItems[0].date,previous);
  assert.match(h.node("personalLogHistory").innerHTML,/1–20 \/ 25/);assert.equal(h.controller.getState().historyMessage,"日志列表加载失败，请重试。");
  h.controller.destroy();
});
