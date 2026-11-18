using System.IO;
// Created by Jobs on 2026-11-18. Every field is a native WPF control.
using System.Globalization;
using System.Text.Json.Nodes;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Ink;
using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace RepairDesktop;

sealed class ActionWindow : Window
{
    readonly MainWindow host;
    readonly JsonObject order;
    readonly string action;
    readonly string openingContext;
    readonly Dictionary<string, Func<JsonNode?>> readers = [];
    readonly StackPanel panel = new() { Margin = new Thickness(25) };
    readonly TextBlock error = new() { TextWrapping = TextWrapping.Wrap, Foreground = Brushes.IndianRed, Margin = new Thickness(0, 12, 0, 12) };
    readonly CheckBox consent = new();
    bool saving;
    public ActionWindow(MainWindow host, JsonObject order, string action)
    {
        this.host = host; this.order = order; this.action = action; openingContext = host.Client.Context;
        Closing += (_, e) => e.Cancel = saving;
        Title = host.T(WorkbenchClient.S(host.Actions[action], "title")); Width = 650; Height = 730;
        Background = host.Background; Foreground = host.Foreground; Language = host.Language;
        panel.Children.Add(host.Label(Title, 24)); panel.Children.Add(host.Label(WorkbenchClient.S(order, "number") + " · " + host.Status(WorkbenchClient.S(order, "status"))));
        panel.Children.Add(host.Label(host.T("仅按已经发生、已经核实的事实填写。办理权限和当前业务条件以服务端确认为准。")));
        if (action is "sign_quote" or "accept")
        {
            var q = order["quote"];
            panel.Children.Add(host.Label(WorkbenchClient.S(q, "description")));
            panel.Children.Add(host.Label(host.T("含税总价（元）") + " " + MainWindow.Money(q?["amountCents"])));
            panel.Children.Add(host.Label(host.T("约定预付款（元，可为零）") + " " + MainWindow.Money(q?["prepayCents"])));
            panel.Children.Add(host.Label(host.T(WorkbenchClient.B(q, "startRequiresPrepayment") ? "已明确约定，核实约定预付款后开修" : "未约定先款开修")));
            panel.Children.Add(host.Label(host.T(WorkbenchClient.B(q, "autoAccept") ? "客户已接受，凭完整交付启动" : "未接受，不自动验收")));
            panel.Children.Add(host.Label(WorkbenchClient.S(q, "validUntil") + " · " + WorkbenchClient.S(q, "warrantyMonths")));
            consent.Content = host.T("我已阅读并确认以上条款"); consent.Margin = new Thickness(0, 10, 0, 10); panel.Children.Add(consent);
        }
        foreach (var field in host.Actions[action]!["fields"]!.AsArray()) AddField(field!.AsObject());
        panel.Children.Add(error);
        var submit = host.Button("确认提交", () => { });
        submit.Click += async (_, _) =>
        {
            saving = true; submit.IsEnabled = false;
            try
            {
                if (host.Client.Context != openingContext || host.Client.Actor == null) throw new Exception("身份或数据来源已改变，请重新打开当前单据。");
                if (action is "sign_quote" or "accept" && consent.IsChecked != true) throw new Exception("请先阅读并确认条款");
                var payload = new JsonObject(); foreach (var r in readers) payload[r.Key] = r.Value();
                if (action == "evidence") { payload["kind"] = "text"; payload["mime"] = "text/plain"; }
                await host.Client.Perform(order, action, payload); saving = false; DialogResult = true;
            }
            catch (Exception e) { error.Text = host.T(e.Message); }
            finally { saving = false; submit.IsEnabled = true; }
        };
        panel.Children.Add(submit); panel.Children.Add(host.Button("取消", Close));
        Content = new ScrollViewer { Content = panel, VerticalScrollBarVisibility = ScrollBarVisibility.Auto };
    }

    void AddField(JsonObject field)
    {
        var key = WorkbenchClient.S(field, "key"); var kind = WorkbenchClient.S(field, "kind"); var value = WorkbenchClient.S(field, "value");
        if (key == "remark" && !new[] { "admin", "dispatcher", "engineer", "finance" }.Contains(WorkbenchClient.S(host.Client.Actor, "role"))) return;
        value = value switch { "$owner" => WorkbenchClient.S(order, "ownerId"), "$assignee" => WorkbenchClient.S(order, "assigneeId"), "$amount" => (decimal.Parse(WorkbenchClient.S(order["quote"], "amountCents"), CultureInfo.InvariantCulture) / 100).ToString("F2", CultureInfo.InvariantCulture), "$receivable" => (decimal.Parse(WorkbenchClient.S(order["summary"], "receivableCents"), CultureInfo.InvariantCulture) / 100).ToString("F2", CultureInfo.InvariantCulture), "$quoteVersion" => WorkbenchClient.S(order["quote"], "version"), "$remark" => WorkbenchClient.S(order, "remark"), "$customerNote" => WorkbenchClient.S(order, "customerNote"), _ => value };
        panel.Children.Add(host.Label(host.T(WorkbenchClient.S(field, "title")), 16));
        if (kind == "bool")
        {
            var toggle = new CheckBox { Content = host.T("是"), IsChecked = value == "true", Margin = new Thickness(0, 5, 0, 12) };
            panel.Children.Add(toggle); readers[key] = () => JsonValue.Create(toggle.IsChecked == true);
        }
        else if (kind is "date" or "instant")
        {
            var picker = new DatePicker { SelectedDate = value == "$future" ? DateTime.Today.AddDays(30) : DateTime.Today, Margin = new Thickness(0, 5, 0, 12) };
            panel.Children.Add(picker);
            var time = host.Input(DateTime.Now.ToString("HH:mm")); if (kind == "instant") panel.Children.Add(time);
            readers[key] = () =>
            {
                var date = picker.SelectedDate?.Date ?? throw new Exception("请选择日期");
                var clock = kind == "date" ? new TimeSpan(23, 59, 59) : TimeSpan.TryParseExact(time.Text, @"hh\:mm", CultureInfo.InvariantCulture, out var t) ? t : throw new Exception("请选择日期");
                return JsonValue.Create(new DateTimeOffset(DateTime.SpecifyKind(date + clock, DateTimeKind.Unspecified), TimeSpan.FromHours(8)).ToString("O"));
            };
        }
        else if (kind == "signature")
        {
            var ink = new InkCanvas { Width = 540, Height = 180, Background = Brushes.White, DefaultDrawingAttributes = new DrawingAttributes { Color = Colors.Black, Width = 3, Height = 3, FitToCurve = true } };
            panel.Children.Add(ink); panel.Children.Add(host.Button("清除签名", () => ink.Strokes.Clear()));
            readers[key] = () =>
            {
                if (ink.Strokes.Sum(s => s.StylusPoints.Count) < 12) throw new Exception("请实际手写签名");
                var image = new RenderTargetBitmap(540, 180, 96, 96, PixelFormats.Pbgra32); image.Render(ink);
                var encoder = new PngBitmapEncoder(); encoder.Frames.Add(BitmapFrame.Create(image));
                using var stream = new MemoryStream(); encoder.Save(stream);
                return JsonValue.Create("data:image/png;base64," + Convert.ToBase64String(stream.ToArray()));
            };
        }
        else if (kind is "choice" or "ref" or "refs")
        {
            var options = new List<KeyValuePair<string, string>>();
            if (kind == "choice")
            {
                var labels = new Dictionary<string, string> { ["cash"]="现金约定",["credit"]="批准企业账期",["receipt"]="收到现金",["refund"]="实际退还现金",["unknown"]="待确认",["required"]="需要真实资料",["none"]="无需，已有确认依据",["customer_refused"]="客户拒修",["company_refused"]="公司拒修",["unrepairable"]="确认不能修",["cancelled"]="批准取消",["negotiated"]="按协商停止" };
                options.AddRange(field["options"]!.AsArray().Select(x => new KeyValuePair<string, string>(x!.ToString(), host.T(labels.GetValueOrDefault(x.ToString(), x.ToString())))));
            }
            else
            {
                var records = value == "parts" ? host.Client.Parts : order[value] as JsonArray ?? [];
                options.AddRange(records.Where(x => !WorkbenchClient.B(x, "deleted") && !WorkbenchClient.B(x, "resolved")).Select(x => new KeyValuePair<string, string>(WorkbenchClient.S(x, "id"), new[] { "number", "name", "title", "note", "id" }.Select(k => WorkbenchClient.S(x, k)).First(v => v.Length > 0))));
            }
            if (kind == "refs")
            {
                var many = new ListBox { SelectionMode = SelectionMode.Multiple, ItemsSource = options, DisplayMemberPath = "Value", Height = 100 }; panel.Children.Add(many);
                readers[key] = () => new JsonArray(many.SelectedItems.Cast<KeyValuePair<string, string>>().Select(x => (JsonNode?)JsonValue.Create(x.Key)).ToArray());
            }
            else
            {
                var choices = new ComboBox { ItemsSource = options, DisplayMemberPath = "Value", SelectedValuePath = "Key", SelectedValue = kind == "choice" ? value : "", Margin = new Thickness(0, 0, 0, 12) }; panel.Children.Add(choices);
                readers[key] = () => JsonValue.Create(choices.SelectedValue?.ToString() ?? "");
            }
        }
        else
        {
            var input = host.Input(value); input.IsReadOnly = key == "quoteVersion"; panel.Children.Add(input);
            readers[key] = () =>
            {
                if (kind == "integer") return int.TryParse(input.Text, out var n) && n >= 0 ? JsonValue.Create(n) : throw new Exception("请输入有效整数");
                if (kind == "money")
                {
                    if (!decimal.TryParse(input.Text, NumberStyles.Number, CultureInfo.InvariantCulture, out var amount) || amount < 0 || amount * 100 != decimal.Truncate(amount * 100) || amount > long.MaxValue / 100) throw new Exception("请输入有效金额");
                    return JsonValue.Create((long)(amount * 100));
                }
                return JsonValue.Create(input.Text.Trim());
            };
        }
    }
}
