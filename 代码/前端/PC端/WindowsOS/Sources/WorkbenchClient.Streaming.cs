// Created by Jobs. Device media always travels as a bounded-buffer file stream, never an inline Base64 request.
using System.IO;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text.Json.Nodes;

namespace RepairDesktop;

sealed partial class WorkbenchClient : IDisposable
{
    CancellationTokenSource transfers=new();
    bool disposed;
    readonly Dictionary<string,(JsonObject Meta,NativeTemporaryFile File,string Context)> stagedDeviceUploads=[];
    readonly Dictionary<string,NativeTemporaryFile> demoDeviceEvidence=[];
    void ResetTransfers()
    {
        transfers.Cancel();transfers.Dispose();transfers=new();
        foreach(var file in stagedDeviceUploads.Values.Select(x=>x.File).Concat(demoDeviceEvidence.Values).Distinct())file.Dispose();
        stagedDeviceUploads.Clear();demoDeviceEvidence.Clear();
    }
    public void Dispose(){if(disposed)return;disposed=true;ResetTransfers();transfers.Dispose();http.Dispose();}
    public async Task<JsonObject> UploadOrderFile(NativeDeviceFile file,IProgress<NativeTransferProgress>? progress=null,CancellationToken cancellationToken=default)
    {
        file.AssertUnchanged();
        if(file.Uploaded!=null&&file.UploadContext==Context)return file.Uploaded.DeepClone().AsObject();
        if(Actor==null)throw new ApiException(401,"请先登录");
        if(IsDemo)await Probe();
        string context=Context;int captured=epoch;
        using var cancel=CancellationTokenSource.CreateLinkedTokenSource(cancellationToken,transfers.Token);
        await using var input=new FileStream(file.Path,FileMode.Open,FileAccess.Read,FileShare.Read,65536,FileOptions.Asynchronous|FileOptions.SequentialScan);
        using var tracked=new NativeTransferStream(input,progress,file.Size);
        JsonObject metadata;
        if(IsDemo)
        {
            NativeTemporaryFile? temporary=new(System.IO.Path.GetExtension(file.Path));
            try
            {
                await tracked.CopyToAsync(temporary.Writer,65536,cancel.Token);await temporary.Writer.FlushAsync(cancel.Token);temporary.CompleteWriting();
                if(captured!=epoch||context!=Context)throw new Exception("身份或数据来源已改变，请重新打开当前单据。");
                metadata=new(){["id"]="ios-demo-upload-"+Guid.NewGuid(),["name"]=file.Name,["mime"]=file.Mime,["size"]=tracked.Completed,["sha256"]=tracked.Digest()};
                stagedDeviceUploads.Add(S(metadata,"id"),(metadata.DeepClone().AsObject(),temporary,context));temporary=null;
            }
            finally{temporary?.Dispose();}
        }
        else
        {
            using var request=new HttpRequestMessage(HttpMethod.Post,Endpoint+"/api/v38/order-uploads");
            request.Headers.Authorization=new("Bearer",token);request.Headers.Add("Idempotency-Key",file.RequestKey);request.Headers.Add("X-File-Name",Uri.EscapeDataString(file.Name));
            request.Content=new StreamContent(tracked,65536);request.Content.Headers.ContentType=new MediaTypeHeaderValue(file.Mime);request.Content.Headers.ContentLength=file.Size;
            using var response=await http.SendAsync(request,HttpCompletionOption.ResponseHeadersRead,cancel.Token);
            metadata=await TransferResponse(response,captured,cancel.Token);
            string digest;
            if(tracked.Completed==file.Size)digest=tracked.Digest();
            else
            {
                await using var verification=new FileStream(file.Path,FileMode.Open,FileAccess.Read,FileShare.Read,65536,FileOptions.Asynchronous|FileOptions.SequentialScan);
                digest=Convert.ToHexString(await SHA256.HashDataAsync(verification,cancel.Token)).ToLowerInvariant();
            }
            if(S(metadata,"id").Length==0||S(metadata,"name")!=file.Name||S(metadata,"mime")!=file.Mime||metadata["size"] is not JsonValue size||!size.TryGetValue<long>(out var length)||length!=file.Size||S(metadata,"sha256")!=digest)throw new InvalidDataException("写响应未通过校验");
        }
        if(captured!=epoch||context!=Context)throw new Exception("身份或数据来源已改变，请重新打开当前单据。");
        file.Uploaded=new(){["uploadId"]=S(metadata,"id"),["name"]=file.Name,["mime"]=file.Mime,["size"]=file.Size,["sha256"]=S(metadata,"sha256")};file.UploadContext=context;
        progress?.Report(new(file.Size,file.Size));return file.Uploaded.DeepClone().AsObject();
    }
    public async Task DiscardOrderUpload(JsonObject reference,CancellationToken cancellationToken=default)
    {
        string id=S(reference,"uploadId");if(id.Length==0)return;
        if(stagedDeviceUploads.Remove(id,out var local)){local.File.Dispose();return;}
        if(id.StartsWith("ios-demo-",StringComparison.Ordinal))return;
        int captured=epoch;using var cancel=CancellationTokenSource.CreateLinkedTokenSource(cancellationToken,transfers.Token);
        using var request=new HttpRequestMessage(HttpMethod.Delete,Endpoint+"/api/v38/order-uploads/"+Uri.EscapeDataString(id));request.Headers.Authorization=new("Bearer",token);
        using var response=await http.SendAsync(request,HttpCompletionOption.ResponseHeadersRead,cancel.Token);
        if(!response.IsSuccessStatusCode)await TransferResponse(response,captured,cancel.Token);
    }
    public async Task<NativeTemporaryFile> EvidenceFileToTemporary(string orderId,JsonObject evidence,IProgress<NativeTransferProgress>? progress=null,CancellationToken cancellationToken=default)
    {
        string id=S(evidence,"id"),mime=S(evidence,"mime");int captured=epoch;string context=Context;
        using var cancel=CancellationTokenSource.CreateLinkedTokenSource(cancellationToken,transfers.Token);
        var output=new NativeTemporaryFile(mime=="video/mp4"?".mp4":mime=="video/quicktime"?".mov":mime=="video/webm"?".webm":System.IO.Path.GetExtension(S(evidence,"name")));
        try
        {
            if(IsDemo)
            {
                await Probe();
                if(demoDeviceEvidence.TryGetValue(orderId+":"+id,out var local))
                {
                    await using var input=new FileStream(local.Path,FileMode.Open,FileAccess.Read,FileShare.ReadWrite|FileShare.Delete,65536,FileOptions.Asynchronous|FileOptions.SequentialScan);
                    using var tracked=new NativeTransferStream(input,progress,input.Length);await tracked.CopyToAsync(output.Writer,65536,cancel.Token);
                    if(S(evidence,"sha256").Length>0&&tracked.Digest()!=S(evidence,"sha256"))throw new InvalidDataException("文件原件校验失败");
                }
                else if(demoOrderFiles.TryGetValue(orderId+":"+id,out var legacy))
                {
                    if(S(evidence,"sha256").Length>0&&Convert.ToHexString(SHA256.HashData(legacy)).ToLowerInvariant()!=S(evidence,"sha256"))throw new InvalidDataException("文件原件校验失败");
                    await output.Writer.WriteAsync(legacy,cancel.Token);
                }
                else throw new InvalidDataException("暂时没有记录");
            }
            else
            {
                using var request=new HttpRequestMessage(HttpMethod.Get,Endpoint+"/api/v38/orders/"+Uri.EscapeDataString(orderId)+"/evidence/"+Uri.EscapeDataString(id));request.Headers.Authorization=new("Bearer",token);
                using var response=await http.SendAsync(request,HttpCompletionOption.ResponseHeadersRead,cancel.Token);
                if(!response.IsSuccessStatusCode)await TransferResponse(response,captured,cancel.Token);
                await using var source=await response.Content.ReadAsStreamAsync(cancel.Token);
                using var tracked=new NativeTransferStream(source,progress,response.Content.Headers.ContentLength??0);await tracked.CopyToAsync(output.Writer,65536,cancel.Token);
                if(S(evidence,"sha256").Length>0&&tracked.Digest()!=S(evidence,"sha256"))throw new InvalidDataException("文件原件校验失败");
            }
            await output.Writer.FlushAsync(cancel.Token);output.CompleteWriting();
            if(captured!=epoch||context!=Context)throw new Exception("身份或数据来源已改变，请重新打开当前单据。");
            return output;
        }
        catch{output.Dispose();throw;}
    }
    async Task<JsonObject> TransferResponse(HttpResponseMessage response,int captured,CancellationToken cancellationToken)
    {
        JsonObject? value=null;try{value=JsonNode.Parse(await response.Content.ReadAsStringAsync(cancellationToken))?.AsObject();}catch(System.Text.Json.JsonException){}
        if(captured!=epoch)throw new Exception("身份或数据来源已改变，请重新打开当前单据。");
        if(!response.IsSuccessStatusCode){if(response.StatusCode==HttpStatusCode.Unauthorized)Clear();throw new ApiException((int)response.StatusCode,S(value,"message").Length>0?S(value,"message"):"HTTP "+(int)response.StatusCode);}
        return value??throw new InvalidDataException("写响应未通过校验");
    }
    List<(string UploadId,JsonObject Evidence,NativeTemporaryFile File)> ResolveDemoDeviceUploads(JsonArray references)
    {
        var result=new List<(string,JsonObject,NativeTemporaryFile)>();var seen=new HashSet<string>();
        foreach(var reference in references)
        {
            string id=S(reference,"uploadId");
            if(!seen.Add(id)||!stagedDeviceUploads.TryGetValue(id,out var stored)||stored.Context!=Context)throw new InvalidDataException("设备附件提交内容无法核对");
            foreach(var key in new[]{"name","mime","size","sha256"})if(reference?[key]!=null&&S(reference,key)!=S(stored.Meta,key))throw new InvalidDataException("设备附件提交内容无法核对");
            var meta=stored.Meta.DeepClone().AsObject();meta["id"]="ios-demo-evidence-"+Guid.NewGuid();meta["kind"]=S(meta,"mime").StartsWith("video/",StringComparison.Ordinal)?"video":"image";meta["uploaderId"]=S(Actor,"id");meta["createdAt"]=DateTimeOffset.UtcNow.ToString("O");meta["stage"]="pending_intake";meta["public"]=true;
            result.Add((id,meta,stored.File));
        }
        return result;
    }
}
