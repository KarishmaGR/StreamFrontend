//
//  AppStateManager.swift
//  LocationTracking
//
//  Created by enjay on 17/11/24.
//

import Foundation
import UIKit
import Network

class AppStateManager {
    private var isInternetConnected: Bool? = nil
    private var isAppInForeground: Bool? = nil
    
    private let monitor = NWPathMonitor()
    
    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let isConnected = path.status == .satisfied
            if self?.isInternetConnected != isConnected {
                self?.isInternetConnected = isConnected
                if isConnected {
                    print("Internet connection restored.")
                } else {
                    print("Internet connection lost.")
                }
            }
        }
        let queue = DispatchQueue(label: "InternetMonitor")
        monitor.start(queue: queue)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appStateDidChange),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appStateDidChange),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    @objc private func appStateDidChange() {
        let isForeground = UIApplication.shared.applicationState == .active
        if isAppInForeground != isForeground {
            isAppInForeground = isForeground
            if isForeground {
                print("App is in the foreground.")
            } else {
                print("App is in the background.")
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        monitor.cancel()
    }
}
