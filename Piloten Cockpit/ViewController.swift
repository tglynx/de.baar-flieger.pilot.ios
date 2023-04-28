//
//  ViewController.swift
//  wkwebview
//
//  Created by Michael Sommer
//

import UIKit
import WebKit
import Reachability

class ViewController: UIViewController, WKUIDelegate, WKNavigationDelegate {
    
    var webView: WKWebView!

    let reachability = try! Reachability()
    
    override func loadView() {
        
        let webConfiguration = WKWebViewConfiguration()
        
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        
        webView.uiDelegate = self
        webView.navigationDelegate = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(networkStatusChanged), name: .reachabilityChanged, object: reachability)
        
        view = webView
        
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // webView.frame = view.bounds            // previously
        let topPadding = view.safeAreaInsets.top
        webView.frame = view.frame.inset(by: UIEdgeInsets(top: topPadding, left: CGFloat(0), bottom: CGFloat(0), right: CGFloat(0)))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let url = URL(string: "https://pilot.baar-flieger.de/app/benutzer")!
        webView.load(URLRequest(url: url))
        webView.allowsBackForwardNavigationGestures = true
        
        //view.backgroundColor = .red
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        NSLog("did fail provisional navigation %@", error as NSError)
        let url = Bundle.main.url(forResource: "error", withExtension: "html")!
        webView.loadFileURL(url, allowingReadAccessTo: url)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        NSLog("did fail navigation %@", error as NSError)
        let url = Bundle.main.url(forResource: "error", withExtension: "html")!
        webView.loadFileURL(url, allowingReadAccessTo: url)
    }
    
    
    @objc func networkStatusChanged(notification: Notification) {
        let reachability = notification.object as! Reachability
        
        switch reachability.connection {
        case .unavailable:
            let url = Bundle.main.url(forResource: "error", withExtension: "html")!
            webView.loadFileURL(url, allowingReadAccessTo: url)
        default:
            let url = URL(string: "https://pilot.baar-flieger.de/app/benutzer")!
            webView.load(URLRequest(url: url))
        }
        
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
}

