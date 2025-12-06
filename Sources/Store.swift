
import SwiftUI
import CoreImage.CIFilterBuiltins
import Foundation
import AppKit

@MainActor
class Store: ObservableObject {
    @Published var host: String = "Starting..."
    @Published var files: [String] = []
    @Published var qr: NSImage?
    @Published var busy: Bool = false
    @Published var pin: String = ""
    
    @Published var isTunneling: Bool = false
    @Published var findingTunnel: Bool = false
    private var tunnelProcess: Process?
    private var localAddress: String = ""
    
    private var serverTask: Task<Void, Never>?
    private let events = FileEvents()
    
    func boot() {
        if serverTask != nil { return }
        
        regeneratePin()
        
        let ip = Address.find() ?? "localhost"
        let port = 8080
        let base = "http://\(ip):\(port)"
        
        self.localAddress = base
        self.host = base
        self.generate(base)
        self.refresh()
        
        let onStatus: @Sendable (Bool) -> Void = { [weak self] active in
            Task { @MainActor in
                self?.busy = active
            }
        }
        
        let onRefresh: @Sendable () -> Void = { [weak self] in
            Task { @MainActor in
                self?.playSound("Glass")
                self?.refresh()
            }
        }
        
        let pinProvider: @Sendable () async -> String = { [weak self] in
            await MainActor.run {
                self?.pin ?? ""
            }
        }
        
        serverTask = Task.detached {
            let server = Host(
                port: port,
                onStatus: onStatus,
                onRefresh: onRefresh,
                pinProvider: pinProvider,
                events: self.events
            )
            do {
                try await server.launch()
            } catch {
                print("Server failed to start: \(error)")
            }
        }
    }
    
    func regeneratePin() {
        self.pin = String(format: "%04d", Int.random(in: 0...9999))
    }
    
    func generate(_ string: String) {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        
        if let output = filter.outputImage {
            let colorFilter = CIFilter.falseColor()
            colorFilter.inputImage = output
            colorFilter.color0 = CIColor(red: 0, green: 0, blue: 0, alpha: 1)
            colorFilter.color1 = CIColor(red: 0, green: 0, blue: 0, alpha: 0)
            
            if let colored = colorFilter.outputImage {
                if let cg = context.createCGImage(colored, from: colored.extent) {
                    self.qr = NSImage(cgImage: cg, size: NSSize(width: 200, height: 200))
                }
            }
        }
    }
    
    func refresh() {
        let url = Storage.location
        do {
            let urls = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            let names = urls.map { $0.lastPathComponent }.filter { !$0.hasPrefix(".") }
            self.files = names.sorted()
        } catch {}
        
        Task {
            await events.signal()
        }
    }
    
    func open(_ name: String) {
        let url = Storage.location.appendingPathComponent(name)
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
    }
    
    func clear() {
        let url = Storage.location
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            for fileURL in fileURLs {
                try FileManager.default.removeItem(at: fileURL)
            }
        } catch {
            print("Error clearing cache: \(error)")
        }
        refresh()
        playSound("Purr")
    }
    
    func playSound(_ name: String) {
        NSSound(named: name)?.play()
    }
    
    func toggleTunnel() {
        if isTunneling {
            stopTunnel()
        } else {
            startTunnel()
        }
    }
    
    private func stopTunnel() {
        tunnelProcess?.terminate()
        tunnelProcess = nil
        isTunneling = false
        findingTunnel = false
        playSound("Bottle")
        
        self.host = self.localAddress
        self.generate(self.localAddress)
    }
    
    private func startTunnel() {
        var executableURL: URL?

        if let bundleURL = Bundle.module.url(forResource: "cloudflared", withExtension: nil) {
            let tempDir = FileManager.default.temporaryDirectory
            let targetURL = tempDir.appendingPathComponent("cloudflared")
            
            do {
                if FileManager.default.fileExists(atPath: targetURL.path) {
                    try FileManager.default.removeItem(at: targetURL)
                }
                
                try FileManager.default.copyItem(at: bundleURL, to: targetURL)
                
                let chmod = Process()
                chmod.executableURL = URL(fileURLWithPath: "/bin/chmod")
                chmod.arguments = ["+x", targetURL.path]
                try chmod.run()
                chmod.waitUntilExit()
                
                executableURL = targetURL
            } catch {
                print("Failed to prepare bundled cloudflared: \(error)")
            }
        }
        
        if executableURL == nil {
            let paths = [
                "/opt/homebrew/bin/cloudflared",
                "/usr/local/bin/cloudflared",
                "/usr/bin/cloudflared"
            ]
            if let path = paths.first(where: { FileManager.default.fileExists(atPath: $0) }) {
                executableURL = URL(fileURLWithPath: path)
            }
        }
        
        guard let finalURL = executableURL else {
            print("cloudflared binary not found in bundle or system paths.")
            self.isTunneling = false
            playSound("Basso")
            return
        }
        
        findingTunnel = true
        isTunneling = true
        
        let task = Process()
        task.executableURL = finalURL
        task.arguments = ["tunnel", "--url", "http://localhost:8080"]
        
        let pipe = Pipe()
        task.standardError = pipe
        
        task.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                self?.stopTunnel()
            }
        }
        
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let str = String(data: data, encoding: .utf8) {
                if let range = str.range(of: "https://[a-zA-Z0-9-]+\\.trycloudflare\\.com", options: .regularExpression) {
                    let url = String(str[range])
                    Task { @MainActor in
                        guard let self = self else { return }
                        if self.findingTunnel {
                            self.host = url
                            self.generate(url)
                            self.playSound("Hero")
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                self.findingTunnel = false
                            }
                        }
                    }
                }
            }
        }
        
        do {
            try task.run()
            self.tunnelProcess = task
        } catch {
            print("Failed to run cloudflared: \(error)")
            stopTunnel()
        }
    }
}
