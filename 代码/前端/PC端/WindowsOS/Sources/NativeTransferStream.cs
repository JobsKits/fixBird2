// Created by Jobs. The fixed buffer used by StreamContent also feeds the digest and progress counter.
using System.IO;
using System.Security.Cryptography;

namespace RepairDesktop;

sealed class NativeTransferStream(Stream source,IProgress<NativeTransferProgress>? progress,long total) : Stream
{
    readonly IncrementalHash hash=IncrementalHash.CreateHash(HashAlgorithmName.SHA256);
    long completed;
    long lastProgress=System.Diagnostics.Stopwatch.GetTimestamp();
    public long Completed=>completed;
    public string Digest()=>Convert.ToHexString(hash.GetHashAndReset()).ToLowerInvariant();
    void Observe(ReadOnlySpan<byte> bytes){hash.AppendData(bytes);completed+=bytes.Length;if(bytes.Length==0||completed==total||System.Diagnostics.Stopwatch.GetElapsedTime(lastProgress).TotalMilliseconds>=100){lastProgress=System.Diagnostics.Stopwatch.GetTimestamp();progress?.Report(new(completed,total));}}
    public override int Read(byte[] buffer,int offset,int count){int length=source.Read(buffer,offset,count);Observe(buffer.AsSpan(offset,length));return length;}
    public override async ValueTask<int> ReadAsync(Memory<byte> buffer,CancellationToken cancellationToken=default){int length=await source.ReadAsync(buffer,cancellationToken);Observe(buffer.Span[..length]);return length;}
    public override async Task<int> ReadAsync(byte[] buffer,int offset,int count,CancellationToken cancellationToken){int length=await source.ReadAsync(buffer.AsMemory(offset,count),cancellationToken);Observe(buffer.AsSpan(offset,length));return length;}
    public override bool CanRead=>source.CanRead;
    public override bool CanSeek=>source.CanSeek;
    public override bool CanWrite=>false;
    public override long Length=>source.Length;
    public override long Position{get=>source.Position;set=>source.Position=value;}
    public override long Seek(long offset,SeekOrigin origin)=>source.Seek(offset,origin);
    public override void Flush()=>source.Flush();
    public override void SetLength(long value)=>throw new NotSupportedException();
    public override void Write(byte[] buffer,int offset,int count)=>throw new NotSupportedException();
    protected override void Dispose(bool disposing){if(disposing){hash.Dispose();source.Dispose();}base.Dispose(disposing);}
}

sealed class NativeTemporaryFile : IDisposable
{
    FileStream? stream;
    public string Path { get; }
    public Stream Writer=>stream??throw new ObjectDisposedException(nameof(NativeTemporaryFile));
    public NativeTemporaryFile(string extension)
    {
        Path=System.IO.Path.Combine(System.IO.Path.GetTempPath(),"RepairDesktop-"+Guid.NewGuid()+extension);
        stream=new FileStream(Path,FileMode.CreateNew,FileAccess.ReadWrite,FileShare.Read|FileShare.Delete,65536,FileOptions.Asynchronous);
    }
    public void CompleteWriting(){var current=stream;stream=null;current?.Dispose();}
    public void Dispose(){try{CompleteWriting();}finally{try{File.Delete(Path);}catch(IOException){}}}
}
