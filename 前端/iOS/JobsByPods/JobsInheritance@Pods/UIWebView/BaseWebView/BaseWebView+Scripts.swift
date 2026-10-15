//
//  BaseWebView+Scripts.swift
//  JobsInheritance
//
//  Created by Jobs on 2026年5月13日，星期三.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

import WebKit

// ===== WK Script Bridge / UserScripts =====
public extension BaseWebView {
    static func makeBridgeUserScript() -> WKUserScript {
        let js = """
        (function() {
          if (window.Native) return;
          const _callbacks = {};
          let _seq = 0;

          window.__nativeReturn = function(id, value) {
            const cb = _callbacks[id];
            if (cb) { delete _callbacks[id]; try { cb(value); } catch(e) { console.error(e); } }
          };

          function _post(name, payload) {
            try { window.webkit.messageHandlers.bridge.postMessage({ name:name, payload:payload ?? null }); }
            catch(e){ console.error('bridge.post failed', e); }
          }
          function _call(name, payload) {
            const id = ++_seq;
            try {
              return new Promise(function(resolve){
                _callbacks[id] = resolve;
                window.webkit.messageHandlers.bridge.postMessage({ name:name, payload:payload ?? null, id:id });
              });
            } catch(e){ console.error('bridge.call failed', e); return Promise.reject(e); }
          }
          function _emit(name, detail) {
            try { document.dispatchEvent(new CustomEvent(name, { detail: detail })); }
            catch(e){ console.error('emit failed', e); }
          }
          function _on(name, fn) {
            document.addEventListener(name, function(e){ try { fn && fn(e.detail); } catch(e){ console.error(e); } });
          }

          ['log','warn','error'].forEach(function(level){
            const old = console[level];
            console[level] = function(){
              try { window.webkit.messageHandlers.console.postMessage({ level:level, args:[].slice.call(arguments) }); } catch(_){}
              old && old.apply(console, arguments);
            };
          });
          window.onerror = function(msg, src, line, col, err){
            try { window.webkit.messageHandlers.console.postMessage({ level:'error', args:[String(msg||''), String(src||''), line||0, col||0, String((err&&err.stack)||'')] }); } catch(_){}
          };
          window.onunhandledrejection = function(e){
            try { window.webkit.messageHandlers.console.postMessage({ level:'error', args:['unhandledrejection', String((e&&e.reason)||'')] }); } catch(_){}
          };

          window.Native = { post:_post, call:_call, emit:_emit, on:_on };
        })();
        """
        if #available(iOS 14.0, *) {
            return WKUserScript(source: js,
                                injectionTime: .atDocumentStart,
                                forMainFrameOnly: false,
                                in: .page)
        } else {
            return WKUserScript(source: js,
                                injectionTime: .atDocumentStart,
                                forMainFrameOnly: false)
        }
    }
    /// 通用重定向修补脚本：仅升级 http→https，不做任何域名改写
    static func makeSanitizeUserScript() -> WKUserScript {
        let js = """
        (function(){
          function sanitize(u){
            try{
              var x = new URL(u, location.href);
              if (x.protocol === 'http:') x.protocol = 'https:';
              return x.href;
            }catch(e){ return u; }
          }
          var _assign = Location.prototype.assign;
          var _replace = Location.prototype.replace;
          Object.defineProperty(Location.prototype, 'assign', { value: function(u){ return _assign.call(this, sanitize(u)); }});
          Object.defineProperty(Location.prototype, 'replace', { value: function(u){ return _replace.call(this, sanitize(u)); }});
          var hrefDesc = Object.getOwnPropertyDescriptor(Location.prototype, 'href');
          Object.defineProperty(Location.prototype, 'href', {
            get: function(){ return hrefDesc.get.call(this); },
            set: function(u){ return _replace.call(this, sanitize(u)); }
          });
          var _open = window.open;
          Object.defineProperty(window, 'open', { value: function(u, t, f){
            if (typeof u === 'string') u = sanitize(u);
            return _open.call(window, u, t, f);
          }});
          try { console.log('[SanitizeJS] installed'); } catch(_){}
        })();
        """
        if #available(iOS 14.0, *) {
            return WKUserScript(source: js,
                                injectionTime: .atDocumentStart,
                                forMainFrameOnly: false,
                                in: .page)
        } else {
            return WKUserScript(source: js,
                                injectionTime: .atDocumentStart,
                                forMainFrameOnly: false)
        }
    }
}
// MARK: - Dark CSS / MobileBridge shim
extension BaseWebView {
    @MainActor
    func injectDarkCSSIfNeeded() {
        guard injectDarkStylePatch else { return }
        injectDarkCSS()
    }
    /// Dark CSS 注入（用于 injectDarkStylePatch）
    @MainActor
    func injectDarkCSS() {
        let css = """
        @media (prefers-color-scheme: dark) {
          html, body { background:#000 !important; color:#eee !important; }
        }
        """
        let js = "var s=document.createElement('style');s.innerHTML=\(BaseWebView.quote(css));document.head&&document.head.appendChild(s);"
        let script: WKUserScript
        if #available(iOS 14.0, *) {
            script = WKUserScript(source: js,
                                  injectionTime: .atDocumentEnd,
                                  forMainFrameOnly: false, in: .page)
        } else {
            script = WKUserScript(source: js,
                                  injectionTime: .atDocumentEnd,
                                  forMainFrameOnly: false)
        }
        webView.configuration.userContentController.addUserScript(script)
    }
    /// 极简 JS shim：前端没注入时兜底
    @MainActor
    func injectMinimalMobileShimIfNeeded() {
        guard mobileConfig.injectShim else { return }
        injectMinimalMobileShim()
    }

    @MainActor
    func injectMinimalMobileShim() {
        let js = """
        (function(){
          if (window.MobileBridge) return;
          function post(msg){
            try { window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.iOSBridge.postMessage(msg); }
            catch(e){ console && console.error('iOSBridge.post failed', e); }
          }
          window.MobileBridge = {
            showToast: function(message){ post({action:'showToast', message: String(message||'')}); },
            navigateToDeposit: function(){ post({action:'navigateToDeposit'}); },
            navigateToLogin: function(){ post({action:'navigateToLogin'}); },
            navigateToHome: function(){ post({action:'navigateToHome'}); },
            closeWebView: function(){ post({action:'closeWebView'}); },
            getToken: function(){
              return new Promise(function(resolve){
                var cb='__onToken_'+Date.now()+'_'+Math.random().toString(36).slice(2);
                window[cb]=function(t){ try{ resolve(t||null); } finally{ try{ delete window[cb]; }catch(_){} } };
                post({action:'getToken', callback: cb});
              });
            }
          };
          try { console.log('[iOS shim] MobileBridge installed'); } catch(_){}
        })();
        """
        let script: WKUserScript
        if #available(iOS 14.0, *) {
            script = WKUserScript(source: js,
                                  injectionTime: .atDocumentStart,
                                  forMainFrameOnly: false,
                                  in: .page)
        } else {
            script = WKUserScript(source: js,
                                  injectionTime: .atDocumentStart,
                                  forMainFrameOnly: false)
        };webView.configuration.userContentController.addUserScript(script)
    }
}
