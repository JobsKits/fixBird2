using System.IO;
// Created by Jobs on 2026-11-18. Windows desktop uses native WPF controls.
using System.Globalization;
using System.Text.Json.Nodes;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using Microsoft.Win32;

namespace RepairDesktop;

sealed class MainWindow : Window
{
    readonly WorkbenchClient client = new();
    readonly JsonObject translations = Load("desktop-l10n.json")["messages"]!.AsObject();
    internal readonly JsonObject Actions = Load("actions.json");
    readonly string preferencePath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Jobs", "RepairDesktop", "preferences.json");
    readonly DockPanel root = new() { Margin = new Thickness(20) };
    readonly TextBlock message = new() { TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0, 10, 0, 0) };
    readonly Grid body = new();
    StackPanel detail = new();
    ListBox list = new();
    TextBox search = new();
    JsonObject? selected;
    enum InventoryKind { None,Part,Loan }
    InventoryKind selectedInventoryKind;
    string selectedPartId="";
    string selectedLoanId="";
    bool settingsSaving;
    int loanReadRevision;
    string language = "zh-Hans";
    string theme = "system";
    int selectionRevision;
    bool busy;
    NativeAuthenticationView? authenticationView;
    string draftSearch = "";
    internal static JsonObject Load(string file) => JsonNode.Parse(File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "Resources", file)))!.AsObject();
    internal string T(string key) => language == "zh-Hans" ? key : translations[language]?[key]?.ToString() ?? key;
    internal WorkbenchClient Client => client;

    public MainWindow()
    {
        Title = "啄木鸟维修平台"; Width = 1200; Height = 850; MinWidth = 960; MinHeight = 680;
        Content = root;
        try
        {
            var preferences = JsonNode.Parse(File.ReadAllText(preferencePath));
            language = WorkbenchClient.S(preferences, "language"); theme = WorkbenchClient.S(preferences, "theme");
            client.Configure(WorkbenchClient.S(preferences, "endpoint"), double.Parse(WorkbenchClient.S(preferences, "timeout"), CultureInfo.InvariantCulture));
        }
        catch { }
        SystemEvents.UserPreferenceChanged += PreferenceChanged;
        Closed += (_, _) => { SystemEvents.UserPreferenceChanged -= PreferenceChanged;client.Dispose(); };
        Draw();
        Loaded += async (_, _) => { await client.ProbeDemoAvailability(); if(client.Actor==null)Draw(); };
    }

    void PreferenceChanged(object sender, UserPreferenceChangedEventArgs e) => Dispatcher.BeginInvoke(()=>{ if(client.Actor!=null)Draw();else{ApplyTheme();authenticationView?.RefreshPalette();} });
    internal TextBlock Label(string text, double size = 14) => new() { Text = text, FontSize = size, TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0, 5, 0, 5) };
    internal Button Button(string text, Action run) { var b = new Button { Content = T(text), Padding = new Thickness(14, 7, 14, 7), Margin = new Thickness(4) }; b.Click += (_, _) => run(); return b; }
    internal TextBox Input(string value = "") => new() { Text = value, Padding = new Thickness(8), Margin = new Thickness(0, 3, 0, 10) };
    void ApplyTheme()
    {
        var dark = theme == "dark";
        if (theme == "system")
        {
            using var key = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize");
            dark = key?.GetValue("AppsUseLightTheme") is int v && v == 0;
        }
        Background = dark ? new SolidColorBrush(Color.FromRgb(27, 30, 37)) : Brushes.WhiteSmoke;
        Foreground = dark ? Brushes.WhiteSmoke : Brushes.Black;
        Resources[SystemColors.ControlBrushKey] = dark ? new SolidColorBrush(Color.FromRgb(42, 47, 57)) : Brushes.White;
        Resources[SystemColors.WindowBrushKey] = dark ? new SolidColorBrush(Color.FromRgb(35, 40, 48)) : Brushes.White;
        Resources[SystemColors.ControlTextBrushKey] = Foreground;
        Resources[SystemColors.WindowTextBrushKey] = Foreground;
        Resources[SystemColors.GrayTextBrushKey] = dark ? Brushes.LightGray : Brushes.DimGray;
    }

    void Draw()
    {
        ReconcileSelection();
        var culture = CultureInfo.GetCultureInfo(language == "zh-Hans" ? "zh-CN" : language == "zh-Hant" ? "zh-TW" : language);
        CultureInfo.CurrentCulture = culture;
        Language = System.Windows.Markup.XmlLanguage.GetLanguage(culture.IetfLanguageTag);
        ApplyTheme(); root.Children.Clear();
        var header = new DockPanel { LastChildFill = true, Margin = new Thickness(0, 0, 0, 15) };
        var logo = new Image { Source = new BitmapImage(new Uri(Path.Combine(AppContext.BaseDirectory, "Resources", "RepairLogo.png"))), Width = 42, Height = 42, Margin = new Thickness(0, 0, 12, 0) };
        DockPanel.SetDock(logo, Dock.Left); header.Children.Add(logo);
        if (client.Actor != null)
        {
            var buttons = new StackPanel { Orientation = Orientation.Horizontal };
            buttons.Children.Add(Label(WorkbenchClient.IdentityCaption(client.Actor,T),13));
            buttons.Children.Add(Button("重新加载", () => Run(async () => { await client.Refresh(); selected = null; Draw(); })));
            buttons.Children.Add(Button("退出登录", () => Run(async () => { await client.Logout(); selected = null; selectionRevision++; Draw(); })));
            DockPanel.SetDock(buttons, Dock.Right); header.Children.Add(buttons);
        }
        var settingsButton=Button("设置",OpenSettings);DockPanel.SetDock(settingsButton,Dock.Right);header.Children.Add(settingsButton);
        var brand = new StackPanel(); brand.Children.Add(Label(T("啄木鸟维修平台"), 25));
        brand.Children.Add(Label(T(client.Actor == null ? "欢迎使用" : client.IsDemo ? "独立合成演示" : "服务端数据")));
        header.Children.Add(brand); DockPanel.SetDock(header, Dock.Top); root.Children.Add(header);
        DockPanel.SetDock(message, Dock.Bottom); root.Children.Add(message);
        body.Children.Clear(); root.Children.Add(body);
        if (client.Actor == null) Login(); else Workbench();
        message.Text = T(client.Message);
    }

    async void Run(Func<Task> operation)
    {
        if (busy) return;
        busy = true; body.IsEnabled = false;
        try { await operation(); message.Text = T(client.Message); }
        catch (Exception error) { if (client.Actor == null) Draw(); message.Text = T(error.Message); }
        finally { busy = false; body.IsEnabled = true; }
    }

    internal void Authenticated()
    {
        selected=null;selectionRevision++;draftSearch=client.SearchText;Draw();
    }
    void Login()
    {
        var panel=new StackPanel{HorizontalAlignment=HorizontalAlignment.Center,MaxWidth=790};
        authenticationView=new NativeAuthenticationView(this);
        panel.Children.Add(authenticationView);

        body.Children.Add(new ScrollViewer{Content=panel,VerticalScrollBarVisibility=ScrollBarVisibility.Auto});
    }
    static string RoleName(string role) => role switch { "admin" => "公司负责人", "customer" => "客户", "engineer" => "工程师", _ => "财务" };

    void Workbench()
    {
        var tabs = new TabControl();
        tabs.Items.Add(new TabItem { Header = T("工单"), Content = Orders() });
        tabs.Items.Add(new TabItem { Header = T("库存借还"), Content = Inventory() });

        body.Children.Add(tabs);
    }

    Grid Orders()
    {
        var grid = new Grid { Margin = new Thickness(10) };
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(420) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        var left = new DockPanel();
        var bar = new StackPanel(); var commands = new WrapPanel();
        var statuses=new List<KeyValuePair<string,string>>{new("",T("全部"))};
        statuses.AddRange(WorkbenchClient.OrderStatuses.Select(value=>new KeyValuePair<string,string>(value,Status(value))));
        bar.Children.Add(Label(T("状态")));
        var state=new ComboBox{ItemsSource=statuses,DisplayMemberPath="Value",SelectedValuePath="Key",SelectedValue=client.StatusFilter,MinHeight=38,HorizontalContentAlignment=HorizontalAlignment.Left,Margin=new Thickness(0,0,0,6)};
        System.Windows.Automation.AutomationProperties.SetName(state,T("状态"));
        state.SelectionChanged+=(_,_)=>Run(()=>QueryOrders(selectedStatus:state.SelectedValue?.ToString()??""));bar.Children.Add(state);
        search = Input(draftSearch);
        search.KeyDown+=(_,e)=>{if(e.Key==System.Windows.Input.Key.Enter){e.Handled=true;Run(()=>QueryOrders());}};
        commands.Children.Add(Button("搜索", () => Run(()=>QueryOrders())));
        commands.Children.Add(Button("新建工单", Create));
        var more=Button("加载更多",()=>Run(()=>QueryOrders(true)));more.IsEnabled=client.More;commands.Children.Add(more);
        bar.Children.Add(search); bar.Children.Add(commands);bar.Children.Add(Label(T("当前已加载工单")+" · "+client.Orders.Count,12)); DockPanel.SetDock(bar, Dock.Top); left.Children.Add(bar);
        list = new ListBox { Margin = new Thickness(0, 10, 15, 0), ItemContainerStyle=SelectedRowStyle() };
        if (client.Orders.Count == 0) list.Items.Add(Empty());
        int orderIndex=0;
        foreach (var order in client.Orders)
        {
            var row=new StackPanel();
            row.Children.Add(new TextBlock{Text=(++orderIndex)+". "+WorkbenchClient.S(order,"number")+" · "+Status(WorkbenchClient.S(order,"status")),FontWeight=FontWeights.SemiBold,TextWrapping=TextWrapping.Wrap,Margin=new Thickness(0,0,0,5)});
            row.Children.Add(new TextBlock{Text=WorkbenchClient.S(order,"device")+" · "+WorkbenchClient.S(order,"customer"),TextWrapping=TextWrapping.Wrap});
            row.Children.Add(new TextBlock{Text=OrderTimestamp(order),FontSize=12,TextWrapping=TextWrapping.Wrap,Margin=new Thickness(0,5,0,0)});
            var item=new ListBoxItem{Content=row,Tag=order,IsSelected=WorkbenchClient.S(selected,"id")==WorkbenchClient.S(order,"id")};
            list.Items.Add(item);
        }
        list.SelectionChanged += (_, _) =>
        {
            if (list.SelectedItem is not ListBoxItem { Tag: JsonObject order }) return;
            var revision = ++selectionRevision;
            string context=client.Context;
            Run(async () => { var full = await client.Detail(WorkbenchClient.S(order, "id")); if (revision != selectionRevision||context!=client.Context||!client.ContainsCurrentOrder(WorkbenchClient.S(full,"id"))||!client.MatchesCurrentQuery(full)) return; selected = full; RenderDetail(); });
        };
        left.Children.Add(list); grid.Children.Add(left);
        detail = new StackPanel { Margin = new Thickness(20, 10, 10, 10) };
        var scroll = new ScrollViewer { Content = detail, VerticalScrollBarVisibility = ScrollBarVisibility.Auto };
        Grid.SetColumn(scroll, 1); grid.Children.Add(scroll); RenderDetail(); return grid;
    }

    async Task QueryOrders(bool append=false,string? selectedStatus=null)
    {
        selectionRevision++;
        string proposed=append?client.SearchText:search.Text;draftSearch=search.Text;
        try{await client.Search(proposed,append,selectedStatus);}
        finally{ReconcileSelection();Draw();}
    }
    void ReconcileSelection()
    {
        if(selected!=null&&(!client.ContainsCurrentOrder(WorkbenchClient.S(selected,"id"))||!client.MatchesCurrentQuery(selected))){selected=null;selectionRevision++;}
    }

    internal Style SelectedRowStyle()
    {
        var style=new Style(typeof(ListBoxItem));
        style.Setters.Add(new Setter(Control.PaddingProperty,new Thickness(12)));
        style.Setters.Add(new Setter(Control.HorizontalContentAlignmentProperty,HorizontalAlignment.Stretch));
        style.Setters.Add(new Setter(Control.ForegroundProperty,Foreground));
        var template=new ControlTemplate(typeof(ListBoxItem));
        var border=new FrameworkElementFactory(typeof(Border));border.SetValue(Border.CornerRadiusProperty,new CornerRadius(7));border.SetBinding(Border.BackgroundProperty,new System.Windows.Data.Binding("Background"){RelativeSource=new System.Windows.Data.RelativeSource(System.Windows.Data.RelativeSourceMode.TemplatedParent)});
        var presenter=new FrameworkElementFactory(typeof(ContentPresenter));presenter.SetValue(FrameworkElement.MarginProperty,new Thickness(10));border.AppendChild(presenter);template.VisualTree=border;
        style.Setters.Add(new Setter(Control.TemplateProperty,template));
        var selected=new Trigger{Property=ListBoxItem.IsSelectedProperty,Value=true};
        var dark=Foreground is SolidColorBrush brush&&brush.Color.R>180;
        selected.Setters.Add(new Setter(Control.BackgroundProperty,new SolidColorBrush(dark?Color.FromRgb(68,83,73):Color.FromRgb(222,230,222))));
        selected.Setters.Add(new Setter(Control.ForegroundProperty,dark?Brushes.White:new SolidColorBrush(Color.FromRgb(26,61,39))));style.Triggers.Add(selected);
        return style;
    }

    internal string Status(string key) => T(new Dictionary<string, string> { ["pending_intake"]="待受理",["pending_arrangement"]="待安排",["diagnosis_quotation"]="检测／报价中",["pending_customer_confirmation"]="待客户确认",["pending_execution"]="待执行",["repairing"]="维修中",["pending_quality_check"]="待质检",["pending_delivery"]="待交付",["pending_acceptance"]="待验收",["settling"]="结算中",["pending_completion"]="待完结确认",["completed"]="已完结" }.GetValueOrDefault(key, key));
    internal static string Money(JsonNode? value) => "¥" + (decimal.TryParse(value?.ToString(), out var cents) ? cents / 100 : 0).ToString("F2");
    static bool TryBusinessTime(string raw,out string value)
    {
        if(DateTimeOffset.TryParse(raw,CultureInfo.InvariantCulture,DateTimeStyles.AssumeUniversal,out var time)&&time.Year>1)
        {
            value=time.ToOffset(TimeSpan.FromHours(8)).ToString("g",CultureInfo.CurrentCulture);
            return true;
        }
        value="";return false;
    }
    string BusinessTime(string raw)=>TryBusinessTime(raw,out var value)?value:T("时间未记录");
    string OrderTimestamp(JsonNode? order)
    {
        if(TryBusinessTime(WorkbenchClient.S(order,"createdAt"),out var created))return T("创建时间")+" · "+created;
        if(TryBusinessTime(WorkbenchClient.S(order,"updatedAt"),out var updated))return T("更新时间")+" · "+updated;
        return T("创建时间")+" · "+T("时间未记录");
    }
    string LoanTimestamp(JsonNode? loan)
    {
        string raw=WorkbenchClient.S(loan,"createdAt");
        if(!TryBusinessTime(raw,out _))raw=WorkbenchClient.S(loan,"borrowedAt");
        return T("借出时间")+" · "+BusinessTime(raw);
    }
    void RenderDetail()
    {
        ReconcileSelection();
        detail.Children.Clear();
        if (selected == null) { detail.Children.Add(Label(T("请选择工单"), 23)); return; }
        var order = selected;
        detail.Children.Add(Label(WorkbenchClient.S(order, "number"), 24));
        detail.Children.Add(Label(Status(WorkbenchClient.S(order, "status"))));
        detail.Children.Add(Label(T("创建时间")+" · "+BusinessTime(WorkbenchClient.S(order,"createdAt")),12));
        detail.Children.Add(Label(T("更新时间")+" · "+BusinessTime(WorkbenchClient.S(order,"updatedAt")),12));
        foreach (var field in new[] { ("customer", "客户"), ("project", "项目"), ("device", "设备"), ("description", "故障说明"), ("remark", "内部备注"), ("customerNote", "发布给客户的说明") })
            detail.Children.Add(Label(T(field.Item2) + " · " + WorkbenchClient.S(order, field.Item1)));
        detail.Children.Add(Label(T("报价") + " " + Money(order["quote"]?["amountCents"]), 18));
        detail.Children.Add(Label(WorkbenchClient.S(order["quote"], "description")));
        detail.Children.Add(Label(T(WorkbenchClient.B(order["quote"], "startRequiresPrepayment") ? "已明确约定，核实约定预付款后开修" : "未约定先款开修")));
        detail.Children.Add(Label(T("待收款") + " " + Money(order["summary"]?["remainingCents"])));
        detail.Children.Add(Label(T("当前可办理"), 18));
        var actions = new WrapPanel();
        foreach (var entry in order["allowedActions"]!.AsArray())
        {
            var id = entry!.ToString(); if (Actions[id] is not JsonObject spec) continue;
            actions.Children.Add(Button(WorkbenchClient.S(spec, "title"), () =>
            {
                var form = new ActionWindow(this, order, id) { Owner = this };
                if (form.ShowDialog() == true) Run(async () => { await client.Refresh();selected=client.ContainsCurrentOrder(WorkbenchClient.S(order,"id"))?await client.Detail(WorkbenchClient.S(order,"id")):null;ReconcileSelection();Draw(); });
            }));
        }
        detail.Children.Add(actions);
        if(client.IsDemo&&order["evidence"] is JsonArray sample&&sample.Count>0)detail.Children.Add(Label(T("合成演示设备资料"),18));
        if(order["evidence"] is JsonArray evidence)foreach(var file in evidence.Where(x=>WorkbenchClient.S(x,"kind") is "image" or "video"))
        {
            var original=file!.DeepClone();var open=Button(WorkbenchClient.S(original,"kind")=="video"?"播放":"预览",()=>Run(()=>
            {
                using var download=new NativeDownloadDialog(this,WorkbenchClient.S(order,"id"),original.AsObject());
                if(download.ShowDialog()==true&&download.File!=null)NativeMediaPreview.OpenFile(this,this,WorkbenchClient.S(original,"name"),WorkbenchClient.S(original,"mime"),download.File.Path);
                return Task.CompletedTask;
            }));
            if(client.DemoEvidenceThumbnail(WorkbenchClient.S(order,"id"),original.AsObject()) is {} thumbnail)
            {
                var content=new StackPanel();
                var source=new BitmapImage();source.BeginInit();source.DecodePixelWidth=640;source.CacheOption=BitmapCacheOption.OnLoad;source.UriSource=new Uri(thumbnail);source.EndInit();source.Freeze();
                content.Children.Add(new Image{Source=source,Width=220,Height=136,Stretch=Stretch.Uniform,Margin=new Thickness(0,0,0,7)});
                content.Children.Add(new TextBlock{Text=T(WorkbenchClient.S(original,"kind")=="video"?"播放":"预览"),HorizontalAlignment=HorizontalAlignment.Center});open.Content=content;
                System.Windows.Automation.AutomationProperties.SetName(open,WorkbenchClient.S(original,"name")+" · "+T(WorkbenchClient.S(original,"kind")=="video"?"播放":"预览"));
            }
            var attachment=new StackPanel{Margin=new Thickness(0,6,0,6)};attachment.Children.Add(Label(WorkbenchClient.S(original,"name"),12));attachment.Children.Add(open);detail.Children.Add(attachment);
        }

        detail.Children.Add(Label(T("业务记录"), 18));
        foreach (var row in order["events"]?.AsArray().Reverse() ?? []) detail.Children.Add(Label(BusinessTime(WorkbenchClient.S(row, "createdAt")) + " · " + WorkbenchClient.S(row, "note")));
    }

    FrameworkElement Empty()
    {
        var stack = new StackPanel { Margin = new Thickness(20) };
        stack.Children.Add(Label("◇", 32)); stack.Children.Add(Label(T("暂时没有记录"))); stack.Children.Add(Button("重新加载", () => Run(async () => { await client.Refresh(); Draw(); }))); return stack;
    }

    void OpenSettings()
    {
        var dialog=new Window{Title=T("设置"),Owner=this,Width=730,SizeToContent=SizeToContent.Height,MaxHeight=680,Background=Background,Foreground=Foreground,Language=Language};
        dialog.Closing+=(_,e)=>e.Cancel=settingsSaving;
        dialog.Content=Settings(()=>{dialog.Close();Draw();});dialog.ShowDialog();
    }
    FrameworkElement Settings(Action? saved=null)
    {
        var panel=new StackPanel{Margin=new Thickness(20,16,20,20),Width=650,HorizontalAlignment=HorizontalAlignment.Left,VerticalAlignment=VerticalAlignment.Top};
        var appearance=new StackPanel{Margin=new Thickness(16)};
        appearance.Children.Add(Label(T("语言")));
        var languages=new[]{"zh-Hans","zh-Hant","bo","en","ja","fr","es","de","ru","ko"};
        var names=new[]{"简体中文","繁體中文","བོད་ཡིག","English","日本語","Français","Español","Deutsch","Русский","한국어"};
        var lang=new ComboBox{ItemsSource=names,SelectedIndex=Math.Max(0,Array.IndexOf(languages,language)),HorizontalContentAlignment=HorizontalAlignment.Left,Margin=new Thickness(0,0,0,12)};appearance.Children.Add(lang);
        appearance.Children.Add(Label(T("主题")));
        var themes=new ComboBox{ItemsSource=new[]{T("白天"),T("黑夜"),T("跟随系统")},SelectedIndex=theme=="light"?0:theme=="dark"?1:2,HorizontalContentAlignment=HorizontalAlignment.Left};appearance.Children.Add(themes);
        panel.Children.Add(new GroupBox{Header=T("外观"),Content=appearance,Margin=new Thickness(0,0,0,14)});
        var connection=new StackPanel{Margin=new Thickness(16)};
        connection.Children.Add(Label(T("服务地址")));var endpoint=Input(client.Endpoint);connection.Children.Add(endpoint);
        connection.Children.Add(Label(T("请求超时")+" (0.5–30 s)"));var timeout=Input(client.Timeout.ToString(CultureInfo.InvariantCulture));connection.Children.Add(timeout);
        panel.Children.Add(new GroupBox{Header=T("连接"),Content=connection});
        var failure=Label("");failure.Foreground=Brushes.IndianRed;panel.Children.Add(failure);
        var save=Button("保存设置",()=>{});panel.Children.Add(save);
        save.Click+=async(_,_)=>
        {
            if(settingsSaving)return;settingsSaving=true;panel.IsEnabled=false;failure.Text="";
            try
            {
                var nextTimeout=double.Parse(timeout.Text,CultureInfo.InvariantCulture);
                if(endpoint.Text.TrimEnd('/')!=client.Endpoint||nextTimeout!=client.Timeout){client.Configure(endpoint.Text,nextTimeout);selected=null;selectionRevision++;await client.ProbeDemoAvailability();}
                language=languages[lang.SelectedIndex];theme=new[]{"light","dark","system"}[themes.SelectedIndex];
                Directory.CreateDirectory(Path.GetDirectoryName(preferencePath)!);
                File.WriteAllText(preferencePath,new JsonObject{["language"]=language,["theme"]=theme,["endpoint"]=client.Endpoint,["timeout"]=client.Timeout}.ToJsonString());settingsSaving=false;saved?.Invoke();
            }
            catch(Exception error){failure.Text=T(error.Message);}
            finally{settingsSaving=false;panel.IsEnabled=true;}
        };
        return new ScrollViewer{Content=panel,VerticalScrollBarVisibility=ScrollBarVisibility.Auto,VerticalContentAlignment=VerticalAlignment.Top};
    }

    FrameworkElement Inventory()
    {
        var shell=new DockPanel{Margin=new Thickness(18)};
        var header=new DockPanel();header.Children.Add(Label(T("库存借还"),24));var borrow=Button("借出登记",()=>OpenLoan("borrow"));DockPanel.SetDock(borrow,Dock.Right);header.Children.Add(borrow);DockPanel.SetDock(header,Dock.Top);shell.Children.Add(header);
        var columns=new Grid();columns.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(390)});columns.ColumnDefinitions.Add(new ColumnDefinition());shell.Children.Add(columns);
        var left=new DockPanel();var stock=new StackPanel{Margin=new Thickness(0,4,12,12)};
        stock.Children.Add(Label(T("配件"),17));
        var partRows=new ListBox{ItemContainerStyle=SelectedRowStyle(),MaxHeight=240};
        if(client.Parts.Count==0)partRows.Items.Add(Empty());
        foreach(var part in client.Parts)
        {
            var line=new StackPanel();line.Children.Add(new TextBlock{Text=WorkbenchClient.S(part,"name"),FontWeight=FontWeights.SemiBold,TextWrapping=TextWrapping.Wrap});line.Children.Add(new TextBlock{Text="SKU · "+WorkbenchClient.S(part,"sku")+" · "+T("可用")+" "+WorkbenchClient.I(part,"available")+" · "+T("隔离")+" "+WorkbenchClient.I(part,"quarantine"),TextWrapping=TextWrapping.Wrap,Margin=new Thickness(0,5,0,0)});
            partRows.Items.Add(new ListBoxItem{Content=line,Tag=part,IsSelected=selectedInventoryKind==InventoryKind.Part&&selectedPartId==WorkbenchClient.S(part,"id")});
        }
        stock.Children.Add(partRows);DockPanel.SetDock(stock,Dock.Top);left.Children.Add(stock);columns.Children.Add(left);
        var rows=new ListBox{ItemContainerStyle=SelectedRowStyle(),Margin=new Thickness(0,0,12,0)};
        if(client.Loans.Count==0)rows.Items.Add(Empty());
        int loanIndex=0;
        foreach(var loan in client.Loans)
        {
            var row=new StackPanel();row.Children.Add(new TextBlock{Text=(++loanIndex)+". "+WorkbenchClient.S(loan,"partName"),FontWeight=FontWeights.SemiBold,TextWrapping=TextWrapping.Wrap});row.Children.Add(new TextBlock{Text=WorkbenchClient.S(loan,"borrowerId")+" · "+T("尚欠")+" "+WorkbenchClient.I(loan,"outstanding"),TextWrapping=TextWrapping.Wrap,Margin=new Thickness(0,5,0,0)});
            row.Children.Add(new TextBlock{Text=LoanTimestamp(loan),FontSize=12,TextWrapping=TextWrapping.Wrap,Margin=new Thickness(0,5,0,0)});
            row.Children.Add(new TextBlock{Text=T("归还期限")+" · "+BusinessTime(WorkbenchClient.S(loan,"dueAt")),FontSize=12,TextWrapping=TextWrapping.Wrap,Margin=new Thickness(0,5,0,0)});
            rows.Items.Add(new ListBoxItem{Content=row,Tag=loan,IsSelected=selectedInventoryKind==InventoryKind.Loan&&selectedLoanId==WorkbenchClient.S(loan,"id")});
        }
        left.Children.Add(rows);
        var details=new StackPanel{Margin=new Thickness(18,8,4,8)};var scroll=new ScrollViewer{Content=details,VerticalScrollBarVisibility=ScrollBarVisibility.Auto};Grid.SetColumn(scroll,1);columns.Children.Add(scroll);
        void SelectLoan(JsonObject loan)
        {
            selectedInventoryKind=InventoryKind.Loan;selectedLoanId=WorkbenchClient.S(loan,"id");selectedPartId="";partRows.SelectedIndex=-1;
            _=RenderLoan(loan,details);
        }
        void SelectPart(JsonObject part)
        {
            loanReadRevision++;selectedInventoryKind=InventoryKind.Part;selectedPartId=WorkbenchClient.S(part,"id");selectedLoanId="";rows.SelectedIndex=-1;
            RenderPart(part,details,loan=>{rows.SelectedItem=rows.Items.OfType<ListBoxItem>().FirstOrDefault(x=>x.Tag is JsonObject data&&WorkbenchClient.S(data,"id")==WorkbenchClient.S(loan,"id"));});
        }
        var initialLoan=selectedInventoryKind==InventoryKind.Loan?client.Loans.FirstOrDefault(x=>WorkbenchClient.S(x,"id")==selectedLoanId)?.AsObject():null;
        var initialPart=selectedInventoryKind==InventoryKind.Part?client.Parts.FirstOrDefault(x=>WorkbenchClient.S(x,"id")==selectedPartId)?.AsObject():null;
        if(initialLoan!=null)_=RenderLoan(initialLoan,details);else if(initialPart!=null)RenderPart(initialPart,details,loan=>{rows.SelectedItem=rows.Items.OfType<ListBoxItem>().FirstOrDefault(x=>x.Tag is JsonObject data&&WorkbenchClient.S(data,"id")==WorkbenchClient.S(loan,"id"));});else details.Children.Add(Label(T("请选择配件或借还记录"),20));
        rows.SelectionChanged+=(_,_)=>{if(rows.SelectedItem is ListBoxItem{Tag:JsonObject loan})SelectLoan(loan);};
        partRows.SelectionChanged+=(_,_)=>{if(partRows.SelectedItem is ListBoxItem{Tag:JsonObject part})SelectPart(part);};
        return shell;
    }
    void RenderPart(JsonObject part,StackPanel panel,Action<JsonObject> selectLoan)
    {
        panel.Children.Clear();panel.Children.Add(Label(WorkbenchClient.S(part,"name"),23));panel.Children.Add(Label("SKU · "+WorkbenchClient.S(part,"sku")));panel.Children.Add(Label(T("可用")+" · "+WorkbenchClient.I(part,"available")));panel.Children.Add(Label(T("隔离")+" · "+WorkbenchClient.I(part,"quarantine")));panel.Children.Add(Label(T("关联借还记录"),18));
        var related=client.Loans.Where(x=>WorkbenchClient.S(x,"partId")==WorkbenchClient.S(part,"id")).OfType<JsonObject>().ToArray();
        if(related.Length==0)panel.Children.Add(Empty());
        int relatedIndex=0;
        foreach(var loan in related){var target=loan;var row=Button((++relatedIndex)+". "+WorkbenchClient.S(loan,"partName")+" · "+WorkbenchClient.S(loan,"borrowerId")+" · "+T("尚欠")+" "+WorkbenchClient.I(loan,"outstanding")+"\n"+LoanTimestamp(loan),()=>selectLoan(target));row.HorizontalContentAlignment=HorizontalAlignment.Left;panel.Children.Add(row);}
    }
    void OpenLoan(string action,JsonObject? loan=null)
    {
        var dialog=new NativeLoanDialog(this,action,loan){Owner=this};
        if(dialog.ShowDialog()==true)Run(async()=>{selectedInventoryKind=InventoryKind.Loan;selectedPartId="";selectedLoanId=dialog.SavedId??"";await client.Refresh();Draw();});
    }
    async Task RenderLoan(JsonObject loan,StackPanel panel)
    {
        var revision=++loanReadRevision;var context=client.Context;panel.Children.Clear();
        panel.Children.Add(Label(WorkbenchClient.S(loan,"partName"),23));panel.Children.Add(Label(T("借用人账号")+" · "+WorkbenchClient.S(loan,"borrowerId")));panel.Children.Add(Label(T("数量")+" "+WorkbenchClient.I(loan,"quantity")+" · "+T("尚欠")+" "+WorkbenchClient.I(loan,"outstanding")));panel.Children.Add(Label(WorkbenchClient.S(loan,"note")));
        panel.Children.Add(Label(LoanTimestamp(loan),12));panel.Children.Add(Label(T("归还期限")+" · "+BusinessTime(WorkbenchClient.S(loan,"dueAt")),12));
        var actions=new WrapPanel();if(WorkbenchClient.I(loan,"outstanding")>0)actions.Children.Add(Button("归还",()=>OpenLoan("return",loan)));actions.Children.Add(Button("补录图片凭据",()=>OpenLoan("append",loan)));panel.Children.Add(actions);panel.Children.Add(Label(T("图片凭据"),18));
        var files=loan["files"] as JsonArray??[];
        if(files.Count==0){panel.Children.Add(Label(T("暂无图片凭据")));return;}
        foreach(var file in files)
        {
            var group=new StackPanel{Margin=new Thickness(0,8,0,12)};group.Children.Add(Label(WorkbenchClient.S(file,"name")));group.Children.Add(Label(T(WorkbenchClient.S(file,"stage")=="return"?"归还":"借出登记")+" · "+BusinessTime(WorkbenchClient.S(file,"createdAt")),11));panel.Children.Add(group);
            try
            {
                var bytes=await client.LoanFile(WorkbenchClient.S(loan,"id"),WorkbenchClient.S(file,"id"));
                if(context!=client.Context||revision!=loanReadRevision)return;
                var source=NativeLoanDialog.Decode(bytes);var button=new Button{Content=new Image{Source=source,MaxHeight=210,Stretch=Stretch.Uniform},ToolTip=WorkbenchClient.S(file,"name"),HorizontalAlignment=HorizontalAlignment.Left};
                button.Click+=(_,_)=>new Window{Owner=this,Title=WorkbenchClient.S(file,"name"),Width=850,Height=680,Content=new Image{Source=source,Stretch=Stretch.Uniform},Background=Background}.ShowDialog();group.Children.Add(button);
            }
            catch(Exception error){if(client.Actor==null){selected=null;selectedLoanId="";Draw();return;}if(context==client.Context&&revision==loanReadRevision)group.Children.Add(Label(T(error.Message),11));}
        }
    }

    void Create()
    {
        Run(async()=>
        {
            await client.LoadCustomerDirectory();var dialog=new NativeOrderDialog(this){Owner=this};
            if(dialog.ShowDialog()==true){selected=dialog.Saved;await client.Refresh();ReconcileSelection();Draw();}
        });
    }
}
