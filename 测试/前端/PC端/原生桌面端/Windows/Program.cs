using RepairDesktop;
using System.Text.Json.Nodes;
static void Check(bool condition, string reason) { if (!condition) throw new Exception(reason); }
if(args.Length>0&&args[0]=="--password-only")
{
    await PasswordPolicySmoke.Run();
    return;
}
if(args.Length>0&&args[0]=="--stream-only")
{
    await StreamingSmoke.Live(args[1],args[2],args[3]);
    return;
}
if(args.Length>0)
{
var client = new WorkbenchClient();
client.Configure(args[0], 2.5);
await client.Login("admin", "1234");
Check(!client.IsDemo && WorkbenchClient.S(client.Actor, "role") == "admin", "real login");
Check(client.Orders.Count > 0, "bootstrap");
var full = await client.Detail(WorkbenchClient.S(client.Orders[0], "id"));
Check(!WorkbenchClient.B(full, "isSummary"), "full detail");
await client.Search("控制");
await client.Search("");
var created = await client.Create(new JsonObject { ["type"]="mail",["customer"]=WorkbenchClient.S(full,"customer"),["customerId"]=WorkbenchClient.S(full,"customerId"),["companyId"]=WorkbenchClient.S(full,"companyId"),["project"]="原生桌面验收",["device"]="Windows原生合成验收设备",["description"]="本地隔离服务：客户端真实传输合同验收" });
Check(!WorkbenchClient.S(created,"id").StartsWith("ios-demo-"), "real creation");
var changed = await client.Perform(created, "remark", new JsonObject { ["remark"]="Windows原生真实HTTP验收" });
Check(WorkbenchClient.I(changed,"version")>WorkbenchClient.I(created,"version"), "version advance");
try { await client.Login("admin", "invalid-password"); throw new Exception("invalid password accepted"); } catch (ApiException e) { Check(e.Status == 401 && client.Actor == null, "401 must revoke"); }
client.Configure("http://127.0.0.1:1",0.5);
await client.Login("admin", "1234");
Check(client.IsDemo && WorkbenchClient.S(client.Actor,"id").StartsWith("ios-demo-"),"synthetic fallback");
Console.WriteLine("PASS: Windows client HTTP login/detail/search/create/action/version/401 isolation/offline synthetic fallback (macOS CLI; WPF runtime untested)");
}
if(args.Length>1)
{
    var live=new WorkbenchClient();live.Configure(args[0],5);await live.Login("admin","1234");
    string suffix=Guid.NewGuid().ToString("N")[..10],liveEmail="native_"+suffix+"@example.test",name="native_"+suffix,password="Native-live-2026!";
    var delivery=await live.Authentication("/auth/email-code",new(){["email"]=liveEmail,["purpose"]="register"});
    Check(WorkbenchClient.S(delivery,"demoCode").Length==6,"real local code delivery");
    await live.Authentication("/register",new(){["email"]=liveEmail,["username"]=name,["name"]="Windows原生认证验收",["code"]=WorkbenchClient.S(delivery,"demoCode"),["password"]=password,["confirmPassword"]=password});
    Check(WorkbenchClient.S(live.Actor,"role")=="admin","register must not silently replace session");
    await live.Login(liveEmail,password);Check(!live.IsDemo&&WorkbenchClient.S(live.Actor,"username")==name,"real register liveEmail login");
    var liveReset=await live.Authentication("/auth/email-code",new(){["email"]=liveEmail,["purpose"]="reset_password"});
    await live.Authentication("/reset-password",new(){["email"]=liveEmail,["code"]=WorkbenchClient.S(liveReset,"demoCode"),["password"]="Changed-live-2026!",["confirmPassword"]="Changed-live-2026!"});
    await live.Login(liveEmail,"Changed-live-2026!");Check(!live.IsDemo,"real liveReset liveEmail login");
    await live.Login("admin","1234");await live.LoadCustomerDirectory();
    var directory=await live.CreateDirectoryEntry(new(){["operation"]="customer",["name"]="Windows原生合成客户",["companyName"]="原生合成企业一",["username"]="buyer_"+suffix,["password"]=password,["confirmPassword"]=password});
    string customerId=WorkbenchClient.S(directory,"customerId");Check(customerId.Length>0&&WorkbenchClient.S(directory,"accountId").Length>0,"controlled customer directory creation");
    var company=await live.CreateDirectoryEntry(new(){["operation"]="company",["customerId"]=customerId,["name"]="原生合成企业二"});
    string companyId=WorkbenchClient.S(company,"companyId");
    var account=await live.CreateDirectoryEntry(new(){["operation"]="account",["customerId"]=customerId,["companyId"]=companyId,["username"]="buyer2_"+suffix,["name"]="原生第二经办人",["password"]=password,["confirmPassword"]=password});
    string accountId=WorkbenchClient.S(account,"accountId");Check(accountId.Length>0&&companyId.Length>0,"controlled second company/account");
    byte[] picture=File.ReadAllBytes(args[1]),video=File.ReadAllBytes(args[2]);
    var order=await live.Create(new(){["type"]="mail",["customer"]="Windows原生合成客户",["customerId"]=accountId,["companyId"]=companyId,["project"]="原生隔离验收",["device"]="Windows原生附图设备",["description"]="合成图片和视频，客户端真实HTTP合同验收",["files"]=new JsonArray(new JsonObject{["name"]="device.png",["mime"]="image/png",["dataBase64"]=Convert.ToBase64String(picture)},new JsonObject{["name"]="device.mp4",["mime"]="video/mp4",["dataBase64"]=Convert.ToBase64String(video)})});
    Check(order["evidence"]!.AsArray().Count==2,"atomic initial order media");
    foreach(var file in order["evidence"]!.AsArray())
    {
        using var liveOriginalFile=await live.EvidenceFileToTemporary(WorkbenchClient.S(order,"id"),file!.AsObject());
        var bytes=File.ReadAllBytes(liveOriginalFile.Path);
        Check(bytes.SequenceEqual(WorkbenchClient.S(file,"kind")=="image"?picture:video),"order original bytes");
        Check(file!["dataBase64"]==null&&WorkbenchClient.S(file,"data").Length==0,"media metadata never includes source bytes");
    }
    var engineer=new WorkbenchClient();engineer.Configure(args[0],5);await engineer.Login("engineer","Demo-Repair-2026!");
    order=await live.Perform(order,"intake",new(){["ownerId"]=WorkbenchClient.S(live.Actor,"id"),["assigneeId"]=WorkbenchClient.S(engineer.Actor,"id")});
    JsonArray LivePictures()=>new(new JsonObject{["name"]="loan-proof.png",["mime"]="image/png",["dataBase64"]=Convert.ToBase64String(picture)});
    var loan=await live.WriteLoan("/loans",new(){["orderId"]=WorkbenchClient.S(order,"id"),["partId"]=WorkbenchClient.S(live.Parts[0],"id"),["quantity"]=2,["borrowerId"]=WorkbenchClient.S(engineer.Actor,"id"),["dueAt"]=DateTimeOffset.UtcNow.AddDays(7).ToString("O"),["note"]="原生合成借出",["attachments"]=LivePictures()});
    var liveReturned=await live.WriteLoan("/loans/"+WorkbenchClient.S(loan,"id")+"/actions",new(){["type"]="return",["version"]=WorkbenchClient.I(loan,"version"),["payload"]=new JsonObject{["quantity"]=1,["condition"]="good",["note"]="原生合成部分归还",["attachments"]=LivePictures()}});
    Check(WorkbenchClient.I(liveReturned,"outstanding")==1&&liveReturned["files"]!.AsArray().Count==2,"real partial return pictures");
    foreach(var file in liveReturned["files"]!.AsArray())Check((await live.LoanFile(WorkbenchClient.S(liveReturned,"id"),WorkbenchClient.S(file,"id"))).SequenceEqual(picture),"real loan original bytes");
    Console.WriteLine("PASS: real normal registration/reset/email login, controlled multi-company/account directory, atomic image/video order creation and original downloads, borrow/partial-return images and originals");
}
var fake = new ProtocolFixture();
var guarded = new WorkbenchClient(fake);
guarded.Configure("http://127.0.0.1:8098", 0.5);
await guarded.Login("admin", "1234");
Check(!guarded.IsDemo && WorkbenchClient.S(guarded.Actor, "id") == "real-admin", "fixture real identity");
fake.Mode = "503"; await guarded.Refresh();
Check(guarded.IsDemo, "503 must adopt separate synthetic data");
fake.Mode = "ok"; await guarded.Refresh();
Check(!guarded.IsDemo && WorkbenchClient.S(guarded.Actor, "id") == "real-admin", "automatic recovery must restore authenticated identity");
var original = guarded.Orders[0]!.DeepClone().AsObject();
fake.Mode = "lost-write";
for (var i=0;i<2;i++)
{
    try { await guarded.Perform(original,"remark",new JsonObject { ["remark"]="same frozen intent" }); throw new Exception("unknown write accepted"); }
    catch (Exception e) { Check(e.Message.StartsWith("提交结果未知"),"unknown write must remain unknown"); }
}
Check(fake.Keys.Count == 2 && fake.Keys[0] == fake.Keys[1],"unknown retry must reuse idempotency key");
fake.Mode = "403";
try { await guarded.Perform(original,"remark",new JsonObject { ["remark"]="rejected" }); throw new Exception("403 accepted"); }
catch(ApiException e) { Check(e.Status==403 && !guarded.IsDemo,"403 cannot report demo success"); }
fake.Mode = "ok";
var slow = guarded.Search("slow");
await guarded.Search("fast"); fake.ReleaseSlow(); await slow;
Check(WorkbenchClient.S(guarded.Orders[0],"number")=="FAST","late page must not replace latest search");
fake.Mode="401";
try { await guarded.Refresh(); throw new Exception("401 accepted"); } catch(ApiException e) { Check(e.Status==401 && guarded.Actor==null,"401 must clear all identity"); }
Console.WriteLine("PASS: Windows protocol 503 fallback/recovery/authenticated actor/unknown-write key replay/403 rejection/late-page exclusion/401 revocation");

var remoteFixture=new ProtocolFixture();
var remote=new WorkbenchClient(remoteFixture);remote.Configure("https://production.invalid",0.5);await remote.Login("admin","1234");
remoteFixture.Mode="503";
try{await remote.Refresh();throw new Exception("remote fallback accepted");}catch(ApiException e){Check(e.Status==503&&!remote.IsDemo&&!remote.CanUseDemo,"remote must never expose demo");}
var productionFixture=new ProtocolFixture{Mode="production"};var production=new WorkbenchClient(productionFixture);production.Configure("http://127.0.0.1:8098",0.5);await production.Login("admin","1234");productionFixture.Mode="offline";
try{await production.Refresh();throw new Exception("known production fallback");}catch(System.Net.Http.HttpRequestException){Check(!production.CanUseDemo&&!production.IsDemo,"known production cannot fall back after outage");}
var offlineFixture=new ProtocolFixture{Mode="offline"};var local=new WorkbenchClient(offlineFixture);local.Configure("http://127.0.0.1:8098",0.5);await local.Login("admin","1234");Check(local.IsDemo&&local.CanUseDemo,"local offline explicit synthetic mode");
var png=Convert.FromBase64String("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aF9sAAAAASUVORK5CYII=");
JsonArray Pictures()=>new(new JsonObject{["name"]="native-fixture.png",["mime"]="image/png",["dataBase64"]=Convert.ToBase64String(png)});
var borrowed=await local.WriteLoan("/loans",new JsonObject{["orderId"]=WorkbenchClient.S(local.Orders[0],"id"),["partId"]=WorkbenchClient.S(local.Parts[0],"id"),["quantity"]=2,["borrowerId"]=WorkbenchClient.S(local.Actor,"id"),["dueAt"]=DateTimeOffset.Now.AddDays(3).ToString("O"),["note"]="native fixture",["attachments"]=Pictures()});
Check(WorkbenchClient.I(borrowed,"outstanding")==2&&borrowed["files"]!.AsArray().Count==1,"demo borrow image metadata");
var returned=await local.WriteLoan("/loans/"+WorkbenchClient.S(borrowed,"id")+"/actions",new JsonObject{["type"]="return",["version"]=WorkbenchClient.I(borrowed,"version"),["payload"]=new JsonObject{["quantity"]=1,["condition"]="good",["attachments"]=Pictures(),["note"]="partial return"}});
Check(WorkbenchClient.I(returned,"outstanding")==1&&returned["files"]!.AsArray().Count==2,"demo partial return picture");
var originalFile=await local.LoanFile(WorkbenchClient.S(returned,"id"),WorkbenchClient.S(returned["files"]![0],"id"));Check(originalFile.SequenceEqual(png),"demo original image roundtrip");
var email="native-offline@example.test";
var code=await local.Authentication("/auth/email-code",new(){["email"]=email,["purpose"]="register"});
await local.Authentication("/register",new(){["email"]=email,["username"]="native_offline",["name"]="Native",["code"]=WorkbenchClient.S(code,"demoCode"),["password"]="Native-offline-2026!",["confirmPassword"]="Native-offline-2026!"});
await local.Login("native_offline","Native-offline-2026!");Check(local.IsDemo&&WorkbenchClient.S(local.Actor,"username")=="native_offline","offline registration login");
var reset=await local.Authentication("/auth/email-code",new(){["email"]=email,["purpose"]="reset_password"});
await local.Authentication("/reset-password",new(){["email"]=email,["code"]=WorkbenchClient.S(reset,"demoCode"),["password"]="Changed-offline-2026!",["confirmPassword"]="Changed-offline-2026!"});
await local.Login(email,"Changed-offline-2026!");Check(local.IsDemo,"offline reset and email login");
Console.WriteLine("PASS: local-only demo gates, known production protection, remote rejection, image borrow/partial return/original roundtrip, offline register/reset/email login");
await OrderFilterSmoke.Run();
await StreamingSmoke.Run();
if(args.Length>3)await StreamingSmoke.Live(args[0],args[3],args[2]);

sealed class ProtocolFixture : System.Net.Http.HttpMessageHandler
{
    public string Mode="ok";
    public readonly List<string> Keys=[];
    readonly TaskCompletionSource gate=new(TaskCreationOptions.RunContinuationsAsynchronously);
    readonly JsonObject seed=JsonNode.Parse(File.ReadAllText(Path.Combine(AppContext.BaseDirectory,"Resources","demo.json")))!["admin"]!.AsObject();
    JsonObject Actor => new() { ["id"]="real-admin",["role"]="admin",["companyId"]="real-company",["authVersion"]=1,["status"]="active",["name"]="fixture",["username"]="admin" };
    public void ReleaseSlow()=>gate.TrySetResult();
    protected override async Task<System.Net.Http.HttpResponseMessage> SendAsync(System.Net.Http.HttpRequestMessage request,CancellationToken cancel)
    {
        JsonNode raw;
        var path=request.RequestUri!.AbsolutePath;
        if(Mode=="offline")throw new System.Net.Http.HttpRequestException("offline");
        if(path.EndsWith("/healthz"))return Response(200,new JsonObject{["status"]="ok",["mode"]=Mode=="production"?"production":"synthetic_demo"});
        if(Mode=="401")return Response(401,new JsonObject{["message"]="unauthorized"});
        if(path.EndsWith("/login")) raw=new JsonObject{["token"]="fixture-token",["actor"]=Actor};
        else if(path.EndsWith("/actions"))
        {
            Keys.Add(request.Headers.GetValues("Idempotency-Key").Single());
            if(Mode=="lost-write")throw new System.Net.Http.HttpRequestException("response lost after send");
            return Response(403,new JsonObject{["message"]="forbidden"});
        }
        else if(path.EndsWith("/orders"))
        {
            var slow=request.RequestUri.Query.Contains("slow");
            if(slow)await gate.Task;
            var order=seed["orders"]![0]!.DeepClone();order!["number"]=slow?"SLOW":"FAST";
            raw=new JsonObject{["items"]=new JsonArray(order),["page"]=1,["pageSize"]=30,["totalPages"]=1};
        }
        else
        {
            if(Mode=="503")return Response(503,new JsonObject{["message"]="outage"});
            raw=new JsonObject{["actor"]=Actor,["orders"]=seed["orders"]!.DeepClone(),["parts"]=seed["parts"]!.DeepClone(),["loans"]=new JsonArray(),["metrics"]=new JsonObject(),["orderPage"]=new JsonObject{["totalPages"]=1}};
        }
        return Response(200,raw);
    }
    static System.Net.Http.HttpResponseMessage Response(int status,JsonNode node)=>new((System.Net.HttpStatusCode)status){Content=new System.Net.Http.StringContent(node.ToJsonString())};
}
