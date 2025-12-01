import SwiftUI
import CoreImage.CIFilterBuiltins

@MainActor
class Store: ObservableObject {
    @Published var host: String = "Starting..."
    @Published var files: [String] = []
    @Published var qr: NSImage?
    @Published var busy: Bool = false
    
    private var serverTask: Task<Void, Never>?
    
    func boot() {
        let ip = Address.find() ?? "localhost"
        let port = 8080
        let base = "http://\(ip):\(port)"
            
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
                self?.refresh()
            }
        }
        
        serverTask = Task.detached {
            let server = Host(port: port, onStatus: onStatus, onRefresh: onRefresh)
            do {
                try await server.launch()
            } catch {
                print("Server failed to start: \(error)")
            }
        }
    }
    
    func generate(_ string: String) {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        
        if let output = filter.outputImage {
            let colorFilter = CIFilter.falseColor()
            colorFilter.inputImage = output
            colorFilter.color0 = CIColor(red: 1, green: 1, blue: 1, alpha: 1)
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
    }
}