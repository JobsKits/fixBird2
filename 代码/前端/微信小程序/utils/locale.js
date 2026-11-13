// Jobs · 仅翻译界面标签，保留业务字段、请求值和客户内容。
let catalog = {messages:{}};
try { catalog = require('../assets/ui-l10n.json'); } catch (_) {}
const languages = [{code:'zh-Hans',name:'简体中文'},{code:'zh-Hant',name:'繁體中文'},{code:'bo',name:'བོད་ཡིག'},{code:'en',name:'English'},{code:'ja',name:'日本語'},{code:'fr',name:'Français'},{code:'es',name:'Español'},{code:'de',name:'Deutsch'},{code:'ru',name:'Русский'},{code:'ko',name:'한국어'}];
function language(){return wx.getStorageSync('repair-language')||'zh-Hans';}
function tr(value){return ((catalog.messages||{})[language()]||{})[value]||value;}
function state(){const keys=Object.keys((catalog.messages||{}).en||{});const ui={};for(const key of keys)ui[key]=tr(key);return {ui,languages,language:language(),languageIndex:Math.max(0,languages.findIndex(x=>x.code===language())),appearance:wx.getStorageSync('repair-appearance')||'system',appearanceNames:[tr('跟随系统'),tr('白天'),tr('黑夜')]};}
function display(parts){const compact=['zh-Hans','zh-Hant','ja'].includes(language());return parts.map(tr).reduce((result,part)=>{const gap=!compact&&result&&part&&!/\s$/.test(result)&&!/^\s/.test(part)?' ':'';return result+gap+part;},'');}
function notice(store){return display(store.messageParts||[store.message]);}
function errorText(error){if(error.uiField&&error.uiInstruction)return error.uiField+'：'+tr(error.uiInstruction);return display(error.uiParts||[error.message||'操作未完成']);}
module.exports={tr,state,languages,notice,errorText};
