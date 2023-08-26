//
//  ViewController.swift
//  Piloten Cockpit
//
//  Created by Michael Sommer
//

import UIKit
import WebKit
import Reachability

class ViewController: UIViewController, WKUIDelegate, WKNavigationDelegate {
    
    var webView: WKWebView!
    var backButton: UIButton!
    
    let reachability = try! Reachability()
    
    // Declare a UIActivityIndicatorView property
    var activityIndicatorView: UIActivityIndicatorView!
    
    override func loadView() {
        
        let webConfiguration = WKWebViewConfiguration()
        
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        
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
        
        // Create and configure the activity indicator view
        activityIndicatorView = UIActivityIndicatorView(style: .large)
        activityIndicatorView.color = .gray
        activityIndicatorView.hidesWhenStopped = true
        view.addSubview(activityIndicatorView)
        activityIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            activityIndicatorView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicatorView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        webView.uiDelegate = self
        webView.navigationDelegate = self
        
        webView.alpha = 0
        
        let url = URL(string: "https://pilot.baar-flieger.de/app/piloten")!
        webView.load(URLRequest(url: url))
        webView.allowsBackForwardNavigationGestures = true
        
        // Create the back button
        backButton = UIButton(type: .custom)
        backButton.setTitle("<", for: .normal)
        backButton.titleLabel?.font = UIFont.systemFont(ofSize: 17.0)
        backButton.setTitleColor(.darkGray, for: .normal)
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backButton)
        
        // Position the back button in the upper-left corner of the view
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: guide.topAnchor, constant: 22),
            backButton.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 22),
            backButton.widthAnchor.constraint(equalToConstant: 30),
            backButton.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        // Customize the button's appearance
        let lightGrayColor = UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 0.7)
        backButton.backgroundColor = lightGrayColor
        backButton.layer.cornerRadius = 6.0
        backButton.layer.borderWidth = 1.0
        backButton.layer.borderColor = UIColor.clear.cgColor

        // Set initial visibility of the back button
        updateBackButtonVisibility()

    }

    @objc func backButtonTapped() {
        // Handle the back button tap event here
        webView.goBack()
    }
    
    func updateBackButtonVisibility() {
        if let url = webView.url, url.absoluteString.hasPrefix("https://pilot.baar-flieger.de/files") {
            backButton.isHidden = !webView.canGoBack
        } else {
            backButton.isHidden = true
        }
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        activityIndicatorView.startAnimating()
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        activityIndicatorView.stopAnimating()
        
        print("Current URL: \(webView.url?.absoluteString ?? "Unknown")")
        
        // Update the visibility of the back button
        updateBackButtonVisibility()

        if let currentURL = webView.url, currentURL.absoluteString == "https://pilot.baar-flieger.de/app/piloten" {
            
            let script = "document.cookie;"
            webView.evaluateJavaScript(script) { (result, error) in
                if let cookie = result as? String, !cookie.contains("budibase:auth") {
                    // User is not logged in, navigate to the Custom Login app
                    let newURL = URL(string: "https://pilot.baar-flieger.de/app/benutzer")!
                    webView.load(URLRequest(url: newURL))
                } else {
                    webView.alpha = 1
                }
            }
            
        } else {
            webView.alpha = 1
        }
            
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        print("decidePolicyFor URL: \(navigationAction.request.url?.absoluteString ?? "Unknown")")
        
        if let url = navigationAction.request.url, url.absoluteString.contains("/builder/") {
            let newURL = URL(string: "https://pilot.baar-flieger.de/app/benutzer")!
            webView.load(URLRequest(url: newURL))
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
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

