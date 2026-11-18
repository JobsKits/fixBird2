// Created by Jobs. Separate WPF authentication cards; switching never recreates password drafts.
using System.Text.Json.Nodes;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Media;
using System.Windows.Media.Animation;

namespace RepairDesktop;

sealed class NativeAuthenticationView : Grid
{
    readonly MainWindow host;
    readonly Grid viewport=new(){ClipToBounds=true};
    readonly Dictionary<string,Card> cards=[];
    readonly Dictionary<string,Button> routes=[];
    readonly SolidColorBrush surface,ink,subtle,accent,railBackground,activeBackground;
    string mode="login";
    int switchRevision;
    bool busy;
    string T(string key)=>host.T(key);
    public NativeAuthenticationView(MainWindow host)
    {
        this.host=host;
        var dark=host.Foreground is SolidColorBrush text&&text.Color.R>180;
        surface=new SolidColorBrush(dark?Color.FromRgb(32,47,38):Colors.White);
        ink=new SolidColorBrush(dark?Color.FromRgb(236,245,237):Color.FromRgb(31,57,40));
        subtle=new SolidColorBrush(dark?Color.FromRgb(190,210,196):Color.FromRgb(76,102,84));
        accent=new SolidColorBrush(dark?Color.FromRgb(170,220,181):Color.FromRgb(48,99,64));
        railBackground=new SolidColorBrush(dark?Color.FromRgb(24,36,29):Color.FromRgb(244,247,241));
        activeBackground=new SolidColorBrush(dark?Color.FromRgb(61,89,69):Color.FromRgb(218,234,217));
        if(SystemParameters.HighContrast){surface=new(SystemColors.WindowColor);ink=new(SystemColors.WindowTextColor);subtle=new(SystemColors.WindowTextColor);accent=new(SystemColors.HighlightColor);railBackground=new(SystemColors.WindowColor);activeBackground=new(SystemColors.HighlightColor);}
        ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(260)});
        ColumnDefinitions.Add(new ColumnDefinition());
        var rail=new Grid{Background=railBackground,Margin=new Thickness(0),VerticalAlignment=VerticalAlignment.Stretch};
        for(int row=0;row<3;row++)rail.RowDefinitions.Add(new RowDefinition{Height=new GridLength(1,GridUnitType.Star)});
        int routeRow=0;
        foreach(var key in new[]{"login","register","reset"})
        {
            var next=key;
            var routeContent=new Grid{HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center,MaxWidth=192};
            routeContent.RowDefinitions.Add(new RowDefinition{Height=GridLength.Auto});
            routeContent.RowDefinitions.Add(new RowDefinition{Height=new GridLength(12)});
            routeContent.RowDefinitions.Add(new RowDefinition{Height=GridLength.Auto});
            var icon=RouteIcon(key);routeContent.Children.Add(icon);
            var caption=new TextBlock{Text=Caption(key),FontSize=26,TextWrapping=TextWrapping.Wrap,TextAlignment=TextAlignment.Center,VerticalAlignment=VerticalAlignment.Center};
            Grid.SetRow(caption,2);routeContent.Children.Add(caption);
            var button=new Button{Content=routeContent,FontSize=26,MinHeight=84,Margin=new Thickness(10,5,10,5),VerticalAlignment=VerticalAlignment.Stretch,Padding=new Thickness(14,12,14,12),HorizontalContentAlignment=HorizontalAlignment.Center,VerticalContentAlignment=VerticalAlignment.Center,BorderThickness=new Thickness(0)};
            System.Windows.Automation.AutomationProperties.SetName(button,Caption(key));
            button.Click+=(_,_)=>Switch(next);routes[key]=button;Grid.SetRow(button,routeRow++);rail.Children.Add(button);
            var card=CreateCard(key);cards[key]=card;viewport.Children.Add(card.Shell);
        }
        Children.Add(rail);SetColumn(viewport,1);Children.Add(viewport);
        Background=surface;HorizontalAlignment=HorizontalAlignment.Center;MaxWidth=790;Height=560;MinHeight=560;MaxHeight=560;
        Switch("login",false);
    }
    public void RefreshPalette()
    {
        bool dark=host.Foreground is SolidColorBrush text&&text.Color.R>180;
        surface.Color=dark?Color.FromRgb(32,47,38):Colors.White;ink.Color=dark?Color.FromRgb(236,245,237):Color.FromRgb(31,57,40);subtle.Color=dark?Color.FromRgb(190,210,196):Color.FromRgb(76,102,84);accent.Color=dark?Color.FromRgb(170,220,181):Color.FromRgb(48,99,64);railBackground.Color=dark?Color.FromRgb(24,36,29):Color.FromRgb(244,247,241);activeBackground.Color=dark?Color.FromRgb(61,89,69):Color.FromRgb(218,234,217);
        if(SystemParameters.HighContrast){surface.Color=railBackground.Color=SystemColors.WindowColor;ink.Color=subtle.Color=SystemColors.WindowTextColor;accent.Color=activeBackground.Color=SystemColors.HighlightColor;}
        if(!SystemParameters.ClientAreaAnimation||SystemParameters.HighContrast){switchRevision++;foreach(var (key,card)in cards){card.Shell.RenderTransform=new TranslateTransform();card.Shell.Visibility=key==mode?Visibility.Visible:Visibility.Collapsed;}}
    }
    string Caption(string key)=>T(key=="login"?"登录":key=="register"?"新用户注册":"忘记密码");
    static Viewbox RouteIcon(string key)
    {
        var data=Geometry.Parse(key switch
        {
            "login"=>"M19,4 L29,4 L29,28 L19,28 M3,16 L22,16 M15,9 L22,16 L15,23",
            "register"=>"M17,8 A5,5 0 1 1 7,8 A5,5 0 1 1 17,8 M2,28 C2,18 22,18 22,28 M26,9 L26,21 M20,15 L32,15",
            _=>"M16,10 A7,7 0 1 1 2,10 A7,7 0 1 1 16,10 M14,15 L28,29 M21,22 L25,18 M25,26 L29,22"
        });
        data.Freeze();
        var path=new System.Windows.Shapes.Path{Data=data,StrokeThickness=2,StrokeStartLineCap=PenLineCap.Round,StrokeEndLineCap=PenLineCap.Round,StrokeLineJoin=PenLineJoin.Round};
        path.SetBinding(System.Windows.Shapes.Shape.StrokeProperty,new Binding("Foreground"){RelativeSource=new RelativeSource(RelativeSourceMode.FindAncestor,typeof(Button),1)});
        var canvas=new Canvas{Width=34,Height=34};canvas.Children.Add(path);
        var icon=new Viewbox{Child=canvas,Width=42,Height=42,Stretch=Stretch.Uniform,HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center};
        return icon;
    }
    Card CreateCard(string key)
    {
        var card=new Card();
        var form=new StackPanel{Margin=new Thickness(27,22,27,22)};
        card.Shell=new ScrollViewer{Content=form,VerticalScrollBarVisibility=ScrollBarVisibility.Auto,Background=surface};

        if(key=="login"&&host.Client.CanUseDemo)
        {
            form.Children.Add(new TextBlock{Text=T("请选择角色"),Foreground=subtle,Margin=new Thickness(0,0,0,7)});
            var choices=new ComboBox{ItemsSource=new[]{new KeyValuePair<string,string>("admin",T("公司负责人")),new("dispatcher",T("客服调度")),new("engineer",T("工程师")),new("finance",T("财务")),new("warehouse",T("仓库")),new("qc",T("质检")),new("customer",T("客户")),new("outsource",T("一手外包")),new("supplier",T("供应商"))},DisplayMemberPath="Value",SelectedValuePath="Key",SelectedValue="admin",MinHeight=42,HorizontalContentAlignment=HorizontalAlignment.Left,Margin=new Thickness(0,0,0,9)};
            choices.SelectionChanged+=(_,_)=>{if(card.Fields.TryGetValue("username",out var user)){var role=choices.SelectedValue?.ToString()??"admin";((TextBox)user).Text=role;var secret=(NativePasswordField)card.Fields["password"];secret.Password=role=="admin"?"1234":"Demo-Repair-2026!";secret.IsRevealed=true;}};
            form.Children.Add(choices);
            form.Children.Add(new TextBlock{Text=T("已预填合成账号和密码，可直接登录；仅用于演示。"),TextWrapping=TextWrapping.Wrap,Foreground=subtle,FontSize=12,Margin=new Thickness(0,0,0,10)});
        }
        var fields=key=="login"?new[]{("username","账号"),("password","密码")}:key=="register"?new[]{("username","用户名"),("name","姓名"),("email","邮箱"),("code","验证码"),("password","密码"),("confirmPassword","确认密码")}:new[]{("email","邮箱"),("code","验证码"),("password","密码"),("confirmPassword","确认密码")};
        foreach(var (field,title)in fields)
        {
            form.Children.Add(new TextBlock{Text=T(title),Foreground=ink,Margin=new Thickness(0,3,0,4)});
            FrameworkElement input=field is "password" or "confirmPassword"?new NativePasswordField(key=="login"&&host.Client.CanUseDemo?"1234":"",T,key=="login"&&host.Client.CanUseDemo):new TextBox{Text=key=="login"&&host.Client.CanUseDemo?"admin":"",Padding=new Thickness(8),MinHeight=42,VerticalContentAlignment=VerticalAlignment.Center,Margin=new Thickness(0,0,0,8)};
            if(input is NativePasswordField password){card.PasswordFields[field]=password;form.Children.Add(password);}else form.Children.Add(input);
            card.Fields[field]=input;
            input.KeyDown+=async(_,e)=>{if(e.Key==System.Windows.Input.Key.Enter){e.Handled=true;await Submit(key,card);}};
        }
        if(key!="login")
        {
            var code=new Button{Height=42,MinWidth=170,Padding=new Thickness(18,0,18,0),Margin=new Thickness(0,2,0,6),HorizontalAlignment=HorizontalAlignment.Stretch,HorizontalContentAlignment=HorizontalAlignment.Center,VerticalContentAlignment=VerticalAlignment.Center,Background=activeBackground,Foreground=ink,BorderThickness=new Thickness(0)};
            card.CodeButton=code;SetCodeButtonContent(card,false);code.Click+=async(_,_)=>await SendCode(key,card);form.Children.Add(code);
        }
        card.Error=new TextBlock{TextWrapping=TextWrapping.Wrap,Foreground=Brushes.IndianRed,Margin=new Thickness(0,6,0,6)};form.Children.Add(card.Error);
        var submit=host.Button(key=="login"?"登录":key=="register"?"创建账号":"重置密码",()=>{});
        submit.Background=accent;submit.Foreground=SystemParameters.HighContrast?SystemColors.HighlightTextBrush:darkText(accent)?Brushes.Black:Brushes.White;submit.BorderThickness=new Thickness(0);submit.Margin=new Thickness(0,6,0,4);submit.Click+=async(_,_)=>await Submit(key,card);form.Children.Add(submit);
        var links=new WrapPanel();
        foreach(var next in key=="login"?new[]{"register","reset"}:new[]{"login"})
        {
            var target=next;
            var link=host.Button(next=="login"?"返回登录":next=="register"?"新用户注册":"忘记密码",()=>Switch(target));link.Background=Brushes.Transparent;link.BorderThickness=new Thickness(0);link.Foreground=accent;links.Children.Add(link);
        }
        form.Children.Add(links);return card;
    }
    static bool darkText(Brush brush)=>brush is SolidColorBrush b&&b.Color.R>140;
    void SetCodeButtonContent(Card card,bool sending)
    {
        if(card.CodeButton==null)return;
        var content=new StackPanel{Orientation=Orientation.Horizontal,HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center};
        var plane=new System.Windows.Shapes.Path{Data=Geometry.Parse("M2,3 L22,12 L2,21 L6,12 Z M6,12 L22,12"),Width=22,Height=22,Stretch=Stretch.Uniform,StrokeThickness=1.7,StrokeLineJoin=PenLineJoin.Round,Margin=new Thickness(0,0,9,0)};
        plane.SetBinding(System.Windows.Shapes.Shape.StrokeProperty,new Binding("Foreground"){Source=card.CodeButton});
        content.Children.Add(plane);content.Children.Add(new TextBlock{Text=T(sending?"发送中…":"发送验证码"),VerticalAlignment=VerticalAlignment.Center,TextAlignment=TextAlignment.Center,TextWrapping=TextWrapping.Wrap,MaxWidth=330});
        card.CodeButton.Content=content;card.CodeButton.IsEnabled=!sending;card.CodeButton.Opacity=sending?0.6:1;System.Windows.Automation.AutomationProperties.SetName(card.CodeButton,T(sending?"发送中…":"发送验证码"));
    }
    string Value(Card card,string key)=>card.PasswordFields.TryGetValue(key,out var password)?password.Password:((TextBox)card.Fields[key]).Text.Trim();
    JsonObject Values(Card card){var values=new JsonObject();foreach(var key in card.Fields.Keys)values[key]=Value(card,key);return values;}
    async Task SendCode(string key,Card card)
    {
        if(busy)return;busy=true;SetCodeButtonContent(card,true);IsEnabled=false;card.Error.Text="";
        try{var result=await host.Client.Authentication("/auth/email-code",new JsonObject{["email"]=Value(card,"email"),["purpose"]=key=="register"?"register":"reset_password"});card.Error.Text=WorkbenchClient.S(result,"demoCode").Length>0?T("演示验证码")+": "+WorkbenchClient.S(result,"demoCode"):T("验证码已发送");}
        catch(Exception error){card.Error.Text=T(error.Message);}
        finally{busy=false;IsEnabled=true;SetCodeButtonContent(card,false);}
    }
    async Task Submit(string key,Card card)
    {
        if(busy||key!=mode)return;busy=true;IsEnabled=false;card.Error.Text="";
        try
        {
            if(card.PasswordFields.Values.Any(field=>!field.ValidateForSubmission()))throw new Exception(PasswordCharacterPolicy.ErrorMessage);
            if(key=="login"){await host.Client.Login(Value(card,"username"),Value(card,"password"));if(host.Client.Actor==null)throw new Exception(T("请填写账号和密码。"));foreach(var password in card.PasswordFields.Values)password.Clear();host.Authenticated();}
            else
            {
                if(Value(card,"password")!=Value(card,"confirmPassword"))throw new Exception(T("两次输入的密码不一致"));
                var values=Values(card);var response=await host.Client.Authentication(key=="register"?"/register":"/reset-password",values);
                if(!WorkbenchClient.B(response,"ok"))throw new InvalidOperationException(T("响应未通过校验：JSON无法解析"));
                ((TextBox)cards["login"].Fields["username"]).Text=Value(card,key=="register"?"username":"email");
                foreach(var password in card.PasswordFields.Values)password.Clear();cards["login"].PasswordFields["password"].Clear();busy=false;IsEnabled=true;Switch("login");cards["login"].Error.Text=T(key=="register"?"注册成功，请登录":"密码已重置，请登录");
            }
        }
        catch(Exception error){card.Error.Text=T(error.Message);}
        finally{busy=false;IsEnabled=true;}
    }
    void Switch(string next,bool animate=true)
    {
        if(busy)return;var previous=mode;mode=next;int revision=++switchRevision;
        foreach(var (key,button)in routes){button.Background=key==next?activeBackground:railBackground;button.Foreground=key==next?accent:subtle;button.FontWeight=key==next?FontWeights.SemiBold:FontWeights.Normal;}
        foreach(var (key,card)in cards){card.Shell.Visibility=key==next||key==previous?Visibility.Visible:Visibility.Collapsed;card.Shell.IsEnabled=key==next;card.Shell.RenderTransform=new TranslateTransform();}
        bool reduce=SystemParameters.HighContrast||!SystemParameters.ClientAreaAnimation;
        if(!animate||next==previous||reduce){foreach(var (key,card)in cards)card.Shell.Visibility=key==next?Visibility.Visible:Visibility.Collapsed;return;}
        double width=Math.Max(400,viewport.ActualWidth);
        var incoming=(TranslateTransform)cards[next].Shell.RenderTransform;var outgoing=(TranslateTransform)cards[previous].Shell.RenderTransform;
        var easing=new CubicEase{EasingMode=EasingMode.EaseInOut};
        incoming.BeginAnimation(TranslateTransform.XProperty,new DoubleAnimation(width+16,0,TimeSpan.FromMilliseconds(700)){EasingFunction=easing});
        var exit=new DoubleAnimation(0,-width-16,TimeSpan.FromMilliseconds(700)){EasingFunction=easing};exit.Completed+=(_,_)=>{if(revision==switchRevision)cards[previous].Shell.Visibility=Visibility.Collapsed;};outgoing.BeginAnimation(TranslateTransform.XProperty,exit);
    }
    sealed class Card
    {
        public ScrollViewer Shell=null!;
        public TextBlock Error=null!;
        public Button? CodeButton;
        public readonly Dictionary<string,FrameworkElement> Fields=[];
        public readonly Dictionary<string,NativePasswordField> PasswordFields=[];
    }
}
