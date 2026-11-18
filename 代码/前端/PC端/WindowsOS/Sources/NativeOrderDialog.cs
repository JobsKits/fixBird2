// Created by Jobs. Customer/account/company selections come from the controlled service directory.
using System.IO;
using System.Text.Json.Nodes;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using Microsoft.Win32;
using static RepairDesktop.WorkbenchClient;

namespace RepairDesktop;

sealed class NativeOrderDialog : Window
{
    readonly MainWindow host;
    readonly string context;
    readonly ComboBox customers=Choice(),accounts=Choice(),companies=Choice(),type=Choice();
    readonly TextBox project=new(){Padding=new Thickness(8)},device=new(){Padding=new Thickness(8)},description=new(){Padding=new Thickness(8),AcceptsReturn=true,TextWrapping=TextWrapping.Wrap,MinHeight=66};
    readonly StackPanel attachmentsView=new();
    readonly TextBlock error=new(){TextWrapping=TextWrapping.Wrap,Foreground=Brushes.IndianRed};
    readonly List<NativeDeviceFile> files=[];
    readonly TextBlock transferStatus=new(){TextWrapping=TextWrapping.Wrap};
    CancellationTokenSource? uploadCancellation;
    JsonObject? frozenSubmission;
    bool committing,closeAfterCancellation;
    bool changing,saving;
    public JsonObject? Saved { get;private set; }
    static ComboBox Choice()=>new(){DisplayMemberPath="Value",SelectedValuePath="Key",MinHeight=34};
    JsonArray Groups=>host.Client.CustomerDirectory["customers"] as JsonArray??[];
    JsonObject? SelectedCustomer=>Groups.FirstOrDefault(x=>S(x,"id")==customers.SelectedValue?.ToString())?.AsObject();
    JsonArray CustomerAccounts=>SelectedCustomer?["accounts"] as JsonArray??[];
    JsonArray CustomerCompanies=>SelectedCustomer?["companies"] as JsonArray??[];
    public NativeOrderDialog(MainWindow host)
    {
        this.host=host;context=host.Client.Context;Title=host.T("新建工单");Owner=host;Width=820;MaxHeight=760;SizeToContent=SizeToContent.Height;Background=host.Background;Foreground=host.Foreground;Language=host.Language;
        Closing+=(_,e)=>{if(saving){e.Cancel=true;if(!committing){closeAfterCancellation=true;uploadCancellation?.Cancel();}}};
        Closed+=async(_,_)=>{if(Saved==null&&context==host.Client.Context)foreach(var file in files)if(file.Uploaded!=null)try{await host.Client.DiscardOrderUpload(file.Uploaded);}catch{}};
        var root=new StackPanel{Margin=new Thickness(24)};root.Children.Add(host.Label(Title,24));
        var fields=new Grid();fields.ColumnDefinitions.Add(new());fields.ColumnDefinitions.Add(new());
        void Field(string title,FrameworkElement input,int row,int column){while(fields.RowDefinitions.Count<=row)fields.RowDefinitions.Add(new(){Height=GridLength.Auto});var stack=new StackPanel{Margin=new Thickness(column==0?0:10,0,column==0?10:0,13)};stack.Children.Add(host.Label(host.T(title)));stack.Children.Add(input);Grid.SetRow(stack,row);Grid.SetColumn(stack,column);fields.Children.Add(stack);}
        FrameworkElement DirectoryChoice(ComboBox choice,string operation)
        {
            var wrap=new DockPanel();var add=host.Button("新建",()=>NewDirectory(operation));add.Margin=new Thickness(7,0,0,0);add.IsEnabled=B(host.Client.CustomerDirectory,"canManage");DockPanel.SetDock(add,Dock.Right);wrap.Children.Add(add);wrap.Children.Add(choice);return wrap;
        }
        Field("客户",DirectoryChoice(customers,"customer"),0,0);Field("客户账号",DirectoryChoice(accounts,"account"),0,1);Field("企业编号",DirectoryChoice(companies,"company"),1,0);
        type.ItemsSource=new[]{new KeyValuePair<string,string>("mail",host.T("寄修")),new("onsite",host.T("上门")),new("sale",host.T("销售"))};type.SelectedIndex=0;Field("类型",type,1,1);Field("项目",project,2,0);Field("设备",device,2,1);
        root.Children.Add(fields);root.Children.Add(host.Label(host.T("故障说明")));root.Children.Add(description);
        root.Children.Add(host.Label(host.T("图片与视频"),16));
        var choose=host.Button("选择图片或视频",ChooseMedia);root.Children.Add(choose);
        var drop=new Border{BorderBrush=Brushes.Gray,BorderThickness=new Thickness(1),CornerRadius=new CornerRadius(7),Padding=new Thickness(18),MinHeight=70,AllowDrop=true,Child=new TextBlock{Text=host.T("将图片或视频拖到这里"),TextWrapping=TextWrapping.Wrap}};
        drop.DragOver+=(_,e)=>{e.Effects=!saving&&frozenSubmission==null&&e.Data.GetDataPresent(DataFormats.FileDrop)?DragDropEffects.Copy:DragDropEffects.None;e.Handled=true;};
        drop.Drop+=(_,e)=>{if(!saving&&frozenSubmission==null&&e.Data.GetData(DataFormats.FileDrop) is string[] paths)AddMedia(paths);e.Handled=true;};
        root.Children.Add(drop);root.Children.Add(attachmentsView);root.Children.Add(transferStatus);root.Children.Add(error);
        var actions=new StackPanel{Orientation=Orientation.Horizontal,HorizontalAlignment=HorizontalAlignment.Right};var cancel=host.Button("取消",()=>{if(saving&&!committing)uploadCancellation?.Cancel();else if(!saving)Close();});actions.Children.Add(cancel);var submit=host.Button("确认提交",()=>{});actions.Children.Add(submit);root.Children.Add(actions);
        submit.Click+=async(_,_)=>
        {
            if(saving)return;saving=true;committing=false;uploadCancellation=new();SetEditing(false);error.Text="";
            try
            {
                if(context!=host.Client.Context)throw new Exception(host.T("身份或数据来源已改变，请重新打开当前单据。"));
                JsonObject body;
                if(frozenSubmission!=null)body=frozenSubmission.DeepClone().AsObject();
                else
                {
                    var customer=SelectedCustomer;var account=CustomerAccounts.FirstOrDefault(x=>S(x,"id")==accounts.SelectedValue?.ToString());
                    if(customer==null||account==null||S(account,"companyId")!=companies.SelectedValue?.ToString()||device.Text.Trim().Length==0||description.Text.Trim().Length==0)throw new Exception(host.T("请核对填写内容"));
                    body=new(){["type"]=type.SelectedValue?.ToString(),["customer"]=S(customer,"name"),["customerId"]=S(account,"id"),["companyId"]=S(account,"companyId"),["project"]=project.Text,["device"]=device.Text,["description"]=description.Text};
                    if(files.Count>0)
                    {
                        var references=new JsonArray();
                        foreach(var file in files)
                        {
                            var progress=new Progress<NativeTransferProgress>(value=>transferStatus.Text=host.T("正在上传设备附件")+" · "+file.Name+" · "+(value.Total>0?(100d*value.Completed/value.Total).ToString("F0")+"%":value.Completed.ToString("N0")));
                            references.Add(await host.Client.UploadOrderFile(file,progress,uploadCancellation.Token));
                        }
                        body["files"]=references;
                    }
                    frozenSubmission=body.DeepClone().AsObject();
                }
                committing=true;cancel.IsEnabled=false;transferStatus.Text=host.T("正在提交工单");
                Saved=await host.Client.Create(body);saving=false;DialogResult=true;Close();
            }
            catch(OperationCanceledException){transferStatus.Text="";error.Text=host.T("上传已取消");}
            catch(Exception failure){transferStatus.Text="";if(failure is ApiException||!failure.Message.StartsWith("提交结果未知",StringComparison.Ordinal))frozenSubmission=null;error.Text=host.T(failure.Message);}
            finally{saving=false;committing=false;uploadCancellation?.Dispose();uploadCancellation=null;SetEditing(frozenSubmission==null);cancel.IsEnabled=true;submit.IsEnabled=true;if(closeAfterCancellation&&Saved==null)Close();}
        };
        void SetEditing(bool enabled){fields.IsEnabled=enabled;description.IsEnabled=enabled;choose.IsEnabled=enabled;drop.IsEnabled=enabled;attachmentsView.IsEnabled=enabled;submit.IsEnabled=enabled;cancel.IsEnabled=true;cancel.Content=host.T(saving?"取消上传":"取消");}
        customers.SelectionChanged+=(_,_)=>{if(!changing)SelectGroup();};accounts.SelectionChanged+=(_,_)=>{if(!changing)SelectAccount();};companies.SelectionChanged+=(_,_)=>{if(!changing)SelectCompany();};
        ReloadChoices();Content=new ScrollViewer{Content=root,VerticalScrollBarVisibility=ScrollBarVisibility.Auto};
    }
    void ReloadChoices(string? customerId=null,string? accountId=null,string? companyId=null)
    {
        changing=true;customers.ItemsSource=Groups.Select(x=>new KeyValuePair<string,string>(S(x,"id"),S(x,"name"))).ToList();customers.SelectedValue=customerId;if(customers.SelectedIndex<0)customers.SelectedIndex=0;changing=false;SelectGroup(accountId,companyId);
    }
    void SelectGroup(string? accountId=null,string? companyId=null)
    {
        changing=true;companies.ItemsSource=CustomerCompanies.Select(x=>new KeyValuePair<string,string>(S(x,"id"),S(x,"name"))).ToList();
        var account=CustomerAccounts.FirstOrDefault(x=>S(x,"id")==accountId)??CustomerAccounts.FirstOrDefault(x=>companyId==null||S(x,"companyId")==companyId);
        companies.SelectedValue=account!=null?S(account,"companyId"):companyId;if(companies.SelectedIndex<0)companies.SelectedIndex=0;changing=false;SelectCompany(account!=null?S(account,"id"):null);
    }
    void SelectCompany(string? accountId=null)
    {
        changing=true;accounts.ItemsSource=CustomerAccounts.Where(x=>S(x,"companyId")==companies.SelectedValue?.ToString()).Select(x=>new KeyValuePair<string,string>(S(x,"id"),S(x,"username")+" · "+S(x,"name"))).ToList();accounts.SelectedValue=accountId;if(accounts.SelectedIndex<0)accounts.SelectedIndex=0;changing=false;
    }
    void SelectAccount(){var account=CustomerAccounts.FirstOrDefault(x=>S(x,"id")==accounts.SelectedValue?.ToString());if(account==null)return;changing=true;companies.SelectedValue=S(account,"companyId");changing=false;}
    void NewDirectory(string operation)
    {
        if(!B(host.Client.CustomerDirectory,"canManage"))return;
        if(operation!="customer"&&SelectedCustomer==null){error.Text=host.T("请核对填写内容");return;}
        if(operation=="account"&&companies.SelectedValue==null){error.Text=host.T("请核对填写内容");return;}
        var dialog=new Window{Owner=this,Title=host.T(operation=="customer"?"新建客户":operation=="company"?"新建企业":"新建账号"),Width=560,SizeToContent=SizeToContent.Height,MaxHeight=700,Background=Background,Foreground=Foreground,Language=Language};
        var panel=new StackPanel{Margin=new Thickness(24)};panel.Children.Add(host.Label(dialog.Title,22));var inputs=new Dictionary<string,FrameworkElement>();
        var fields=operation=="customer"?new[]{("name","客户名称"),("companyName","企业名称"),("username","用户名"),("password","密码"),("confirmPassword","确认密码")}:operation=="company"?new[]{("name","企业名称")}:new[]{("name","账号名称"),("username","用户名"),("password","密码"),("confirmPassword","确认密码")};
        foreach(var (key,title)in fields){panel.Children.Add(host.Label(host.T(title)));FrameworkElement input=key is "password" or "confirmPassword"?new NativePasswordField("",host.T):host.Input();inputs[key]=input;panel.Children.Add(input);}
        var warning=host.Label("");warning.Foreground=Brushes.IndianRed;panel.Children.Add(warning);var confirm=host.Button("确认提交",()=>{});panel.Children.Add(confirm);bool writing=false;dialog.Closing+=(_,e)=>e.Cancel=writing;
        confirm.Click+=async(_,_)=>
        {
            if(writing)return;writing=true;panel.IsEnabled=false;
            try
            {
                if(context!=host.Client.Context)throw new Exception(host.T("身份或数据来源已改变，请重新打开当前单据。"));
                if(inputs.Values.OfType<NativePasswordField>().Any(field=>!field.ValidateForSubmission()))throw new Exception(PasswordCharacterPolicy.ErrorMessage);
                var body=new JsonObject{["operation"]=operation};foreach(var (key,input)in inputs)body[key]=input is NativePasswordField password?password.Password:((TextBox)input).Text;
                if(operation!="customer")body["customerId"]=S(SelectedCustomer,"id");if(operation=="account")body["companyId"]=companies.SelectedValue?.ToString();
                var response=await host.Client.CreateDirectoryEntry(body);ReloadChoices(S(response,"customerId"),S(response,"accountId"),S(response,"companyId"));writing=false;dialog.Close();
            }
            catch(Exception failure){warning.Text=host.T(failure.Message);}
            finally{writing=false;panel.IsEnabled=true;}
        };
        dialog.Content=new ScrollViewer{Content=panel,VerticalScrollBarVisibility=ScrollBarVisibility.Auto};dialog.ShowDialog();
    }
    void ChooseMedia()
    {
        var picker=new OpenFileDialog{Multiselect=true,CheckFileExists=true,Filter="Images / Video|*.png;*.jpg;*.jpeg;*.gif;*.webp;*.mp4;*.mov;*.webm"};if(picker.ShowDialog(this)==true)AddMedia(picker.FileNames);
    }
    void AddMedia(IEnumerable<string> paths)
    {
        if(saving||frozenSubmission!=null)return;
        try{foreach(var path in paths){var file=new NativeDeviceFile(path);if(files.All(x=>!x.Path.Equals(file.Path,StringComparison.OrdinalIgnoreCase)))files.Add(file);}error.Text="";}
        catch(Exception failure){error.Text=host.T(failure.Message);}
        RenderMedia();
    }
    void RenderMedia()
    {
        attachmentsView.Children.Clear();foreach(var file in files.ToArray())
        {
            var row=new DockPanel();var remove=host.Button("删除",()=>{files.Remove(file);RenderMedia();if(file.Uploaded!=null)_=Discard(file.Uploaded);});DockPanel.SetDock(remove,Dock.Right);row.Children.Add(remove);
            var preview=host.Button("预览",()=>{try{file.AssertUnchanged();NativeMediaPreview.OpenFile(host,this,file.Name,file.Mime,file.Path);}catch(Exception failure){error.Text=host.T(failure.Message);}});DockPanel.SetDock(preview,Dock.Right);row.Children.Add(preview);row.Children.Add(host.Label(file.Name+" · "+file.Size.ToString("N0")+" B",12));attachmentsView.Children.Add(row);
        }
    }
    async Task Discard(JsonObject reference){if(context!=host.Client.Context)return;try{await host.Client.DiscardOrderUpload(reference);}catch{}}
}
