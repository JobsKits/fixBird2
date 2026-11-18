using System.Net;
using System.Text.Json.Nodes;
using RepairDesktop;

static class PasswordPolicySmoke
{
    public static async Task Run()
    {
        int checks=0;
        void Check(bool value,string reason){checks++;if(!value)throw new Exception(reason);}
        foreach(string value in new[]{"", "1234", "Demo-Repair-2026!", "#*0123456789", "中文繁體བོད་ཡིག日本語한국어", "Deutsch-Français-Español", "Русскийالعربية", "©®™", "©\uFE0E", "क्\u200Dष", "123#*क्\u200Dष", "©123क्\u200Dष", "\U00020000\U00013000"})
            Check(PasswordCharacterPolicy.IsValid(value),"ordinary password characters must remain valid");
        foreach(string value in new[]{"abc😀", "❤", "♥", "☀", "☹", "☺", "🇨🇳", "👍🏽", "👩‍🔧", "1️⃣", "#\u20E3", "*\uFE0F\u20E3", "©\uFE0F", "©\u200D", "©\u0301\u200D", "©\u200C\u200D", "™\u200D©", "®\U000E0067\U000E007F", "\uFE0F", "\u20E3", "\U0001FAEA"})
            Check(!PasswordCharacterPolicy.IsValid(value),"emoji or emoji sequence must be rejected");
        for(int code=0x20;code<=0x7E;code++)Check(PasswordCharacterPolicy.IsValid(((char)code).ToString()),"all printable ASCII must remain valid");
        var ranges=JsonNode.Parse(File.ReadAllText(Path.Combine(AppContext.BaseDirectory,"Resources","password-emoji-ranges.json")))!.AsObject();
        Check(ranges["unicodeVersion"]!.ToString()=="18.0.0","canonical Unicode version");
        int codepoints=0;
        foreach(var range in ranges["properties"]!["Emoji"]!.AsArray())
            for(int code=range![0]!.GetValue<int>();code<=range[1]!.GetValue<int>();code++)
            {
                bool allowed=code<=0x7F||code is 0x00A9 or 0x00AE or 0x2122;
                Check(PasswordCharacterPolicy.IsValid(char.ConvertFromUtf32(code))==allowed,"every canonical Emoji scalar follows the same password policy");codepoints++;
            }
        var handler=new NoNetwork();using var client=new WorkbenchClient(handler);
        async Task Rejected(Func<Task> action)
        {
            try{await action();throw new Exception("emoji password accepted before API");}
            catch(InvalidDataException error){Check(error.Message==PasswordCharacterPolicy.ErrorMessage,"visible password error");}
        }
        await Rejected(()=>client.Login("admin","1234😀"));
        await Rejected(async()=>await client.Authentication("/register",new(){["password"]="Valid-2026!",["confirmPassword"]="Valid-2026!❤"}));
        await Rejected(async()=>await client.Authentication("/reset-password",new(){["password"]="😀",["confirmPassword"]="😀"}));
        await Rejected(async()=>await client.CreateDirectoryEntry(new(){["operation"]="account",["password"]="Valid-2026!☀"}));
        Check(handler.Requests==0,"invalid password must never reach health checks or writes");
        Console.WriteLine($"PASS: {checks} password-policy checks; {codepoints} canonical Unicode18 Emoji scalars, ordinary multilingual/ASCII text, bare hearts, flags/skin/ZWJ/tag/keycap/VS16, and login/register/reset/directory rejection before HTTP (macOS CLI; WPF interaction untested)");
    }

    sealed class NoNetwork:HttpMessageHandler
    {
        public int Requests;
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request,CancellationToken cancel)
        {
            Requests++;throw new Exception("password policy allowed unexpected network access");
        }
    }
}
