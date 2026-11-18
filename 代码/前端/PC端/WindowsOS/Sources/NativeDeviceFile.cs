// Created by Jobs. Selection retains file metadata, never the entire device attachment in memory.
using System.IO;
using System.Text.Json.Nodes;

namespace RepairDesktop;

sealed class NativeDeviceFile
{
    public string Path { get; }
    public string Name { get; }
    public string Mime { get; }
    public long Size { get; }
    public DateTime ModifiedUtc { get; }
    public string RequestKey { get; }=Guid.NewGuid().ToString();
    public JsonObject? Uploaded { get; set; }
    public string UploadContext { get; set; }="";
    public NativeDeviceFile(string path)
    {
        var info=new FileInfo(path);
        if(!info.Exists||info.Length<1)throw new IOException("请选择有效设备图片或视频原件");
        Path=info.FullName;Name=info.Name;Size=info.Length;ModifiedUtc=info.LastWriteTimeUtc;
        Mime=info.Extension.ToLowerInvariant() switch{".png"=>"image/png",".jpg" or ".jpeg"=>"image/jpeg",".gif"=>"image/gif",".webp"=>"image/webp",".mp4"=>"video/mp4",".mov"=>"video/quicktime",".webm"=>"video/webm",_=>throw new IOException("请选择有效设备图片或视频原件")};
    }
    public void AssertUnchanged()
    {
        var current=new FileInfo(Path);
        if(!current.Exists||current.Length!=Size||current.LastWriteTimeUtc!=ModifiedUtc)throw new IOException("文件已更改，请重新选择");
    }
}

sealed record NativeTransferProgress(long Completed,long Total);
