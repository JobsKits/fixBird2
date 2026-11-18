// Created by Jobs. Native password input with an accessible vector visibility toggle.
using System.Windows;
using System.Windows.Automation;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Media;
using System.Windows.Shapes;

namespace RepairDesktop;

sealed class NativePasswordField : Grid
{
    readonly PasswordBox hidden = new() { Padding = new Thickness(8), VerticalContentAlignment = VerticalAlignment.Center };
    readonly TextBox visible = new() { Padding = new Thickness(8), VerticalContentAlignment = VerticalAlignment.Center, Visibility = Visibility.Collapsed };
    readonly ToggleButton eye = new() { Width = 40, Height = 34, Margin = new Thickness(3, 0, 0, 0) };
    readonly Line slash = new() { X1 = 2, Y1 = 2, X2 = 22, Y2 = 18, StrokeThickness = 1.7, Visibility = Visibility.Collapsed };
    readonly Func<string, string> translate;
    readonly TextBlock validation = new() { TextWrapping=TextWrapping.Wrap, Foreground=Brushes.IndianRed, Margin=new Thickness(0,4,0,0), Visibility=Visibility.Collapsed };
    string value = "";
    bool updating;
    public string Password
    {
        get => value;
        set => SetValue(value);
    }

    public bool IsRevealed { get => eye.IsChecked == true; set => eye.IsChecked=value; }

    public NativePasswordField(string initial, Func<string, string> translate, bool revealed = false)
    {
        this.translate = translate;
        Margin = new Thickness(0, 3, 0, 10);
        MinHeight=42;hidden.MinHeight=42;visible.MinHeight=42;eye.Height=40;
        ColumnDefinitions.Add(new ColumnDefinition());
        ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        RowDefinitions.Add(new RowDefinition { Height=GridLength.Auto });
        RowDefinitions.Add(new RowDefinition { Height=GridLength.Auto });
        Children.Add(hidden);
        Children.Add(visible);
        SetColumn(eye, 1);
        Children.Add(eye);
        SetRow(validation,1);SetColumnSpan(validation,2);Children.Add(validation);
        var art = new Canvas { Width = 24, Height = 20, IsHitTestVisible = false };
        var outline = new System.Windows.Shapes.Path { Data = Geometry.Parse("M 1,10 C 6,1 18,1 23,10 C 18,19 6,19 1,10 Z"), StrokeThickness = 1.6 };
        var pupil = new Ellipse { Width = 6, Height = 6 };
        Canvas.SetLeft(pupil, 9);
        Canvas.SetTop(pupil, 7);
        art.Children.Add(outline);
        art.Children.Add(pupil);
        art.Children.Add(slash);
        eye.Content = art;
        var stroke = new System.Windows.Data.Binding("Foreground") { Source = eye };
        outline.SetBinding(System.Windows.Shapes.Path.StrokeProperty, stroke);
        pupil.SetBinding(Ellipse.FillProperty, stroke);
        slash.SetBinding(Line.StrokeProperty, stroke);
        hidden.PasswordChanged += (_, _) => { if (!updating) SetValue(hidden.Password); };
        visible.TextChanged += (_, _) => { if (!updating) SetValue(visible.Text); };
        hidden.PreviewTextInput += (_,e) => { if(!PasswordCharacterPolicy.IsValid(e.Text)){e.Handled=true;ShowInvalid();} };
        visible.PreviewTextInput += (_,e) => { if(!PasswordCharacterPolicy.IsValid(e.Text)){e.Handled=true;ShowInvalid();} };
        DataObject.AddPastingHandler(hidden,ValidatePaste);
        DataObject.AddPastingHandler(visible,ValidatePaste);
        eye.Checked += (_, _) => Reveal(true);
        eye.Unchecked += (_, _) => Reveal(false);
        SetValue(initial);
        eye.IsChecked = revealed;
        Reveal(revealed);
        AutomationProperties.SetName(hidden, translate("密码"));
        AutomationProperties.SetName(visible, translate("密码"));
    }

    void SetValue(string next)
    {
        if(PasswordCharacterPolicy.IsValid(next))
        {
            value=next;validation.Visibility=Visibility.Collapsed;
        }
        else ShowInvalid();
        updating = true;
        if (hidden.Password != value) hidden.Password = value;
        if (visible.Text != value) visible.Text = value;
        updating = false;
    }

    void ValidatePaste(object sender,DataObjectPastingEventArgs e)
    {
        var text=e.DataObject.GetData(DataFormats.UnicodeText) as string??e.DataObject.GetData(DataFormats.Text) as string??"";
        if(!PasswordCharacterPolicy.IsValid(text)){e.CancelCommand();ShowInvalid();}
    }

    void ShowInvalid()
    {
        validation.Text=translate(PasswordCharacterPolicy.ErrorMessage);
        validation.Visibility=Visibility.Visible;
    }

    public bool ValidateForSubmission()
    {
        if(validation.Visibility==Visibility.Visible||!PasswordCharacterPolicy.IsValid(value)){ShowInvalid();return false;}
        return true;
    }

    void Reveal(bool show)
    {
        hidden.Visibility = show ? Visibility.Collapsed : Visibility.Visible;
        visible.Visibility = show ? Visibility.Visible : Visibility.Collapsed;
        slash.Visibility = show ? Visibility.Visible : Visibility.Collapsed;
        eye.ToolTip = translate(show ? "隐藏密码" : "显示密码");
        AutomationProperties.SetName(eye, (string)eye.ToolTip);
    }

    public void Clear() => SetValue("");
}
