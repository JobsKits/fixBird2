// Created by Jobs. Both native clients use the same explicit Unicode password policy.
using System.IO;
using System.Globalization;
using System.Text;
using System.Text.Json.Nodes;

namespace RepairDesktop;

static class PasswordCharacterPolicy
{
    public const string ErrorMessage="密码不能包含表情符号";
    static readonly JsonObject Data=JsonNode.Parse(File.ReadAllText(Path.Combine(AppContext.BaseDirectory,"Resources","password-emoji-ranges.json")))!.AsObject();
    static readonly (int First,int Last)[] Emoji=ReadRanges("Emoji");

    public static bool IsValid(string value)
    {
        bool previousEmojiBase=false;
        foreach(var rune in value.EnumerateRunes())
        {
            int code=rune.Value;
            bool emoji=InRanges(code,Emoji);
            if(code is 0xFE0F or 0x20E3 || emoji&&code>0x7F&&code is not (0x00A9 or 0x00AE or 0x2122))return false;
            if(previousEmojiBase&&(code==0x200D||code is >=0xE0020 and <=0xE007F))return false;
            bool extends=code==0x200C||Rune.GetUnicodeCategory(rune) is UnicodeCategory.NonSpacingMark or UnicodeCategory.SpacingCombiningMark or UnicodeCategory.EnclosingMark;
            previousEmojiBase=code>0x7F&&emoji||extends&&previousEmojiBase;
        }
        return true;
    }

    static (int First,int Last)[] ReadRanges(string property)=>
        Data["properties"]![property]!.AsArray().Select(row=>(row![0]!.GetValue<int>(),row[1]!.GetValue<int>())).ToArray();

    static bool InRanges(int code,(int First,int Last)[] ranges)
    {
        foreach(var range in ranges)
        {
            if(code<range.First)return false;
            if(code<=range.Last)return true;
        }
        return false;
    }
}

