using RepairDesktop;
using System.Net;
using System.Security.Cryptography;
using System.Text.Json.Nodes;

static class StreamingSmoke
{
    static void Check(bool condition,string reason){if(!condition)throw new Exception(reason);}
    static async Task<string> Digest(string path){await using var input=File.OpenRead(path);return Convert.ToHexString(await SHA256.HashDataAsync(input)).ToLowerInvariant();}
    static JsonObject Body(JsonObject source,JsonArray files)=>new(){["type"]="mail",["customer"]=WorkbenchClient.S(source,"customer"),["customerId"]=WorkbenchClient.S(source,"customerId"),["companyId"]=WorkbenchClient.S(source,"companyId"),["project"]="Streaming contract fixture",["device"]="Synthetic stream test",["description"]="Isolated native contract fixture",["files"]=files};
    public static async Task Run()
    {
        var path=Path.Combine(Path.GetTempPath(),"RepairDesktop-source-"+Guid.NewGuid()+".mp4");
        var sparse=Path.Combine(Path.GetTempPath(),"RepairDesktop-sparse-"+Guid.NewGuid()+".mp4");
        try
        {
            await using(var writer=new FileStream(path,FileMode.CreateNew,FileAccess.Write,FileShare.None,65536,FileOptions.Asynchronous))
            {
                var block=new byte[65536];RandomNumberGenerator.Fill(block);
                for(int i=0;i<640;i++)await writer.WriteAsync(block);
            }
            using(var writer=new FileStream(sparse,FileMode.CreateNew))writer.SetLength((long)int.MaxValue+65536);
            Check(new NativeDeviceFile(sparse).Size>int.MaxValue,"selection must retain Int64 size without old limits");
            var expected=await Digest(path);
            var handler=new StreamingFixture(path);
            using var online=new WorkbenchClient(handler);online.Configure("http://127.0.0.1:8098",0.5);await online.Login("admin","1234");
            var file=new NativeDeviceFile(path);
            handler.LoseFirstUpload=true;
            try{await online.UploadOrderFile(file);throw new Exception("lost upload response accepted");}catch(HttpRequestException){}
            var reference=await online.UploadOrderFile(file);
            Check(handler.Keys.Count==2&&handler.Keys[0]==handler.Keys[1],"upload lost-response replay must reuse request key");
            Check(handler.MaximumChunk<=65536&&handler.Transferred==file.Size,"upload serialized with bounded 64KiB chunks");
            Check(WorkbenchClient.S(reference,"sha256")==expected&&reference["dataBase64"]==null,"upload reference carries digest without source bytes");
            Check(handler.Mime=="video/mp4"&&handler.FileName==Uri.EscapeDataString(file.Name)&&handler.Authorization=="Bearer fixture-token","raw upload must carry MIME/encoded filename/auth");
            var order=await online.Create(Body(online.Orders[0]!.AsObject(),new JsonArray(reference)));
            string previewPath;
            using(var preview=await online.EvidenceFileToTemporary(WorkbenchClient.S(order,"id"),order["evidence"]![0]!.AsObject())){previewPath=preview.Path;Check(await Digest(preview.Path)==expected,"bounded original download digest");}
            Check(!File.Exists(previewPath)&&File.Exists(path),"preview cleanup owns only its temporary file");
            var wrong=order["evidence"]![0]!.DeepClone().AsObject();wrong["sha256"]=new string('0',64);
            try{using var preview=await online.EvidenceFileToTemporary(WorkbenchClient.S(order,"id"),wrong);throw new Exception("bad original accepted");}catch(InvalidDataException){}
            var changed=new NativeDeviceFile(path);File.SetLastWriteTimeUtc(path,changed.ModifiedUtc.AddSeconds(2));
            try{await online.UploadOrderFile(changed);throw new Exception("changed selection accepted");}catch(IOException){}
            using var cancellation=new CancellationTokenSource();var cancelFile=new NativeDeviceFile(path);
            try{await online.UploadOrderFile(cancelFile,new ImmediateProgress(p=>{if(p.Completed>1024*1024)cancellation.Cancel();}),cancellation.Token);throw new Exception("cancel ignored");}catch(OperationCanceledException){}
            Check(cancelFile.Uploaded==null,"canceled upload cannot become a saved reference");
            handler.BadDigest=true;
            try{await online.UploadOrderFile(new NativeDeviceFile(path));throw new Exception("bad upload response accepted");}catch(InvalidDataException){}
            handler.BadDigest=false;
            using var local=new WorkbenchClient(new OfflineFixture());local.Configure("http://127.0.0.1:1",0.5);await local.Login("admin","1234");
            var localFile=new NativeDeviceFile(path);var localRef=await local.UploadOrderFile(localFile);
            var demoOrder=await local.Create(Body(local.Orders[0]!.AsObject(),new JsonArray(localRef)));
            string demoPreview;
            using(var preview=await local.EvidenceFileToTemporary(WorkbenchClient.S(demoOrder,"id"),demoOrder["evidence"]![0]!.AsObject())){demoPreview=preview.Path;Check(await Digest(preview.Path)==expected,"local demo large disk stream roundtrip");}
            Check(!File.Exists(demoPreview),"demo preview temp released");
            var unbound=await local.UploadOrderFile(new NativeDeviceFile(path));await local.DiscardOrderUpload(unbound);
            try{await local.Create(Body(local.Orders[0]!.AsObject(),new JsonArray(unbound)));throw new Exception("discarded upload reused");}catch(InvalidDataException){}
            Check(WorkbenchClient.IdentityCaption(new JsonObject{["name"]="公司负责人",["role"]="admin"},x=>x)=="公司负责人","header duplicate role suppressed");
            Check(WorkbenchClient.IdentityCaption(new JsonObject{["name"]="Jobs",["role"]="admin"},x=>x)=="Jobs · 公司负责人","header distinct name and role retained");
            Console.WriteLine("PASS: 40MiB bounded raw upload, Int64 selection, MIME/auth/filename, lost-response same-key replay, upload/download digest, cancellation, changed source, local disk demo association and owned temporary cleanup, actor-role caption");
        }
        finally{File.Delete(path);File.Delete(sparse);}
    }
    public static async Task Live(string endpoint,string mediaPath,string smallMediaPath)
    {
        using var client=new WorkbenchClient();client.Configure(endpoint,8);await client.Login("admin","1234");
        var file=new NativeDeviceFile(mediaPath);var reference=await client.UploadOrderFile(file);
        Check(WorkbenchClient.S(reference,"sha256")==await Digest(mediaPath),"live upload digest");
        var order=await client.Create(Body(client.Orders[0]!.AsObject(),new JsonArray(reference)));
        using(var original=await client.EvidenceFileToTemporary(WorkbenchClient.S(order,"id"),order["evidence"]![0]!.AsObject()))Check(await Digest(original.Path)==await Digest(mediaPath),"live encrypted original roundtrip");
        var references=new JsonArray();for(int i=0;i<9;i++)references.Add(await client.UploadOrderFile(new NativeDeviceFile(smallMediaPath)));
        var many=await client.Create(Body(client.Orders[0]!.AsObject(),references));Check(many["evidence"]!.AsArray().Count==9,"live attachment count has no old eight-file cap");
        Console.WriteLine("PASS: live uploadId atomic order association, original streaming SHA256, nine device attachments accepted; source size "+file.Size);
    }
    sealed class ImmediateProgress(Action<NativeTransferProgress> action):IProgress<NativeTransferProgress>{public void Report(NativeTransferProgress value)=>action(value);}
    sealed class OfflineFixture:HttpMessageHandler{protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request,CancellationToken cancellationToken)=>throw new HttpRequestException("offline");}
    sealed class StreamingFixture(string path):HttpMessageHandler
    {
        readonly JsonObject seed=JsonNode.Parse(File.ReadAllText(Path.Combine(AppContext.BaseDirectory,"Resources","demo.json")))!["admin"]!.AsObject();
        readonly Dictionary<string,JsonObject> uploads=[];
        public readonly List<string> Keys=[];
        public long Transferred;
        public int MaximumChunk;
        public bool LoseFirstUpload,BadDigest;
        public string Mime="",FileName="",Authorization="";
        JsonObject Actor=>new(){["id"]="real-admin",["role"]="admin",["companyId"]="real-company",["authVersion"]=1,["status"]="active",["name"]="fixture",["username"]="admin"};
        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request,CancellationToken cancellationToken)
        {
            string route=request.RequestUri!.AbsolutePath;
            if(route.EndsWith("/healthz"))return Response(200,new JsonObject{["status"]="ok",["mode"]="synthetic_demo"});
            if(route.EndsWith("/login"))return Response(200,new JsonObject{["token"]="fixture-token",["actor"]=Actor});
            if(route.EndsWith("/order-uploads"))
            {
                string key=request.Headers.GetValues("Idempotency-Key").Single();Keys.Add(key);
                if(uploads.TryGetValue(key,out var cached))return Response(201,cached);
                Mime=request.Content!.Headers.ContentType!.MediaType!;FileName=request.Headers.GetValues("X-File-Name").Single();Authorization=request.Headers.Authorization!.ToString();
                using var sink=new DigestSink(cancellationToken,n=>MaximumChunk=Math.Max(MaximumChunk,n));
                await request.Content.CopyToAsync(sink,cancellationToken);Transferred=sink.Length;
                var meta=new JsonObject{["id"]=Guid.NewGuid().ToString(),["name"]=Uri.UnescapeDataString(FileName),["mime"]=Mime,["size"]=sink.Length,["sha256"]=BadDigest?new string('0',64):sink.Digest()};uploads[key]=meta;
                if(LoseFirstUpload){LoseFirstUpload=false;throw new HttpRequestException("response lost");}
                return Response(201,meta);
            }
            if(route.Contains("/evidence/"))return new(HttpStatusCode.OK){Content=new StreamContent(new FileStream(path,FileMode.Open,FileAccess.Read,FileShare.Read,65536,FileOptions.Asynchronous))};
            if(route.EndsWith("/orders")&&request.Method==HttpMethod.Post)
            {
                var payload=JsonNode.Parse(await request.Content!.ReadAsStringAsync(cancellationToken))!.AsObject();
                var order=seed["orders"]![0]!.DeepClone().AsObject();foreach(var pair in payload)if(pair.Key!="files")order[pair.Key]=pair.Value?.DeepClone();order["id"]="new-order";order["isSummary"]=false;
                var evidence=new JsonArray();foreach(var reference in payload["files"]!.AsArray()){var metadata=uploads.Values.Single(x=>WorkbenchClient.S(x,"id")==WorkbenchClient.S(reference,"uploadId")).DeepClone().AsObject();metadata["kind"]="video";evidence.Add(metadata);}order["evidence"]=evidence;
                return Response(201,order);
            }
            return Response(200,new JsonObject{["actor"]=Actor,["orders"]=seed["orders"]!.DeepClone(),["parts"]=seed["parts"]!.DeepClone(),["loans"]=new JsonArray(),["metrics"]=new JsonObject(),["orderPage"]=new JsonObject{["totalPages"]=1}});
        }
        static HttpResponseMessage Response(int status,JsonNode value)=>new((HttpStatusCode)status){Content=new StringContent(value.ToJsonString())};
    }
    sealed class DigestSink(CancellationToken cancellationToken,Action<int> observed):Stream
    {
        readonly IncrementalHash hash=IncrementalHash.CreateHash(HashAlgorithmName.SHA256);long length;
        public string Digest()=>Convert.ToHexString(hash.GetHashAndReset()).ToLowerInvariant();
        public override void Write(byte[] buffer,int offset,int count){cancellationToken.ThrowIfCancellationRequested();observed(count);hash.AppendData(buffer.AsSpan(offset,count));length+=count;}
        public override ValueTask WriteAsync(ReadOnlyMemory<byte> buffer,CancellationToken cancel=default){cancel.ThrowIfCancellationRequested();cancellationToken.ThrowIfCancellationRequested();observed(buffer.Length);hash.AppendData(buffer.Span);length+=buffer.Length;return ValueTask.CompletedTask;}
        public override bool CanRead=>false;public override bool CanSeek=>false;public override bool CanWrite=>true;public override long Length=>length;public override long Position{get=>length;set=>throw new NotSupportedException();}
        public override void Flush(){}public override int Read(byte[] b,int o,int n)=>throw new NotSupportedException();public override long Seek(long o,SeekOrigin s)=>throw new NotSupportedException();public override void SetLength(long n)=>throw new NotSupportedException();
        protected override void Dispose(bool disposing){if(disposing)hash.Dispose();base.Dispose(disposing);}
    }
}
