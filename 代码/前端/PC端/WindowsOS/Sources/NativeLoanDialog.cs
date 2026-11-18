// Created by Jobs. Loan evidence uses original local images, previewed before any API write.
using System.IO;
using System.Text.Json.Nodes;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using Microsoft.Win32;

namespace RepairDesktop;

sealed class NativeLoanDialog : Window
{
    readonly MainWindow host;
    readonly JsonObject? loan;
    readonly string action;
    readonly string context;
    readonly StackPanel gallery=new();
    readonly TextBlock error=new(){TextWrapping=TextWrapping.Wrap,Foreground=Brushes.IndianRed};
    readonly List<Attachment> pictures=[];
    readonly ComboBox orders=new(){DisplayMemberPath="Value",SelectedValuePath="Key"};
    readonly ComboBox parts=new(){DisplayMemberPath="Value",SelectedValuePath="Key"};
    readonly ComboBox condition=new(){DisplayMemberPath="Value",SelectedValuePath="Key"};
    readonly TextBox quantity=new(){Text="1",Padding=new Thickness(8)};
    readonly TextBox borrower=new(){Padding=new Thickness(8)};
    readonly TextBox note=new(){Padding=new Thickness(8),AcceptsReturn=true,MinHeight=60,TextWrapping=TextWrapping.Wrap};
    readonly DatePicker due=new(){SelectedDate=DateTime.Today.AddDays(7)};
    bool saving;
    public string? SavedId { get; private set; }
    public NativeLoanDialog(MainWindow host,string action,JsonObject? loan=null)
    {
        this.host=host;this.action=action;this.loan=loan;context=host.Client.Context;
        Title=host.T(action=="borrow"?"借出登记":action=="return"?"归还":"补录图片凭据");Width=720;MaxHeight=760;SizeToContent=SizeToContent.Height;Owner=host;Background=host.Background;Foreground=host.Foreground;Language=host.Language;
        Closing+=(_,e)=>e.Cancel=saving;
        var panel=new StackPanel{Margin=new Thickness(24)};panel.Children.Add(host.Label(Title,23));
        var grid=new Grid();grid.ColumnDefinitions.Add(new());grid.ColumnDefinitions.Add(new());
        void Field(string title,FrameworkElement input,int row,int column){while(grid.RowDefinitions.Count<=row)grid.RowDefinitions.Add(new(){Height=GridLength.Auto});var group=new StackPanel{Margin=new Thickness(column==0?0:10,0,column==0?10:0,12)};group.Children.Add(host.Label(host.T(title)));group.Children.Add(input);Grid.SetRow(group,row);Grid.SetColumn(group,column);grid.Children.Add(group);}
        if(action=="borrow")
        {
            orders.ItemsSource=host.Client.Orders.Select(x=>new KeyValuePair<string,string>(WorkbenchClient.S(x,"id"),WorkbenchClient.S(x,"number"))).ToList();
            parts.ItemsSource=host.Client.Parts.Select(x=>new KeyValuePair<string,string>(WorkbenchClient.S(x,"id"),WorkbenchClient.S(x,"name"))).ToList();
            borrower.Text=WorkbenchClient.S(host.Client.Actor,"id");Field("工单",orders,0,0);Field("配件",parts,0,1);Field("数量",quantity,1,0);Field("借用人账号",borrower,1,1);Field("归还期限",due,2,0);
        }
        else
        {
            panel.Children.Add(host.Label(WorkbenchClient.S(loan,"partName")+" · "+host.T("尚欠")+" "+WorkbenchClient.I(loan,"outstanding")));
            quantity.Text=action=="return"?WorkbenchClient.S(loan,"outstanding"):WorkbenchClient.S(loan,"quantity");
            condition.ItemsSource=new[]{new KeyValuePair<string,string>("good",host.T("完好归还")),new("quarantine",host.T("隔离归还"))};condition.SelectedIndex=0;
            Field("数量",quantity,0,0);if(action=="return")Field("归还状态",condition,0,1);
        }
        panel.Children.Add(grid);panel.Children.Add(host.Label(host.T("备注")));panel.Children.Add(note);
        panel.Children.Add(host.Label(host.T("图片凭据"),16));panel.Children.Add(host.Label(host.T("每次至少选择一张图片，支持 PNG、JPEG、GIF。"),12));
        panel.Children.Add(host.Button("选择图片",Choose));panel.Children.Add(gallery);panel.Children.Add(error);
        var actions=new StackPanel{Orientation=Orientation.Horizontal,HorizontalAlignment=HorizontalAlignment.Right};
        var cancel=host.Button("取消",Close);var submit=host.Button("确认提交",()=>{});actions.Children.Add(cancel);actions.Children.Add(submit);panel.Children.Add(actions);
        submit.Click+=async(_,_)=>
        {
            if(saving)return;saving=true;panel.IsEnabled=false;error.Text="";
            try
            {
                if(context!=host.Client.Context)throw new Exception(host.T("身份或数据来源已改变，请重新打开当前单据。"));
                if(!int.TryParse(quantity.Text,out var count)||count<1)throw new Exception(host.T("请输入有效整数"));
                if(pictures.Count==0)throw new Exception(host.T("请至少选择一张图片凭据"));
                var files=new JsonArray(pictures.Select(x=>(JsonNode)new JsonObject{["name"]=x.Name,["mime"]=x.Mime,["dataBase64"]=Convert.ToBase64String(x.Bytes)}).ToArray());
                JsonObject body;string path;
                if(action=="borrow")
                {
                    if(orders.SelectedValue==null||parts.SelectedValue==null||borrower.Text.Trim().Length==0)throw new Exception(host.T("请核对填写内容"));
                    body=new(){["orderId"]=orders.SelectedValue.ToString(),["partId"]=parts.SelectedValue.ToString(),["quantity"]=count,["borrowerId"]=borrower.Text.Trim(),["dueAt"]=new DateTimeOffset(DateTime.SpecifyKind(due.SelectedDate??DateTime.Today,DateTimeKind.Unspecified).AddHours(23).AddMinutes(59).AddSeconds(59),TimeSpan.FromHours(8)).ToString("O"),["note"]=note.Text,["attachments"]=files};path="/loans";
                }
                else if(action=="return")
                {
                    if(count>WorkbenchClient.I(loan,"outstanding"))throw new Exception(host.T("请输入有效整数"));
                    body=new(){["type"]="return",["version"]=WorkbenchClient.I(loan,"version"),["payload"]=new JsonObject{["quantity"]=count,["condition"]=condition.SelectedValue?.ToString(),["note"]=note.Text,["attachments"]=files}};path="/loans/"+WorkbenchClient.S(loan,"id")+"/actions";
                }
                else {body=new(){["version"]=WorkbenchClient.I(loan,"version"),["stage"]="borrow",["quantity"]=count,["note"]=note.Text,["attachments"]=files};path="/loans/"+WorkbenchClient.S(loan,"id")+"/files";}
                var result=await host.Client.WriteLoan(path,body);SavedId=WorkbenchClient.S(result,"id");saving=false;DialogResult=true;Close();
            }
            catch(Exception failure){error.Text=host.T(failure.Message);}
            finally{saving=false;panel.IsEnabled=true;}
        };
        Content=new ScrollViewer{Content=panel,VerticalScrollBarVisibility=ScrollBarVisibility.Auto};
    }
    void Choose()
    {
        var chooser=new OpenFileDialog{Filter="PNG / JPEG / GIF|*.png;*.jpg;*.jpeg;*.gif",Multiselect=true,CheckFileExists=true};
        if(chooser.ShowDialog(this)!=true)return;
        try
        {
            long total=(loan?["files"] as JsonArray??[]).Sum(x=>(long)WorkbenchClient.I(x,"size"))+pictures.Sum(x=>(long)x.Bytes.Length);
            int count=(loan?["files"] as JsonArray??[]).Count+pictures.Count;
            foreach(var path in chooser.FileNames)
            {
                var info=new FileInfo(path);if(info.Length<=0||info.Length>8*1024*1024||++count>8||(total+=info.Length)>32*1024*1024)throw new Exception(host.T("图片最多8张，单张8MiB，总计32MiB"));
                var bytes=File.ReadAllBytes(path);using var stream=new MemoryStream(bytes);var decoder=BitmapDecoder.Create(stream,BitmapCreateOptions.PreservePixelFormat,BitmapCacheOption.OnLoad);
                string mime=decoder switch{PngBitmapDecoder=>"image/png",JpegBitmapDecoder=>"image/jpeg",GifBitmapDecoder=>"image/gif",_=>throw new Exception(host.T("仅支持 PNG、JPEG、GIF 图片"))};
                pictures.Add(new(Path.GetFileName(path),mime,bytes));
            }
            RenderGallery();error.Text="";
        }
        catch(Exception failure){error.Text=host.T(failure.Message);RenderGallery();}
    }
    void RenderGallery()
    {
        gallery.Children.Clear();foreach(var file in pictures.ToArray())
        {
            var row=new DockPanel{Margin=new Thickness(0,6,0,6)};var remove=host.Button("删除",()=>{pictures.Remove(file);RenderGallery();});DockPanel.SetDock(remove,Dock.Right);row.Children.Add(remove);
            var image=new Image{Source=Decode(file.Bytes),Width=92,Height=72,Stretch=Stretch.Uniform,Margin=new Thickness(0,0,12,0)};DockPanel.SetDock(image,Dock.Left);row.Children.Add(image);row.Children.Add(host.Label(file.Name));gallery.Children.Add(row);
        }
    }
    internal static BitmapSource Decode(byte[] bytes){using var stream=new MemoryStream(bytes);var image=new BitmapImage();image.BeginInit();image.CacheOption=BitmapCacheOption.OnLoad;image.StreamSource=stream;image.EndInit();image.Freeze();return image;}
    sealed record Attachment(string Name,string Mime,byte[] Bytes);
}
