import Foundation
import SystemConfiguration

class ConnectionStateMonitor {
    static let shared = ConnectionStateMonitor()

    private var reachability: SCNetworkReachability?
    private var isMonitoring = false

    // Notification to inform about network changes
    static let networkStatusChangedNotification = Notification.Name("NetworkStatusChanged")

    private init() {
        guard let reachability = SCNetworkReachabilityCreateWithName(nil, "www.apple.com") else { return }
        self.reachability = reachability
    }

    func startMonitoring() {
        guard let reachability = self.reachability, !isMonitoring else { return }

        var context = SCNetworkReachabilityContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
        context.info = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        if SCNetworkReachabilitySetCallback(reachability, { (_, flags, info) in
            guard let info = info else { return }
            let instance = Unmanaged<ConnectionStateMonitor>.fromOpaque(info).takeUnretainedValue()
            instance.handleNetworkChange(flags)
        }, &context) {

            if SCNetworkReachabilitySetDispatchQueue(reachability, DispatchQueue.main) {
                isMonitoring = true
            }
        }
    }

    func stopMonitoring() {
        guard let reachability = self.reachability, isMonitoring else { return }
        SCNetworkReachabilitySetCallback(reachability, nil, nil)
        SCNetworkReachabilitySetDispatchQueue(reachability, nil)
        isMonitoring = false
    }

    private func handleNetworkChange(_ flags: SCNetworkReachabilityFlags) {
        let isReachable = flags.contains(.reachable)
        let isConnectionRequired = flags.contains(.connectionRequired)

        // Check if the network is reachable and a connection is not required
        let isConnected = isReachable && !isConnectionRequired

        // Notify about the network status change
        NotificationCenter.default.post(name: ConnectionStateMonitor.networkStatusChangedNotification, object: nil, userInfo: ["isConnected": isConnected])
    }
}
