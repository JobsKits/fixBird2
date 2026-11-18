// Created by Jobs. Local-only disposable demo authentication, with code expiry and salted password hashes.
using System.Net.Mail;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using static RepairDesktop.WorkbenchClient;

namespace RepairDesktop;

sealed class LocalDemoAuthentication
{
    sealed record Account(string Username,string Email,byte[] Salt,byte[] Digest,string Id,string CompanyId="ios-demo-company-a",string Name="");
    sealed record Code(string Value,DateTimeOffset Expires,DateTimeOffset Sent,int Attempts);
    readonly JsonObject seeds;
    public LocalDemoAuthentication(JsonObject seeds) { this.seeds=seeds; }
    readonly Dictionary<string,Account> accounts=new(StringComparer.OrdinalIgnoreCase);
    readonly Dictionary<string,Code> codes=new(StringComparer.OrdinalIgnoreCase);
    public void Reset(){accounts.Clear();codes.Clear();}
    public JsonObject Login(JsonObject values,Func<string,string> t)
    {
        string name=S(values,"username"),password=S(values,"password");
        if(seeds[name] is JsonObject seed && password==(name=="admin"?"1234":"Demo-Repair-2026!"))return seed["actor"]!.DeepClone().AsObject();
        var account=accounts.Values.FirstOrDefault(a=>a.Username.Equals(name,StringComparison.OrdinalIgnoreCase)||a.Email.Equals(name,StringComparison.OrdinalIgnoreCase));
        if(account==null||!CryptographicOperations.FixedTimeEquals(account.Digest,Hash(password,account.Salt)))throw new ApiException(401,t("请填写账号和密码。"));
        return new(){["id"]=account.Id,["username"]=account.Username,["name"]=account.Name.Length>0?account.Name:account.Username,["email"]=account.Email,["role"]="customer",["companyId"]=account.CompanyId,["status"]="active",["authVersion"]=1};
    }
    public JsonObject Perform(string path,JsonObject values,Func<string,string> t)
    {
        string email=S(values,"email").Trim().ToLowerInvariant();
        if(!MailAddress.TryCreate(email,out var parsed)||parsed.Address!=email)throw new ApiException(422,t("请核对填写内容"));
        if(path=="/auth/email-code")
        {
            string purpose=S(values,"purpose");if(purpose is not ("register" or "reset_password"))throw new ApiException(422,t("请核对填写内容"));
            string key=email+":"+purpose;
            if(codes.TryGetValue(key,out var previous)&&DateTimeOffset.UtcNow<previous.Sent.AddSeconds(60))throw new ApiException(429,t("验证码已发送"));
            string code=RandomNumberGenerator.GetInt32(1000000).ToString("D6");var now=DateTimeOffset.UtcNow;codes[key]=new(code,now.AddMinutes(10),now,0);
            return new(){["demoCode"]=code,["expiresIn"]=600};
        }
        bool register=path=="/register";
        if(!register&&path!="/reset-password")throw new ApiException(404,t("请核对填写内容"));
        string password=S(values,"password");
        if(password.Length<8||Encoding.UTF8.GetByteCount(password)>256||password!=S(values,"confirmPassword"))throw new ApiException(422,t("请核对填写内容"));
        string user=S(values,"username");
        if(register&&(!Regex.IsMatch(user,@"^[\p{L}\p{N}_-]{3,32}$")||seeds.ContainsKey(user)||accounts.Values.Any(a=>a.Username.Equals(user,StringComparison.OrdinalIgnoreCase)||a.Email==email)))throw new ApiException(409,t("请核对填写内容"));
        string lookup=email+":"+(register?"register":"reset_password");
        if(!codes.TryGetValue(lookup,out var current)||current.Expires<DateTimeOffset.UtcNow||current.Attempts>=5)throw new ApiException(422,t("请核对填写内容"));
        codes[lookup]=current with{Attempts=current.Attempts+1};
        if(!CryptographicOperations.FixedTimeEquals(Encoding.UTF8.GetBytes(current.Value),Encoding.UTF8.GetBytes(S(values,"code"))))throw new ApiException(422,t("请核对填写内容"));
        if(register)
        {
            var salt=RandomNumberGenerator.GetBytes(16);accounts[user]=new(user,email,salt,Hash(password,salt),"demo-"+Guid.NewGuid());
        }
        else
        {
            var existing=accounts.Values.FirstOrDefault(a=>a.Email==email);if(existing==null)throw new ApiException(404,t("请核对填写内容"));
            var salt=RandomNumberGenerator.GetBytes(16);accounts[existing.Username]=existing with{Salt=salt,Digest=Hash(password,salt)};
        }
        codes.Remove(lookup);return new(){["ok"]=true};
    }
    public JsonObject AddDirectoryAccount(JsonObject body,string companyId)
    {
        string username=S(body,"username"),password=S(body,"password");
        if(!Regex.IsMatch(username,@"^[\p{L}\p{N}_-]{3,32}$")||seeds.ContainsKey(username)||accounts.ContainsKey(username)||password.Length<8||Encoding.UTF8.GetByteCount(password)>256||password!=S(body,"confirmPassword"))throw new ApiException(422,"请核对填写内容");
        var salt=RandomNumberGenerator.GetBytes(16);var id="ios-demo-directory-"+Guid.NewGuid();
        var name=S(body,"accountName");if(name.Length==0)name=S(body,"name");if(name.Length==0)name=username;
        accounts[username]=new(username,"",salt,Hash(password,salt),id,companyId,name);
        return new(){["id"]=id,["username"]=username,["name"]=name,["role"]="customer",["companyId"]=companyId,["status"]="active",["authVersion"]=1};
    }
    static byte[] Hash(string value,byte[] salt)=>Rfc2898DeriveBytes.Pbkdf2(value,salt,150000,HashAlgorithmName.SHA256,32);
}
