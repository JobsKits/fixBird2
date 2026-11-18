using System.Net;
using System.Security.Cryptography;
using System.Text.Json.Nodes;
using RepairDesktop;
using static RepairDesktop.WorkbenchClient;

static class OrderFilterSmoke
{
    static void Check(bool condition,string reason){if(!condition)throw new Exception(reason);}
    public static async Task Run()
    {
        using var offline=new WorkbenchClient(new Offline());offline.Configure("http://127.0.0.1:1",0.5);await offline.Login("admin","1234");
        Check(offline.IsDemo&&offline.Orders.Count==3,"three local synthetic orders");
        int pictures=0,videos=0;
        foreach(var item in offline.Orders.ToArray())
        {
            var order=await offline.Detail(S(item,"id"));
            Check(order["evidence"] is JsonArray{Count:2},"each seed order has two illustrative attachments");
            foreach(var file in order["evidence"]!.AsArray())
            {
                Check(file!["dataBase64"]==null&&S(file,"sha256").Length==64,"seed metadata does not inline originals");
                using var original=await offline.EvidenceFileToTemporary(S(order,"id"),file.AsObject());
                byte[] bytes=await File.ReadAllBytesAsync(original.Path);
                Check(Convert.ToHexString(SHA256.HashData(bytes)).ToLowerInvariant()==S(file,"sha256"),"seed original digest roundtrip");
                Check(long.Parse(S(file,"size"))==bytes.LongLength,"seed original size roundtrip");
                Check(File.Exists(offline.DemoEvidenceThumbnail(S(order,"id"),file.AsObject())),"seed thumbnail or video poster is available");
                if(S(file,"kind")=="video"){videos++;Check(Path.GetFileName(offline.DemoEvidenceThumbnail(S(order,"id"),file.AsObject()))=="DeviceRepair.png","video poster selection");}
                else pictures++;
                var wrong=file.DeepClone().AsObject();wrong["sha256"]=new string('0',64);
                try{using var invalid=await offline.EvidenceFileToTemporary(S(order,"id"),wrong);throw new Exception("bad demo original digest accepted");}catch(InvalidDataException){}
            }
        }
        Check(pictures==4&&videos==2,"seed image/video distribution");
        await offline.Search("",selectedStatus:"pending_intake");
        Check(offline.Orders.Count==1&&S(offline.Orders[0],"id")=="ios-demo-intake","pending intake filter excludes other seed orders");
        Check(!offline.ContainsCurrentOrder("ios-demo-confirm"),"excluded selected detail is not in current list");
        await offline.Refresh();Check(offline.StatusFilter=="pending_intake"&&offline.Orders.Count==1,"refresh preserves local status");
        await offline.Search("主板",selectedStatus:"pending_customer_confirmation");Check(offline.Orders.Count==1,"local search and status combine");
        await offline.Search("门禁",selectedStatus:"pending_intake");await offline.Refresh();Check(offline.Orders.Count==0,"combined empty result survives refresh");
        await offline.Search("SYNTHETIC DEMO",selectedStatus:"");Check(offline.Orders.Count==0,"search does not match attachment metadata");
        for(int index=0;index<32;index++)
        {
            var created=await offline.Create(new(){["device"]="Paging fixture "+index,["description"]="Synthetic pagination"});
            Check(created["evidence"]!.AsArray().Count==0,"new demo order never inherits sample attachments");
        }
        await offline.Search("Paging fixture",selectedStatus:"pending_intake");Check(offline.Orders.Count==30&&offline.More,"local first filtered page");
        await offline.Search(offline.SearchText,true);Check(offline.Orders.Count==32&&!offline.More,"local append applies query/status without duplicates");
        string last=S(offline.Orders[^1],"id");await offline.Detail(last);Check(offline.Orders.Count==32&&offline.ContainsCurrentOrder(last),"opening a later local page retains the loaded selection context");

        var fixture=new FilterFixture();using var live=new WorkbenchClient(fixture);live.Configure("http://127.0.0.1:8098",0.5);await live.Login("admin","1234");
        Check(!live.IsDemo&&live.Orders.All(order=>order!["evidence"]!.AsArray().Count==0),"real bootstrap does not receive sample evidence");
        await live.Search("Queue",selectedStatus:"pending_intake");Check(live.Orders.Count==30&&live.More,"server first filtered page");
        await live.Search(live.SearchText,true);Check(live.Orders.Count==35&&!live.More&&live.Orders.Select(order=>S(order,"id")).Distinct().Count()==35,"server append keeps actual filter and deduplicates");
        Check(fixture.Requests[^1].Status=="pending_intake"&&fixture.Requests[^1].Query=="Queue"&&fixture.Requests[^1].Page==2,"API carries status plus query on pagination");
        await live.Search("Unit 01",true,"pending_execution");Check(live.Orders.Count==1&&fixture.Requests[^1].Page==1,"changing query/status resets append to first page");
        await live.Refresh();Check(live.Orders.Count==1&&live.StatusFilter=="pending_execution"&&live.SearchText=="Unit 01","server refresh preserves both filters");
        fixture.Reject=true;
        try{await live.Search("rejected",selectedStatus:"pending_intake");throw new Exception("rejected filter accepted");}catch(ApiException failure){Check(failure.Status==422,"expected query rejection");}
        Check(live.StatusFilter=="pending_execution"&&live.SearchText=="Unit 01"&&live.Orders.Count==1,"failed query preserves previously applied list and criteria");fixture.Reject=false;
        await live.Search("Queue",selectedStatus:"pending_intake");fixture.DelayPage=true;var old=live.Search(live.SearchText,true);
        await fixture.PageStarted.Task;await live.Search("Queue",selectedStatus:"pending_execution");fixture.ReleasePage.TrySetResult();await old;
        Check(live.StatusFilter=="pending_execution"&&live.Orders.All(order=>S(order,"status")=="pending_execution"),"late page cannot replace latest status filter");
        fixture.Outage=true;await live.Refresh();Check(live.IsDemo&&live.Orders.Count==0&&live.StatusFilter=="pending_execution"&&live.SearchText=="Queue","local fallback preserves current status and search, including empty results");
        fixture.Outage=false;await live.Refresh();Check(!live.IsDemo&&live.Orders.Count==30&&live.Orders.All(order=>!S(order,"id").StartsWith("ios-demo-")),"server recovery replaces demo list without mixing or skipping a page");
        await live.Logout();Check(live.SearchText.Length==0&&live.StatusFilter.Length==0&&!live.More,"logout clears query and pagination context");
        Console.WriteLine("PASS: seed three-order image/video originals/posters/SHA, demo/real isolation, q+status+refresh+pagination, late filter page, rejection rollback, empty results and recovery");
    }
    sealed class Offline:HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request,CancellationToken cancel)=>throw new HttpRequestException("offline");
    }
    sealed class FilterFixture:HttpMessageHandler
    {
        public bool Reject,DelayPage,Outage;
        public readonly List<(int Page,string Query,string Status)> Requests=[];
        public readonly TaskCompletionSource PageStarted=new(TaskCreationOptions.RunContinuationsAsynchronously),ReleasePage=new(TaskCreationOptions.RunContinuationsAsynchronously);
        readonly JsonObject seed=JsonNode.Parse(File.ReadAllText(Path.Combine(AppContext.BaseDirectory,"Resources","demo.json")))!["admin"]!.AsObject();
        JsonObject Actor=>new(){["id"]="filter-admin",["role"]="admin",["companyId"]="filter-company",["authVersion"]=1,["status"]="active"};
        JsonArray Orders()
        {
            var rows=new JsonArray();
            for(int i=0;i<65;i++){var order=seed["orders"]![0]!.DeepClone().AsObject();order["id"]="filter-"+i;order["number"]="Queue "+i.ToString("D2");order["device"]="Unit "+i.ToString("D2");order["status"]=i%2==0||i>59?"pending_intake":"pending_execution";rows.Add(order);}
            return rows;
        }
        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request,CancellationToken cancel)
        {
            string route=request.RequestUri!.AbsolutePath;
            if(route.EndsWith("/healthz"))return Reply(new(){["status"]="ok",["mode"]="synthetic_demo"});
            if(route.EndsWith("/login"))return Reply(new(){["token"]="filter-token",["actor"]=Actor});
            if(Outage)return Reply(new(){["message"]="outage"},503);
            if(route.EndsWith("/logout"))return Reply(new(){["ok"]=true});
            if(route.EndsWith("/orders"))
            {
                if(Reject)return Reply(new(){["message"]="bad query"},422);
                var query=request.RequestUri.Query.TrimStart('?').Split('&').Select(part=>part.Split('=',2)).ToDictionary(part=>Uri.UnescapeDataString(part[0]),part=>part.Length>1?Uri.UnescapeDataString(part[1]):"");
                int page=int.Parse(query["page"]);string q=query["q"],status=query["status"];Requests.Add((page,q,status));
                if(DelayPage&&page==2){PageStarted.TrySetResult();await ReleasePage.Task;}
                var matches=Orders().Where(order=>MatchesOrder(order,q,status,"admin")).ToArray();
                return Reply(new(){["items"]=new JsonArray(matches.Skip((page-1)*30).Take(30).Select(order=>order!.DeepClone()).ToArray()),["page"]=page,["pageSize"]=30,["totalPages"]=(matches.Length+29)/30});
            }
            return Reply(new(){["actor"]=Actor,["orders"]=new JsonArray(Orders().Take(30).Select(order=>order!.DeepClone()).ToArray()),["parts"]=new JsonArray(),["loans"]=new JsonArray(),["metrics"]=new JsonObject(),["orderPage"]=new JsonObject{["totalPages"]=3}});
        }
        static HttpResponseMessage Reply(JsonObject value,int status=200)=>new((HttpStatusCode)status){Content=new StringContent(value.ToJsonString())};
    }
}
