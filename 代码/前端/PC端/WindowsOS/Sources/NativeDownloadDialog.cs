// Created by Jobs. A cancellable native progress window owns the preview temporary file.
using System.Text.Json.Nodes;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;

namespace RepairDesktop;

sealed class NativeDownloadDialog : Window,IDisposable
{
    readonly CancellationTokenSource cancellation=new();
    readonly MainWindow host;
    readonly string context,orderId;
    readonly JsonObject evidence;
    readonly TextBlock status=new(){TextWrapping=TextWrapping.Wrap};
    readonly ProgressBar progress=new(){Minimum=0,Maximum=100,Height=8,Margin=new Thickness(0,14,0,14),IsIndeterminate=true};
    readonly TextBlock error=new(){TextWrapping=TextWrapping.Wrap,Foreground=Brushes.IndianRed};
    bool closed;
    public NativeTemporaryFile? File {get;private set;}
    public NativeDownloadDialog(MainWindow host,string orderId,JsonObject evidence)
    {
        this.host=host;this.orderId=orderId;this.evidence=evidence;context=host.Client.Context;
        Title=host.T("正在下载原件");Owner=host;Width=470;SizeToContent=SizeToContent.Height;ResizeMode=ResizeMode.NoResize;Background=host.Background;Foreground=host.Foreground;Language=host.Language;WindowStartupLocation=WindowStartupLocation.CenterOwner;
        var panel=new StackPanel{Margin=new Thickness(24)};panel.Children.Add(host.Label(WorkbenchClient.S(evidence,"name"),17));panel.Children.Add(status);panel.Children.Add(progress);panel.Children.Add(error);
        panel.Children.Add(host.Button("取消下载",()=>{cancellation.Cancel();Close();}));Content=panel;
        Closed+=(_,_)=>{closed=true;cancellation.Cancel();};Loaded+=async(_,_)=>await Download();
    }
    async Task Download()
    {
        try
        {
            var updates=new Progress<NativeTransferProgress>(value=>{if(closed)return;status.Text=host.T("正在下载原件")+" · "+value.Completed.ToString("N0")+" B";progress.IsIndeterminate=value.Total<=0;if(value.Total>0)progress.Value=100d*value.Completed/value.Total;});
            var downloaded=await host.Client.EvidenceFileToTemporary(orderId,evidence,updates,cancellation.Token);
            if(closed||host.Client.Context!=context){downloaded.Dispose();return;}
            File=downloaded;DialogResult=true;Close();
        }
        catch(OperationCanceledException){if(!closed){status.Text=host.T("下载已取消");progress.Visibility=Visibility.Collapsed;}}
        catch(Exception failure){if(!closed){error.Text=host.T(failure.Message);progress.Visibility=Visibility.Collapsed;}}
    }
    public void Dispose(){cancellation.Cancel();cancellation.Dispose();File?.Dispose();File=null;}
}
