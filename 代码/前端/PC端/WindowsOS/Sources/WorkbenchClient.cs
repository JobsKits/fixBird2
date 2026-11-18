using System.IO;
// Created by Jobs on 2026-11-18. Native WPF client; credentials remain in memory.
using System.Net;
using System.Net.Http;
using System.Text;
using System.Text.Json.Nodes;
using System.Security.Cryptography;

namespace RepairDesktop;

sealed class ApiException(int status, string message) : Exception(message)
{
    public int Status { get; } = status;
    public bool IsRejection => Status is 400 or 401 or 403 or 404 or 409 or 422 or 429;
}

sealed partial class WorkbenchClient
{
    readonly HttpClient http;
    public WorkbenchClient(HttpMessageHandler? handler = null)
    {
        http = new HttpClient(handler ?? new SocketsHttpHandler { AllowAutoRedirect = false, ConnectTimeout=TimeSpan.FromSeconds(5) }) { Timeout=System.Threading.Timeout.InfiniteTimeSpan };
        demoAuth = new LocalDemoAuthentication(seeds);
    }
    readonly Dictionary<string, string> intents = [];
    readonly Dictionary<string, byte[]> demoLoanFiles = [];
    readonly Dictionary<string, byte[]> demoOrderFiles = [];
    readonly JsonObject seeds = JsonNode.Parse(File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "Resources", "demo.json")))!.AsObject();
    readonly LocalDemoAuthentication demoAuth;
    JsonObject? demo;
    JsonObject? demoActor;
    JsonObject? demoDirectory;
    public JsonObject CustomerDirectory {get;private set;}=new(){["customers"]=new JsonArray(),["canManage"]=false};
    string? token;
    JsonObject? serverActor;
    int readRevision;
    string username = "";
    string password = "";
    int epoch;
    public string Endpoint { get; private set; } = "http://127.0.0.1:8098";
    public double Timeout { get; private set; } = 2.5;
    public bool IsDemo { get; private set; }
    public bool CanUseDemo { get; private set; }
    bool knownProduction;
    public JsonObject? Actor { get; private set; }
    public JsonArray Orders { get; private set; } = [];
    public JsonArray Parts { get; private set; } = [];
    public JsonArray Loans { get; private set; } = [];
    public JsonObject Metrics { get; private set; } = [];
    public string Message { get; private set; } = "欢迎使用";
    public bool More { get; private set; }
    int page = 1;
    string query = "";
    string status = "";
    public string SearchText => query;
    public string StatusFilter => status;
    public static readonly string[] OrderStatuses=["pending_intake","pending_arrangement","diagnosis_quotation","pending_customer_confirmation","pending_execution","repairing","pending_quality_check","pending_delivery","pending_acceptance","settling","pending_completion","completed"];
    public string Context => epoch + ":" + S(Actor, "id") + ":" + IsDemo;
    public static string IdentityCaption(JsonObject actor,Func<string,string> translate)
    {
        var roles=new Dictionary<string,string>{["admin"]="公司负责人",["dispatcher"]="客服调度",["engineer"]="工程师",["finance"]="财务",["warehouse"]="仓库",["qc"]="质检",["customer"]="客户",["outsource"]="一手外包",["supplier"]="供应商"};
        string role=roles.GetValueOrDefault(S(actor,"role"),S(actor,"role")),label=translate(role),name=S(actor,"name").Trim();
        return name.Length==0||name==role||name==label||name==S(actor,"role")?label:name+" · "+label;
    }
    public static string S(JsonNode? n, string key) => n?[key]?.ToString() ?? "";
    public static int I(JsonNode? n, string key) => int.TryParse(S(n, key), out var x) ? x : 0;
    public static bool B(JsonNode? n, string key) => S(n, key) == "true";

    public void Configure(string endpoint, double timeout)
    {
        if (!Uri.TryCreate(endpoint.Trim().TrimEnd('/'), UriKind.Absolute, out var uri) || !(uri.Scheme == "https" || uri.Scheme == "http") || !string.IsNullOrEmpty(uri.UserInfo) || uri.AbsolutePath != "/" || !string.IsNullOrEmpty(uri.Query) || !string.IsNullOrEmpty(uri.Fragment) || timeout < 0.5 || timeout > 30 || !double.IsFinite(timeout))
            throw new Exception("服务地址须为不含凭据、路径或查询的 HTTP(S) 地址");
        Clear();
        Endpoint = uri.GetLeftPart(UriPartial.Authority);
        CanUseDemo = false; knownProduction = false; demoAuth.Reset(); demoDirectory=null;
        Timeout = timeout;
    }

    public async Task ProbeDemoAvailability()
    {
        var captured = epoch;
        CanUseDemo = false;
        if (!Uri.TryCreate(Endpoint, UriKind.Absolute, out var uri) || !(uri.Host.Equals("localhost", StringComparison.OrdinalIgnoreCase) || IPAddress.TryParse(uri.Host.Trim('[', ']'), out var ip) && IPAddress.IsLoopback(ip))) return;
        try
        {
            var health = await Wire("/healthz");
            if (captured != epoch) return;
            if (S(health, "status") == "ok" && S(health, "mode") == "production") knownProduction = true;
            CanUseDemo = S(health, "status") == "ok" && S(health, "mode") == "synthetic_demo";
        }
        catch (Exception failure) when (failure is HttpRequestException or TaskCanceledException)
        {
            if (captured == epoch) CanUseDemo = !knownProduction;
        }
        catch { if (captured == epoch) CanUseDemo = false; }
    }

    void Clear()
    {
        epoch++; ResetTransfers(); Message="欢迎使用";
        Actor = null; serverActor = null; readRevision++;
        token = null;
        username = password = "";
        Orders = []; Parts = []; Loans = []; Metrics = [];
        More = false; IsDemo = false; demo = null; demoActor=null;query=status="";page=1;
        intents.Clear(); demoLoanFiles.Clear(); demoOrderFiles.Clear(); CustomerDirectory=new(){["customers"]=new JsonArray(),["canManage"]=false};
    }

    public async Task<JsonNode?> Authentication(string path, JsonObject body)
    {
        if (path is not ("/auth/email-code" or "/register" or "/reset-password")) throw new InvalidOperationException();
        ValidatePasswords(body);
        await ProbeDemoAvailability();
        try { return await Wire(path, body); }
        catch (Exception failure) when (CanUseDemo && failure is HttpRequestException or TaskCanceledException)
        { return demoAuth.Perform(path,body,key=>key); }
    }

    public async Task Logout()
    {
        var old = token;
        Clear();
        if (old != null)
        {
            try { await Wire("/logout", new JsonObject(), old); } catch { }
        }
    }

    public async Task Login(string name, string secret)
    {
        if(!PasswordCharacterPolicy.IsValid(secret))throw new InvalidDataException(PasswordCharacterPolicy.ErrorMessage);
        await ProbeDemoAvailability();
        Clear(); username = name.Trim(); password = secret;
        if (username.Length == 0 || secret.Length == 0) throw new Exception("请填写账号和密码。");
        var captured = epoch;
        try { await Authenticate(); await Refresh(); }
        catch (ApiException error) when (error.IsRejection) { if (captured == epoch) Clear(); throw; }
        catch (Exception error) when (error is HttpRequestException or TaskCanceledException or InvalidDataException || error is ApiException { IsRejection: false })
        {
            if (captured != epoch) throw new Exception("身份或数据来源已改变，请重新打开当前单据。");
            if (!CanUseDemo) { Clear(); throw; }
            demoActor=demoAuth.Login(new JsonObject{["username"]=username,["password"]=password},key=>key);
            UseDemo();
            Message = "API登录未验证，已进入独立合成演示；刷新继续尝试服务";
        }
    }

    async Task Authenticate()
    {
        if (token != null) return;
        var raw = await Wire("/login", new JsonObject { ["username"] = username, ["password"] = password });
        if (raw is not JsonObject obj || obj["actor"] is not JsonObject actor || S(obj, "token").Length == 0 || S(actor, "status") != "active" || I(actor, "authVersion") < 1 || S(actor, "id").Length == 0)
            throw new InvalidDataException("响应未通过校验：登录响应无效");
        token = S(obj, "token");
        Actor = actor.DeepClone().AsObject();
        serverActor = actor.DeepClone().AsObject();
    }

    void UseDemo()
    {
        demoActor ??= demoAuth.Login(new JsonObject{["username"]=username,["password"]=password},key=>key);
        if (demo == null)
        {
            demo = (seeds[username] ?? seeds["customer"])!.DeepClone().AsObject();
            demo["actor"]=demoActor.DeepClone();
            if(S(demoActor,"role")=="customer")foreach(var order in demo["orders"]!.AsArray()){order!["customerId"]=S(demoActor,"id");order["companyId"]=S(demoActor,"companyId");}
            try{SeedDemoDeviceMedia();}catch{demo=null;throw;}
            var stock=demo["parts"]!.AsArray();
            var borrowPath=Path.Combine(AppContext.BaseDirectory,"Resources","LoanBorrow.png");
            var returnPath=Path.Combine(AppContext.BaseDirectory,"Resources","LoanReturn.png");
            if(stock.Count>0&&File.Exists(borrowPath)&&File.Exists(returnPath))
            {
                string loanId="ios-demo-picture-loan";var files=new JsonArray();
                foreach(var item in new[]{(Path:borrowPath,Stage:"borrow",Quantity:2),(Path:returnPath,Stage:"return",Quantity:1)})
                {
                    var bytes=File.ReadAllBytes(item.Path);string fileId="ios-demo-picture-"+item.Stage;
                    files.Add(new JsonObject{["id"]=fileId,["name"]=Path.GetFileName(item.Path),["mime"]="image/png",["size"]=bytes.Length,["uploaderId"]=S(demoActor,"id"),["createdAt"]=DateTimeOffset.UtcNow.ToString("O"),["stage"]=item.Stage,["quantity"]=item.Quantity,["condition"]=item.Stage=="return"?"good":"",["note"]="SYNTHETIC DEMO"});demoLoanFiles[loanId+":"+fileId]=bytes;
                }
                demo["loans"]!.AsArray().Add(new JsonObject{["id"]=loanId,["version"]=2,["orderId"]=S(demo["orders"]![0],"id"),["partId"]=S(stock[0],"id"),["partName"]=S(stock[0],"name"),["quantity"]=2,["returnedGood"]=1,["returnedQuarantine"]=0,["outstanding"]=1,["borrowerId"]="ios-demo-engineer",["createdAt"]=S(files[0],"createdAt"),["updatedAt"]=S(files[^1],"createdAt"),["dueAt"]="2099-12-31T15:59:59Z",["note"]="SYNTHETIC DEMO",["files"]=files});stock[0]!["available"]=Math.Max(0,I(stock[0],"available")-1);
            }

        }
        IsDemo = true;
        Actor = demo["actor"]!.DeepClone().AsObject();
        ApplyDemoOrderQuery(query,status,1);
        Parts = demo["parts"]!.DeepClone().AsArray();
        Loans = demo["loans"]!.DeepClone().AsArray();
    }

    public Task Refresh()=>ReadOrderPage(query,status,1,true);

    async Task ReadOrderPage(string search,string selectedStatus,int next,bool refreshMetadata)
    {
        var revision = ++readRevision;
        var captured = epoch;
        int requestedPage=next;
        bool wasDemo=IsDemo;
        if(wasDemo)next=1;
        try
        {
            await Authenticate();
            JsonObject? metadata=null;
            JsonArray items;
            int totalPages;
            if(refreshMetadata||IsDemo)
            {
                var raw=await Wire("/bootstrap",bearer:token);
                if(captured!=epoch||revision!=readRevision)return;
                if(raw is not JsonObject obj||obj["actor"] is not JsonObject actor||!ValidActor(actor)||obj["orders"] is not JsonArray orders||obj["parts"] is not JsonArray||obj["loans"] is not JsonArray||obj["metrics"] is not JsonObject)throw new InvalidDataException("响应未通过校验：概览不可用");
                foreach(var order in orders)ValidateOrder(order,false);
                metadata=obj;items=orders;totalPages=I(obj["orderPage"],"totalPages");
                if(search.Length>0||selectedStatus.Length>0||next>1)(items,totalPages)=await FetchOrderPage(search,selectedStatus,next);
            }
            else (items,totalPages)=await FetchOrderPage(search,selectedStatus,next);
            if(captured!=epoch||revision!=readRevision)return;
            bool append=!wasDemo&&next>1&&query==search&&status==selectedStatus;
            var received=append?Orders.DeepClone().AsArray():new JsonArray();
            var identities=received.Select(order=>S(order,"id")).ToHashSet();
            foreach(var item in items)if(identities.Add(S(item,"id")))received.Add(item!.DeepClone());
            if(metadata!=null)
            {
                Actor=metadata["actor"]!.DeepClone().AsObject();Parts=metadata["parts"]!.DeepClone().AsArray();Loans=metadata["loans"]!.DeepClone().AsArray();Metrics=metadata["metrics"]!.DeepClone().AsObject();
            }
            IsDemo=false;Orders=received;query=search;status=selectedStatus;page=next;More=totalPages>page;
            Message = "服务端数据";
        }
        catch (ApiException e) when (e.IsRejection) { if (e.Status == 401) Clear(); throw; }
        catch (Exception error) when (error is HttpRequestException or TaskCanceledException or InvalidDataException || error is ApiException { IsRejection: false })
        {
            if (captured != epoch || revision != readRevision) return;
            await ProbeDemoAvailability();
            if(captured!=epoch||revision!=readRevision)return;
            if (!CanUseDemo) throw;
            UseDemo();ApplyDemoOrderQuery(search,selectedStatus,requestedPage);Message = "独立合成演示";
        }
    }

    void SeedDemoDeviceMedia()
    {
        string directory=Path.Combine(AppContext.BaseDirectory,"Resources");
        var manifest=JsonNode.Parse(File.ReadAllText(Path.Combine(directory,"media-seed.json")))?.AsObject()??throw new InvalidDataException("合成演示设备资料");
        if(I(manifest,"version")!=1||manifest["orders"] is not JsonObject orders)throw new InvalidDataException("合成演示设备资料");
        var staged=new List<(JsonObject Order,JsonArray Files,List<(string Key,byte[] Bytes)> Originals)>();
        foreach(var order in demo!["orders"]!.AsArray().OfType<JsonObject>())
        {
            string orderId=S(order,"id");
            if(orders[orderId] is not JsonArray entries||entries.Count==0)continue;
            var files=new JsonArray();var originals=new List<(string,byte[])>();
            foreach(var entry in entries)
            {
                string resource=S(entry,"resource"),mime=S(entry,"mime"),name=S(entry,"name");
                if(Path.GetFileName(resource)!=resource||resource.Length==0||mime is not ("image/png" or "video/mp4")||name.Length==0)throw new InvalidDataException("合成演示设备资料");
                byte[] bytes=File.ReadAllBytes(Path.Combine(directory,resource));
                string digest=Convert.ToHexString(SHA256.HashData(bytes)).ToLowerInvariant();
                if(entry?["size"] is not JsonValue size||!size.TryGetValue<long>(out long length)||length!=bytes.LongLength||bytes.Length==0||S(entry,"sha256")!=digest)throw new InvalidDataException("文件原件校验失败");
                string id="ios-demo-seed-"+Path.GetFileNameWithoutExtension(resource);
                files.Add(new JsonObject{["id"]=id,["name"]=name,["mime"]=mime,["kind"]=mime.StartsWith("video/",StringComparison.Ordinal)?"video":"image",["size"]=bytes.LongLength,["sha256"]=digest,["uploaderId"]=S(demoActor,"id"),["createdAt"]=S(order,"createdAt"),["stage"]=S(order,"status"),["public"]=true,["localReference"]=resource,["posterReference"]=S(entry,"posterResource"),["note"]="SYNTHETIC DEMO"});
                originals.Add((orderId+":"+id,bytes));
            }
            staged.Add((order,files,originals));
        }
        foreach(var item in staged)
        {
            item.Order["evidence"]=item.Files;
            foreach(var original in item.Originals)demoOrderFiles[original.Key]=original.Bytes;
        }
    }

    async Task<(JsonArray Items,int TotalPages)> FetchOrderPage(string search,string selectedStatus,int next)
    {
        var raw=await Wire($"/orders?page={next}&pageSize=30&q={Uri.EscapeDataString(search)}&status={Uri.EscapeDataString(selectedStatus)}",bearer:token);
        if(raw?["items"] is not JsonArray items||I(raw,"page")!=next||I(raw,"pageSize")<1||I(raw,"pageSize")>200||I(raw,"totalPages")<0)throw new InvalidDataException("响应未通过校验：分页资料无效");
        foreach(var order in items)
        {
            ValidateOrder(order,false);
            if(selectedStatus.Length>0&&S(order,"status")!=selectedStatus)throw new InvalidDataException("响应未通过校验：分页资料无效");
        }
        return(items,I(raw,"totalPages"));
    }

    void ApplyDemoOrderQuery(string search,string selectedStatus,int requestedPage)
    {
        var matches=demo!["orders"]!.AsArray().Where(order=>MatchesOrder(order,search,selectedStatus,S(demoActor,"role"))).ToArray();
        page=Math.Max(1,requestedPage);query=search;status=selectedStatus;
        Orders=new JsonArray(matches.Take(page*30).Select(order=>order!.DeepClone()).ToArray());More=matches.Length>page*30;
    }

    internal static bool MatchesOrder(JsonNode? order,string search,string selectedStatus,string role)
    {
        if(selectedStatus.Length>0&&S(order,"status")!=selectedStatus)return false;
        string text=string.Join(" ",new[]{"number","customer","project","device","description","ownerId"}.Select(field=>S(order,field)));
        if(role is "admin" or "dispatcher" or "finance")text+=" "+S(order,"remark");
        return text.Contains(search.Trim(),StringComparison.OrdinalIgnoreCase);
    }

    public bool ContainsCurrentOrder(string id)=>Orders.Any(order=>S(order,"id")==id);
    public bool MatchesCurrentQuery(JsonObject order)=>MatchesOrder(order,query,status,S(Actor,"role"));
    public string? DemoEvidenceThumbnail(string orderId,JsonObject evidence)
    {
        if(!IsDemo||!S(evidence,"id").StartsWith("ios-demo-seed-",StringComparison.Ordinal)||!demoOrderFiles.ContainsKey(orderId+":"+S(evidence,"id")))return null;
        var recorded=demo?["orders"]?.AsArray().FirstOrDefault(order=>S(order,"id")==orderId)?["evidence"]?.AsArray().FirstOrDefault(file=>S(file,"id")==S(evidence,"id"));
        string resource=S(recorded,"mime")=="video/mp4"?S(recorded,"posterReference"):S(recorded,"localReference");
        if(resource.Length==0||Path.GetFileName(resource)!=resource)return null;
        string path=Path.Combine(AppContext.BaseDirectory,"Resources",resource);return File.Exists(path)?path:null;
    }

    bool ValidActor(JsonObject actor) => S(actor, "id") == S(serverActor, "id") && S(actor, "role") == S(serverActor, "role") && S(actor, "companyId") == S(serverActor, "companyId") && I(actor, "authVersion") == I(serverActor, "authVersion") && S(actor, "status") == "active";

    static JsonObject ValidateOrder(JsonNode? node, bool full)
    {
        if (node is not JsonObject obj || S(obj, "id").Length == 0 || I(obj, "version") < 1 || obj["quote"] is not JsonObject || obj["summary"] is not JsonObject || obj["allowedActions"] is not JsonArray || S(obj, "device").Length == 0 || (full && B(obj, "isSummary")))
            throw new InvalidDataException("响应未通过校验：工单资料不完整");
        if (!ValidInteger(obj["quote"], "amountCents") || !ValidInteger(obj["quote"], "prepayCents") || !ValidInteger(obj["quote"], "version") || !ValidInteger(obj["summary"], "receivableCents") || !ValidInteger(obj["summary"], "remainingCents") || obj["allowedActions"]!.AsArray().Any(x => x is not JsonValue value || !value.TryGetValue<string>(out var action) || action.Length == 0))
            throw new InvalidDataException("响应未通过校验：工单资料不完整");
        return obj;
    }

    static bool ValidInteger(JsonNode? node, string key) => node?[key] is JsonValue value && value.TryGetValue<long>(out var number) && number >= 0;

    public Task Search(string search, bool append = false,string? selectedStatus=null)
    {
        search=search.Trim();selectedStatus??=status;
        if(selectedStatus.Length>0&&!OrderStatuses.Contains(selectedStatus))throw new ArgumentException("请核对填写内容");
        bool same=query==search&&status==selectedStatus;
        if(append&&same&&!More)return Task.CompletedTask;
        return ReadOrderPage(search,selectedStatus,append&&same?page+1:1,false);
    }

    public async Task<JsonObject> Detail(string id)
    {
        if (IsDemo)
        {
            await Probe();
            if (!IsDemo) throw new Exception("身份或数据来源已改变，请重新打开当前单据。");
            return demo!["orders"]!.AsArray().First(x => S(x, "id") == id)!.DeepClone().AsObject();
        }
        var value = ValidateOrder(await Wire("/orders/" + Uri.EscapeDataString(id), bearer: token), true);
        if (S(value, "id") != id) throw new InvalidDataException("响应未通过校验：详情工单不匹配");
        return value;
    }

    async Task Probe()
    {
        await ReadOrderPage(query,status,page,true);
        if (!IsDemo) throw new Exception("服务端数据已恢复，请重新加载后办理。");
    }

    public async Task<JsonObject> Create(JsonObject payload)
    {
        if (IsDemo)
        {
            await Probe();
            if (!new[] { "admin", "dispatcher", "customer" }.Contains(S(Actor, "role"))) throw new Exception("当前角色或阶段不允许此动作");
            var value = demo!["orders"]![0]!.DeepClone().AsObject();
            foreach (var p in payload) if(p.Key!="files")value[p.Key] = p.Value?.DeepClone();
            value["id"] = "ios-demo-" + Guid.NewGuid(); value["number"] = "DEMO-" + DateTime.Now.Ticks;
            value["version"] = 1; value["status"] = "pending_intake";
            value["createdAt"]=DateTimeOffset.UtcNow.ToString("O");value["updatedAt"]=value["createdAt"]!.ToString();
            value["evidence"]=new JsonArray();
            List<(string UploadId,JsonObject Evidence,NativeTemporaryFile File)>? resolved=null;
            if(payload["files"] is JsonArray refs&&refs.Any(x=>S(x,"uploadId").Length>0))
            {
                resolved=ResolveDemoDeviceUploads(refs);value["evidence"]=new JsonArray(resolved.Select(x=>(JsonNode)x.Evidence).ToArray());
            }
            else if(payload["files"] is JsonArray media)
            {
                var staged=new List<(JsonObject Meta,byte[] Data)>();
                foreach(var file in media)
                {
                    string mime=S(file,"mime"),encoded=S(file,"dataBase64");bool video=mime.StartsWith("video/",StringComparison.Ordinal);
                    var bytes=Convert.FromBase64String(encoded);if(bytes.Length==0)throw new InvalidDataException("请选择有效设备图片或视频原件");
                    if(!new[]{"image/png","image/jpeg","image/gif","image/webp","video/mp4","video/quicktime","video/webm"}.Contains(mime))throw new InvalidDataException("请核对填写内容");
                    var meta=new JsonObject{["id"]="ios-demo-evidence-"+Guid.NewGuid(),["name"]=Path.GetFileName(S(file,"name")),["mime"]=mime,["kind"]=video?"video":"image",["size"]=bytes.Length,["sha256"]=Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(bytes)).ToLowerInvariant(),["uploaderId"]=S(Actor,"id"),["createdAt"]=DateTimeOffset.UtcNow.ToString("O"),["stage"]="pending_intake",["public"]=true};staged.Add((meta,bytes));
                }
                value["evidence"]=new JsonArray(staged.Select(x=>(JsonNode)x.Meta).ToArray());foreach(var file in staged)demoOrderFiles[S(value,"id")+":"+S(file.Meta,"id")]=file.Data;
            }

            value["allowedActions"] = S(Actor,"role")=="customer"?new JsonArray("issue"):new JsonArray("intake","issue","remark");
            demo["orders"]!.AsArray().Insert(0, value);
            if(resolved!=null)foreach(var file in resolved){stagedDeviceUploads.Remove(file.UploadId);demoDeviceEvidence[S(value,"id")+":"+S(file.Evidence,"id")]=file.File;}
            UseDemo();
            return value.DeepClone().AsObject();
        }
        return await WriteOrder("/orders", payload, null);
    }

    public async Task<JsonObject> Perform(JsonObject order, string action, JsonObject payload)
    {
        if (!order["allowedActions"]!.AsArray().Any(x => x?.ToString() == action)) throw new Exception("当前角色或阶段不允许此动作");
        if (IsDemo)
        {
            await Probe();
            var value = demo!["orders"]!.AsArray().First(x => S(x, "id") == S(order, "id"))!.AsObject();
            if (I(value, "version") != I(order, "version")) throw new Exception("版本冲突，请重新加载后办理。");
            if (action is "sign_quote" or "accept") throw new Exception("独立演示不模拟客户签署结果，请连接服务后使用手写原件办理");
            if (action is "remark")
            {
                if (payload.ContainsKey("remark") && !new[] { "admin", "dispatcher", "finance", "engineer" }.Contains(S(Actor, "role"))) throw new Exception("当前角色不能修改内部备注");
                foreach (var p in payload) value[p.Key] = p.Value?.DeepClone();
            }
            else if (action == "intake") { value["status"] = "pending_arrangement"; value["allowedActions"] = new JsonArray("diagnose", "remark", "issue"); }
            else if (action == "diagnose") { value["status"] = "diagnosis_quotation"; value["allowedActions"] = new JsonArray("quote", "remark", "issue"); }
            else if (action == "quote")
            {
                if (I(payload, "amountCents") <= 0 || I(payload, "prepayCents") > I(payload, "amountCents") || I(payload, "warrantyMonths") is < 1 or > 60 || (B(payload, "startRequiresPrepayment") && I(payload, "prepayCents") <= 0) || S(payload, "description").Length == 0) throw new Exception("请核对报价、预付上限、方案和质保");
                var quote = payload.DeepClone().AsObject(); quote["version"] = I(value["quote"], "version") + 1; quote["signed"] = false; quote["approved"] = false;
                value["quote"] = quote; value["allowedActions"] = new JsonArray("quote", "approve_quote", "remark", "issue");
            }
            else if (action == "approve_quote")
            {
                if (!DateTimeOffset.TryParse(S(value["quote"], "validUntil"), out var until) || until < DateTimeOffset.Now) throw new Exception("报价不存在或已到接受期限");
                value["quote"]!["approved"] = true; value["status"] = "pending_customer_confirmation"; value["allowedActions"] = new JsonArray("remark", "issue");
            }
            else throw new Exception("此动作首版仅支持服务端办理，独立演示不会伪造票款或签署成功");
            value["version"] = I(value, "version") + 1;value["updatedAt"]=DateTimeOffset.UtcNow.ToString("O"); UseDemo(); return value.DeepClone().AsObject();
        }
        return await WriteOrder("/orders/" + S(order, "id") + "/actions", new JsonObject { ["type"] = action, ["version"] = I(order, "version"), ["payload"] = payload.DeepClone() }, order);
    }

    async Task<JsonObject> WriteOrder(string path, JsonObject body, JsonObject? original)
    {
        var fingerprint = path + body.ToJsonString();
        if (!intents.TryGetValue(fingerprint, out var key)) intents[fingerprint] = key = Guid.NewGuid().ToString();
        try
        {
            var result = ValidateOrder(await Wire(path, body, token, key), true);
            if (original != null && S(body, "type") != "rework" && (S(original, "id") != S(result, "id") || I(result, "version") <= I(original, "version"))) throw new InvalidDataException("写响应未确认本次版本推进");
            if (original != null && S(body, "type") == "rework" && (S(result, "id") == S(original, "id") || S(result, "originalOrderId") != S(original, "id"))) throw new InvalidDataException("写响应未确认本次版本推进");
            var expectedCustomer = S(serverActor, "role") == "customer" ? S(serverActor, "id") : S(body, "customerId");
            if (original == null && (S(body, "device") != S(result, "device") || S(body, "description") != S(result, "description") || S(body, "type") != S(result, "type") || expectedCustomer != S(result, "customerId") || (S(body, "companyId").Length > 0 && S(body, "companyId") != S(result, "companyId")))) throw new InvalidDataException("新建响应与原提交不匹配");
            if(original==null&&body["files"] is JsonArray media&&media.Count>0)
            {
                var originals=(result["evidence"] as JsonArray??[]).ToList();
                foreach(var file in media)
                {
                    var digest=S(file,"uploadId").Length>0?S(file,"sha256"):Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(Convert.FromBase64String(S(file,"dataBase64")))).ToLowerInvariant();
                    int match=originals.FindIndex(x=>S(x,"name")==S(file,"name")&&S(x,"mime")==S(file,"mime")&&S(x,"sha256")==digest);
                    if(match<0)throw new InvalidDataException("服务端未确认全部设备附件，保留原请求意图以便核对重试");
                    originals.RemoveAt(match);
                }
            }
            intents.Remove(fingerprint); Message = "服务端已确认保存"; return result;
        }
        catch (ApiException error) when(error.IsRejection) { throw; }
        catch (Exception e) { throw new Exception("提交结果未知，请核对后按原意图重试。" + e.Message); }
    }

    public async Task<JsonObject> WriteLoan(string path, JsonObject payload)
    {
        if (IsDemo) { await Probe(); return ApplyDemoLoan(path,payload); }
        var fingerprint = path + payload.ToJsonString();
        if (!intents.TryGetValue(fingerprint, out var key)) intents[fingerprint] = key = Guid.NewGuid().ToString();
        try
        {
            var result = await Wire(path, payload, token, key);
            if (result is not JsonObject || S(result, "id").Length == 0 || I(result, "version") <= 0) throw new InvalidDataException("写响应未通过校验");
            bool create=path=="/loans";
            if(create&&(S(result,"orderId")!=S(payload,"orderId")||S(result,"partId")!=S(payload,"partId")||I(result,"quantity")!=I(payload,"quantity")||S(result,"borrowerId")!=S(payload,"borrowerId")))throw new InvalidDataException("写响应未通过校验");
            if(!create&&(path!="/loans/"+S(result,"id")+(path.EndsWith("/files",StringComparison.Ordinal)?"/files":"/actions")||I(result,"version")<=I(payload,"version")))throw new InvalidDataException("写响应未通过校验");
            var submitted=(create||path.EndsWith("/files",StringComparison.Ordinal)?payload:payload["payload"])?["attachments"] as JsonArray;
            if(submitted?.Count>0&&(result["files"] is not JsonArray originals||originals.Count<submitted.Count||originals.Any(file=>file is not JsonObject||S(file,"id").Length==0||I(file,"size")<1||file!["dataBase64"]!=null)))throw new InvalidDataException("写响应未通过校验");
            intents.Remove(fingerprint); await Refresh(); return result!.DeepClone().AsObject();
        }
        catch (ApiException) { throw; }
        catch (Exception e) { throw new Exception("提交结果未知，请核对后按原意图重试。" + e.Message); }
    }

    public async Task LoadCustomerDirectory()
    {
        if(IsDemo)
        {
            await Probe();
            if(demoDirectory==null)
            {
                var actor=seeds["customer"]!["actor"]!.DeepClone();
                demoDirectory=new(){["customers"]=new JsonArray(new JsonObject{["id"]="ios-demo-directory-group",["name"]="合成演示客户",["accounts"]=new JsonArray(actor),["companies"]=new JsonArray(new JsonObject{["id"]=S(actor,"companyId"),["name"]="合成演示企业"})}),["canManage"]=true};
            }
            CustomerDirectory=demoDirectory.DeepClone().AsObject();
            if(S(Actor,"role")=="customer")
            {
                CustomerDirectory=new(){["customers"]=new JsonArray(new JsonObject{["id"]="ios-demo-own-group",["name"]=S(Actor,"name"),["accounts"]=new JsonArray(Actor!.DeepClone()),["companies"]=new JsonArray(new JsonObject{["id"]=S(Actor,"companyId"),["name"]=S(Actor,"companyId")})}),["canManage"]=false};
            }
            else CustomerDirectory["canManage"]=new[]{"admin","dispatcher"}.Contains(S(Actor,"role"));
            return;
        }
        var directory=await Wire("/customer-directory",bearer:token);
        if(directory is not JsonObject value||value["customers"] is not JsonArray||value["canManage"] is not JsonValue)throw new InvalidDataException("请核对填写内容");
        CustomerDirectory=value.DeepClone().AsObject();
    }
    public async Task<JsonObject> CreateDirectoryEntry(JsonObject body)
    {
        ValidatePasswords(body);
        if(IsDemo)
        {
            await Probe();if(!new[]{"admin","dispatcher"}.Contains(S(Actor,"role")))throw new ApiException(403,"当前角色或阶段不允许此动作");
            await LoadCustomerDirectory();var groups=demoDirectory!["customers"]!.AsArray();string operation=S(body,"operation");JsonObject customer;JsonObject? account=null;string companyId;
            if(operation=="customer")
            {
                if(S(body,"name").Trim().Length==0||S(body,"companyName").Trim().Length==0)throw new InvalidDataException("请核对填写内容");
                companyId="ios-demo-company-"+Guid.NewGuid();account=demoAuth.AddDirectoryAccount(body,companyId);
                customer=new(){["id"]="ios-demo-customer-group-"+Guid.NewGuid(),["name"]=S(body,"name"),["accounts"]=new JsonArray(account.DeepClone()),["companies"]=new JsonArray(new JsonObject{["id"]=companyId,["name"]=S(body,"companyName")})};groups.Add(customer);
            }
            else
            {
                customer=groups.FirstOrDefault(x=>S(x,"id")==S(body,"customerId"))?.AsObject()??throw new InvalidDataException("请核对填写内容");
                if(operation=="company")
                {
                    if(S(body,"name").Trim().Length==0)throw new InvalidDataException("请核对填写内容");companyId="ios-demo-company-"+Guid.NewGuid();customer["companies"]!.AsArray().Add(new JsonObject{["id"]=companyId,["name"]=S(body,"name")});
                }
                else if(operation=="account")
                {
                    companyId=S(body,"companyId");if(!customer["companies"]!.AsArray().Any(x=>S(x,"id")==companyId))throw new InvalidDataException("请核对填写内容");account=demoAuth.AddDirectoryAccount(body,companyId);customer["accounts"]!.AsArray().Add(account.DeepClone());
                }
                else throw new InvalidDataException("请核对填写内容");
            }
            await LoadCustomerDirectory();var result=CustomerDirectory.DeepClone().AsObject();result["customerId"]=S(customer,"id");result["accountId"]=S(account,"id");result["companyId"]=companyId;return result;
        }
        var fingerprint="/customer-directory"+body.ToJsonString();if(!intents.TryGetValue(fingerprint,out var key))intents[fingerprint]=key=Guid.NewGuid().ToString();
        try{var result=await Wire("/customer-directory",body,token,key);if(result is not JsonObject directory||directory["customers"] is not JsonArray)throw new InvalidDataException("请核对填写内容");intents.Remove(fingerprint);CustomerDirectory=directory.DeepClone().AsObject();return directory;}
        catch(ApiException){throw;}catch(Exception error){throw new Exception("提交结果未知，请核对后按原意图重试。"+error.Message);}
    }

    public async Task<byte[]> LoanFile(string loanId,string fileId)
    {
        var captured=epoch;
        if(IsDemo)
        {
            await Probe();
            return demoLoanFiles.TryGetValue(loanId+":"+fileId,out var bytes)?bytes.ToArray():throw new InvalidDataException("暂时没有记录");
        }
        using var request=new HttpRequestMessage(HttpMethod.Get,Endpoint+"/api/v38/loans/"+Uri.EscapeDataString(loanId)+"/files/"+Uri.EscapeDataString(fileId));
        request.Headers.Authorization=new("Bearer",token);
        using var cancellation=new CancellationTokenSource(TimeSpan.FromSeconds(Timeout));
        using var response=await http.SendAsync(request,HttpCompletionOption.ResponseHeadersRead,cancellation.Token);
        if(!response.IsSuccessStatusCode){if(response.StatusCode==HttpStatusCode.Unauthorized)Clear();throw new ApiException((int)response.StatusCode,"HTTP "+(int)response.StatusCode);}
        if(response.Content.Headers.ContentLength>8*1024*1024)throw new InvalidDataException("图片最多8张，单张8MiB，总计32MiB");
        var data=await response.Content.ReadAsByteArrayAsync(cancellation.Token);
        if(captured!=epoch)throw new Exception("身份或数据来源已改变，请重新打开当前单据。");
        if(data.Length>8*1024*1024)throw new InvalidDataException("图片最多8张，单张8MiB，总计32MiB");
        return data;
    }

    JsonObject ApplyDemoLoan(string path,JsonObject payload)
    {
        if(!CanUseDemo||!new[]{"admin","warehouse","dispatcher","engineer"}.Contains(S(Actor,"role")))throw new ApiException(403,"当前角色或阶段不允许此动作");
        bool create=path=="/loans",append=path.EndsWith("/files",StringComparison.Ordinal);
        var body=create||append?payload:payload["payload"]?.AsObject()??throw new InvalidDataException("请核对填写内容");
        int quantity=I(body,"quantity");if(quantity<1)throw new InvalidDataException("请输入有效整数");
        JsonObject record;JsonObject part;
        if(create)
        {
            if(!demo!["orders"]!.AsArray().Any(x=>S(x,"id")==S(body,"orderId")))throw new InvalidDataException("请核对填写内容");
            part=demo["parts"]!.AsArray().FirstOrDefault(x=>S(x,"id")==S(body,"partId"))?.AsObject()??throw new InvalidDataException("请核对填写内容");
            if(I(part,"available")<quantity||S(body,"borrowerId").Length==0)throw new InvalidDataException("请核对填写内容");
            record=new(){["id"]="ios-demo-loan-"+Guid.NewGuid(),["version"]=1,["orderId"]=S(body,"orderId"),["partId"]=S(part,"id"),["partName"]=S(part,"name"),["quantity"]=quantity,["returnedGood"]=0,["returnedQuarantine"]=0,["consumed"]=0,["disposed"]=0,["outstanding"]=quantity,["borrowerId"]=S(body,"borrowerId"),["dueAt"]=S(body,"dueAt"),["note"]=S(body,"note"),["files"]=new JsonArray()};
            record["createdAt"]=DateTimeOffset.UtcNow.ToString("O");
        }
        else
        {
            record=demo!["loans"]!.AsArray().FirstOrDefault(x=>path=="/loans/"+S(x,"id")+(append?"/files":"/actions"))?.AsObject()??throw new InvalidDataException("请核对填写内容");
            if(I(payload,"version")!=I(record,"version"))throw new ApiException(409,"版本冲突，请重新加载后办理。");
            if(!append&&(S(payload,"type")!="return"||quantity>I(record,"outstanding")||S(body,"condition") is not ("good" or "quarantine")))throw new InvalidDataException("请核对填写内容");
            part=demo["parts"]!.AsArray().First(x=>S(x,"id")==S(record,"partId"))!.AsObject();
        }
        var existing=record["files"] as JsonArray??[];
        var attachments=body["attachments"] as JsonArray??throw new InvalidDataException("请至少选择一张图片凭据");
        if(attachments.Count<1)throw new InvalidDataException("请至少选择一张图片凭据");
        long total=existing.Sum(x=>(long)I(x,"size"));var decoded=new List<(JsonObject Meta,byte[] Data)>();
        foreach(var file in attachments)
        {
            if(S(file,"dataBase64").Length>12*1024*1024)throw new InvalidDataException("图片最多8张，单张8MiB，总计32MiB");
            var bytes=Convert.FromBase64String(S(file,"dataBase64"));var mime=S(file,"mime");
            bool image=mime=="image/png"&&bytes.Length>=8&&bytes.AsSpan(0,8).SequenceEqual(new byte[]{137,80,78,71,13,10,26,10})||mime=="image/jpeg"&&bytes.Length>=3&&bytes[0]==255&&bytes[1]==216&&bytes[2]==255||mime=="image/gif"&&bytes.Length>=6&&Encoding.ASCII.GetString(bytes,0,6) is "GIF87a" or "GIF89a";
            if(!image||bytes.Length>8*1024*1024||(total+=bytes.Length)>32*1024*1024||existing.Count+decoded.Count+1>8)throw new InvalidDataException("图片最多8张，单张8MiB，总计32MiB");
            var meta=new JsonObject{["id"]="demo-loan-file-"+Guid.NewGuid(),["name"]=Path.GetFileName(S(file,"name")),["mime"]=mime,["size"]=bytes.Length,["uploaderId"]=S(Actor,"id"),["createdAt"]=DateTimeOffset.UtcNow.ToString("O"),["stage"]=create?"borrow":append?S(body,"stage"):"return",["quantity"]=quantity,["note"]=S(body,"note")};
            if(!create)meta["condition"]=S(body,"condition");decoded.Add((meta,bytes));
        }
        if(create){part["available"]=I(part,"available")-quantity;demo!["loans"]!.AsArray().Add(record);}
        else if(!append){record["outstanding"]=I(record,"outstanding")-quantity;var counter=S(body,"condition")=="good"?"returnedGood":"returnedQuarantine";record[counter]=I(record,counter)+quantity;var stock=S(body,"condition")=="good"?"available":"quarantine";part[stock]=I(part,stock)+quantity;}
        foreach(var file in decoded){existing.Add(file.Meta);demoLoanFiles[S(record,"id")+":"+S(file.Meta,"id")]=file.Data;}
        record["files"]=existing.Parent==null?existing:existing.DeepClone();if(!create)record["version"]=I(record,"version")+1;
        record["updatedAt"]=DateTimeOffset.UtcNow.ToString("O");
        UseDemo();return record.DeepClone().AsObject();
    }

    static void ValidatePasswords(JsonObject body)
    {
        foreach(var key in new[]{"password","confirmPassword"})
            if(body.ContainsKey(key)&&!PasswordCharacterPolicy.IsValid(S(body,key)))throw new InvalidDataException(PasswordCharacterPolicy.ErrorMessage);
    }

    async Task<JsonNode?> Wire(string path, JsonObject? body = null, string? bearer = null, string? key = null)
    {
        var captured = epoch;
        using var request = new HttpRequestMessage(body == null ? HttpMethod.Get : HttpMethod.Post, Endpoint + "/api/v38" + path);
        request.Headers.Accept.ParseAdd("application/json");
        if (bearer != null) request.Headers.Authorization = new("Bearer", bearer);
        if (key != null) request.Headers.Add("Idempotency-Key", key);
        if (body != null) request.Content = new StringContent(body.ToJsonString(), Encoding.UTF8, "application/json");
        using var cancellation = new CancellationTokenSource(TimeSpan.FromSeconds(Timeout));
        using var response = await http.SendAsync(request, cancellation.Token);
        var bytes = await response.Content.ReadAsByteArrayAsync(cancellation.Token);
        if (captured != epoch) throw new Exception("身份或数据来源已改变，请重新打开当前单据。");
        JsonNode? raw;
        try { raw = JsonNode.Parse(bytes); } catch { raw = null; }
        if (!response.IsSuccessStatusCode)
        {
            if (response.StatusCode == HttpStatusCode.Unauthorized) Clear();
            throw new ApiException((int)response.StatusCode, S(raw, "message") is { Length: > 0 } msg ? msg : "HTTP " + (int)response.StatusCode);
        }
        return raw ?? throw new InvalidDataException("响应未通过校验：JSON无法解析");
    }
}
