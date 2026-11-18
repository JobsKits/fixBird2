// Created by Jobs. Pictures and videos use Windows image codecs and MediaElement.
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;

namespace RepairDesktop;

static class NativeMediaPreview
{
    public static void OpenFile(MainWindow host,Window owner,string name,string mime,string path)
    {
        var window=new Window{Owner=owner,Title=name,Width=850,Height=660,Background=host.Background,Foreground=host.Foreground};
        if(mime.StartsWith("image/",StringComparison.Ordinal))
        {
            var image=new System.Windows.Media.Imaging.BitmapImage();image.BeginInit();image.DecodePixelWidth=1400;image.CacheOption=System.Windows.Media.Imaging.BitmapCacheOption.OnLoad;image.UriSource=new Uri(path);image.EndInit();image.Freeze();window.Content=new Image{Source=image,Stretch=Stretch.Uniform};
        }
        else
        {
            var player=new MediaElement{Source=new Uri(path),LoadedBehavior=MediaState.Manual,UnloadedBehavior=MediaState.Stop,Stretch=Stretch.Uniform};
            player.Loaded+=(_,_)=>player.Play();
            var root=new DockPanel();var actions=new StackPanel{Orientation=Orientation.Horizontal};actions.Children.Add(host.Button("播放",player.Play));actions.Children.Add(host.Button("暂停",player.Pause));DockPanel.SetDock(actions,Dock.Bottom);root.Children.Add(actions);root.Children.Add(player);window.Content=root;window.Closed+=(_,_)=>{player.Stop();player.Source=null;};
        }
        window.ShowDialog();
    }
    public static void Open(MainWindow host,Window owner,string name,string mime,byte[] bytes)
    {
        var window=new Window{Owner=owner,Title=name,Width=850,Height=660,Background=host.Background,Foreground=host.Foreground};
        if(mime.StartsWith("image/",StringComparison.Ordinal))window.Content=new Image{Source=NativeLoanDialog.Decode(bytes),Stretch=Stretch.Uniform};
        else
        {
            string extension=mime=="video/mp4"?".mp4":mime=="video/quicktime"?".mov":".webm";
            string path=Path.Combine(Path.GetTempPath(),"RepairDesktop-preview-"+Guid.NewGuid()+extension);
            using(var file=new FileStream(path,FileMode.CreateNew,FileAccess.Write,FileShare.None))file.Write(bytes);
            var player=new MediaElement{Source=new Uri(path),LoadedBehavior=MediaState.Manual,UnloadedBehavior=MediaState.Stop,Stretch=Stretch.Uniform};
            var root=new DockPanel();var actions=new StackPanel{Orientation=Orientation.Horizontal};actions.Children.Add(host.Button("播放",player.Play));actions.Children.Add(host.Button("暂停",player.Pause));DockPanel.SetDock(actions,Dock.Bottom);root.Children.Add(actions);root.Children.Add(player);window.Content=root;
            window.Closed+=(_,_)=>{player.Stop();player.Source=null;try{File.Delete(path);}catch(IOException){}};
        }
        window.ShowDialog();
    }
}
