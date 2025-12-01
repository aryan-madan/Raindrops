
import Foundation
import SwiftUI
import AppKit

struct Address {
    static func find() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                
                let interface = ptr?.pointee
                let addrFamily = interface?.ifa_addr.pointee.sa_family
                
                if addrFamily == UInt8(AF_INET) {
                    if let name = String(validatingCString: interface!.ifa_name) {
                        if name == "en0" { // Usually Wi-Fi
                            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                            getnameinfo(interface?.ifa_addr, socklen_t((interface?.ifa_addr.pointee.sa_len)!),
                                        &hostname, socklen_t(hostname.count),
                                        nil, socklen_t(0), NI_NUMERICHOST)
                            
                            address = hostname.withUnsafeBufferPointer { ptr in
                                String(cString: ptr.baseAddress!)
                            }
                        }
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        return address
    }
}

struct Storage {
    static var location: URL {
        let url = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0].appendingPathComponent("Raindrops")
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }
}
