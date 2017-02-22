//
//  AppDelegate.swift
//  wallet
//
//  Created by Chris Downie on 10/4/16.
//  Copyright © 2016 Learning Machine, Inc. All rights reserved.
//

import UIKit
import JSONLD

private let sampleCertificateResetKey = "resetSampleCertificate"

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    // The app has launched normally
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        let commandLineArguments = ProcessInfo.processInfo.arguments
        if commandLineArguments.contains(Arguments.resetData) {
            resetData()
        }
        
        setupApplication()
        launchApplication()
        return true
    }
    
    // The app has launched from a universal link
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([Any]?) -> Void) -> Bool {
        setupApplication()
        
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
            let url = userActivity.webpageURL {
            
            return importState(from: url)
        }

        return true
    }
    
    // The app is launching with a document
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        setupApplication()
        return launchAddCertificate(at: url)
    }
    
    func setupApplication() {
        self.window?.addSubview(JSONLD.shared.webView)
        // Need a way to make this more obvious. Referencing the shared singleton
        Analytics.shared.applicationDidLaunch()
        
        UIButton.appearance().tintColor = Colors.brandColor
        
        // Reset state if needed
        if UserDefaults.standard.bool(forKey: sampleCertificateResetKey) {
            print("Reloading the sample certificate...\n\n")
            UserDefaults.standard.set(false, forKey: sampleCertificateResetKey)
        }
    }
    
    func launchApplication() {
//        let targetWidth = self.window?.bounds.width;
//        var layoutForWidth = UICollectionViewLayout()
//        layoutForWidth.
//        let issuerCollection = IssuerCollectionViewController(collectionViewLayout: <#T##UICollectionViewLayout#>)
//        let navigation = UINavigationController(rootViewController: <#T##UIViewController#>)
    }
    
    func importState(from url: URL) -> Bool {
        guard let fragment = url.fragment else {
            return deprecatedImportState(from: url)
        }
        
        var pathComponents = fragment.components(separatedBy: "/")
        guard pathComponents.count >= 1 else {
            return false
        }
        
        // For paths that start with /, the first one will be an empty string. So the true command name is the second element in the array.
        var commandName = pathComponents.removeFirst()
        if commandName == "" && pathComponents.count >= 1 {
            commandName = pathComponents.removeFirst()
        }
        
        switch commandName {
        case "import-certificate":
            guard pathComponents.count >= 1 else {
                return false
            }
            let encodedCertificateURL = pathComponents.removeFirst()
            if let decodedCertificateString = encodedCertificateURL.removingPercentEncoding,
                let certificateURL = URL(string: decodedCertificateString) {
                print()
                print(decodedCertificateString)
                print()
                return launchAddCertificate(at: certificateURL)
            } else {
                return false
            }
            
        case "introduce-recipient":
            guard pathComponents.count >= 2 else {
                return false
            }
            let encodedIdentificationURL = pathComponents.removeFirst()
            let encodedNonce = pathComponents.removeFirst()
            if let decodedIdentificationString = encodedIdentificationURL.removingPercentEncoding,
                let identificationURL = URL(string: decodedIdentificationString),
                let nonce = encodedNonce.removingPercentEncoding {
                launchAddIssuer(at: identificationURL, with: nonce)
                return true
            } else {
                return false
            }

        default:
            return false
        }
    }
    
    func deprecatedImportState(from url:URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return false
        }
        
        switch components.path {
        case "/demourl":
            var identificationURL: URL?
            var nonce : String?
            
            components.queryItems?.forEach { (queryItem) in
                switch queryItem.name {
                case "identificationURL":
                    if let urlString = queryItem.value,
                        let urlDecodedString = urlString.removingPercentEncoding {
                        identificationURL = URL(string: urlDecodedString)
                    }
                case "nonce":
                    nonce = queryItem.value
                default:
                    break;
                }
            }
            
            if identificationURL != nil && nonce != nil {
                print("got url \(identificationURL!) and nonce \(nonce!)")
                launchAddIssuer(at: identificationURL!, with: nonce!)
                return true
            } else {
                print("Got demo url but didn't have both components")
                return false
            }
        case "/importCertificate":
            let urlComponents = components.queryItems?.filter { queryItem -> Bool in
                return queryItem.name == "certificateURL"
            }
            if let urlString = urlComponents?.first?.value,
                let urlDecodedString = urlString.removingPercentEncoding,
                let certificateURL = URL(string: urlDecodedString) {
                return launchAddCertificate(at: certificateURL)
            } else {
                return false
            }
        default:
            print("I don't know about \(components.path)")
            return false
        }

    }
    
    func launchAddIssuer(at introductionURL: URL, with nonce: String) {
        let rootController = window?.rootViewController as? UINavigationController
        
        rootController?.presentedViewController?.dismiss(animated: false, completion: nil)
        _ = rootController?.popToRootViewController(animated: false)
        
        let issuerCollection = rootController?.viewControllers.first as? IssuerCollectionViewController
        
        issuerCollection?.showAddIssuerFlow(identificationURL: introductionURL, nonce: nonce)
    }
    
    func launchAddCertificate(at url: URL) -> Bool {
        let rootController = window?.rootViewController as? UINavigationController
        
        rootController?.presentedViewController?.dismiss(animated: false, completion: nil)
        _ = rootController?.popToRootViewController(animated: false)
        
        let issuerCollection = rootController?.viewControllers.first as? IssuerCollectionViewController
        return issuerCollection?.add(certificateURL: url) ?? false
    }

    func resetData() {
        // Delete all certificates
        do {
            for certificateURL in try FileManager.default.contentsOfDirectory(at: Paths.certificatesDirectory, includingPropertiesForKeys: nil, options: []) {
                try FileManager.default.removeItem(at: certificateURL)
            }
        } catch {
        }
        
        // Delete Issuers, Certificates folder, and everything else in documents directory.
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        do {
            let allFiles = try FileManager.default.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil, options: [])
            for fileURL in allFiles {
                try FileManager.default.removeItem(at: fileURL)
            }
        } catch {
            
        }

    }
}

