import SwiftUI
import AppKit

struct Home: View {
    @EnvironmentObject var store: Store
    @State private var showCopied: Bool = false

    let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 16)
    ]
    
    let brandColor = Color(red: 0, green: 203/255, blue: 1)

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(0.55))
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    if let url = Bundle.module.url(forResource: "Logo", withExtension: "svg"),
                       let nsImage = NSImage(contentsOf: url) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                    }

                    Text("Inbox")
                        .font(.system(size: 28, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.85))

                    Spacer()

                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            store.toggleTunnel()
                        }
                    }) {
                        HStack(spacing: 6) {
                            ZStack {
                                if store.findingTunnel {
                                    ProgressView()
                                        .controlSize(.small)
                                        .scaleEffect(0.7)
                                        .transition(.opacity.combined(with: .scale(scale: 0.5)))
                                } else {
                                    Image(systemName: "globe")
                                        .font(.system(size: 13, weight: .medium))
                                        .symbolEffect(.bounce, value: store.isTunneling)
                                        .transition(.opacity.combined(with: .scale(scale: 0.5)))
                                }
                            }
                            .frame(width: 14, height: 14)

                            Text(store.isTunneling ? "Public" : "Go Public")
                                .font(.system(size: 13, weight: .medium))
                                .fixedSize()
                                .geometryGroup()
                                .id(store.isTunneling)
                                .transition(.push(from: .bottom))
                        }
                        .foregroundStyle(store.isTunneling ? brandColor : Color.primary.opacity(0.8))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background {
                            ZStack {
                                if store.isTunneling {
                                    brandColor.opacity(0.15)
                                } else {
                                    Color.white.opacity(0.08)
                                }
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
                    }
                    .buttonStyle(.plain)

                    Button(action: { store.clear() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                                .font(.system(size: 13, weight: .medium))
                            Text("Clear Cache")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(.red.opacity(0.9))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.red.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 24)

                ZStack {
                    Color.white.opacity(0.04)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .ignoresSafeArea(edges: .bottom)

                    ScrollView {
                        if store.files.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "tray")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.secondary.opacity(0.4))
                                Text("Waiting for drops...")
                                    .font(.title3)
                                    .foregroundStyle(.secondary.opacity(0.6))
                            }
                            .padding(.top, 100)
                            .frame(maxWidth: .infinity)
                        } else {
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(store.files, id: \.self) { name in
                                    FileCard(name: name, store: store)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 24)
                            .padding(.bottom, 100)
                            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: store.files)
                        }
                    }
                }
            }

            VStack {
                Spacer()
                
                ZStack(alignment: .center) {
                    HStack {
                        Spacer()
                        Button(action: {
                            let pasteboard = NSPasteboard.general
                            pasteboard.clearContents()
                            pasteboard.setString(store.host, forType: .string)
                            store.playSound("Pop")
                            withAnimation(.snappy) {
                                showCopied = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    showCopied = false
                                }
                            }
                        }) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(store.isTunneling ? brandColor : Color.green)
                                    .frame(width: 8, height: 8)
                                    .shadow(color: (store.isTunneling ? brandColor : Color.green).opacity(0.6), radius: 4)

                                Text(showCopied ? "Copied Link!" : store.host)
                                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.9))
                                    .clipShape(Rectangle())
                                    .contentTransition(.numericText())
                            }
                            .padding(.horizontal, 20)
                            .frame(height: 48)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular, in: .capsule)
                        .clipShape(Capsule())
                        Spacer()
                    }
                    
                    HStack {
                        Spacer()
                        HStack(spacing: 8) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            
                            Text(store.pin)
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.9))
                                .contentTransition(.numericText())
                            
                            Button(action: {
                                withAnimation {
                                    store.regeneratePin()
                                }
                            }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .glassEffect(.regular, in: .capsule)
                        .padding(.trailing, 32)
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

struct FileCard: View {
    let name: String
    @ObservedObject var store: Store
    @State private var textPreview: String = ""

    var url: URL { Storage.location.appendingPathComponent(name) }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if isImage {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ZStack {
                            Color.black.opacity(0.2)
                            ProgressView()
                                .scaleEffect(0.6)
                        }
                    }
                } else if isText {
                    ZStack(alignment: .topLeading) {
                        Color.white.opacity(0.05)
                        Text(textPreview)
                            .font(.system(size: 7, design: .monospaced))
                            .foregroundStyle(.secondary.opacity(0.8))
                            .padding(12)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                    .task {
                        if textPreview.isEmpty {
                            textPreview = (try? String(contentsOf: url, encoding: .utf8))?.prefix(800).description ?? ""
                        }
                    }
                } else {
                    ZStack {
                        Color.white.opacity(0.05)
                        VStack(spacing: 8) {
                            Image(systemName: "doc.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(.secondary.opacity(0.25))
                            Text(url.pathExtension.uppercased())
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.secondary.opacity(0.4))
                        }
                    }
                }
            }
            .frame(height: 180)
            .frame(maxWidth: .infinity)

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.95))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)

                    Text(fileSize)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.7))
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                }
                Spacer()
            }
            .padding(10)
            .background(Color.black.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
            .padding(6)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            store.open(name)
        }
    }

    var isImage: Bool {
        ["jpg", "jpeg", "png", "gif", "heic", "webp"].contains(url.pathExtension.lowercased())
    }

    var isText: Bool {
        ["txt", "md", "json", "swift", "js", "html", "css", "xml", "log", "py", "rs", "ts"].contains(url.pathExtension.lowercased())
    }

    var fileSize: String {
        guard let attr = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attr[.size] as? Int64 else { return "--" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

struct MenuBarView: View {
    @EnvironmentObject var store: Store
    @Environment(\.openWindow) var openWindow
    @State private var isHoveringCopy = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {  
                Text("Raindrops")
                    .font(.system(size: 13, weight: .semibold))
                
                Spacer()
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(store.isTunneling ? Color(red: 0, green: 203/255, blue: 1) : Color.green)
                        .frame(width: 6, height: 6)
                    Text(store.isTunneling ? "Public" : "Local")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.06))
                .clipShape(Capsule())
            }
            .padding(12)
            
            Divider()
                .opacity(0.5)
            
            VStack(spacing: 16) {
                if let qr = store.qr {
                    ZStack {
                        Color.white
                        Image(nsImage: qr)
                            .resizable()
                            .interpolation(.none)
                            .aspectRatio(contentMode: .fit)
                            .padding(8)
                    }
                    .frame(width: 150, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.12), radius: 5, x: 0, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.black.opacity(0.05), lineWidth: 1)
                    )
                }
                
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(store.host, forType: .string)
                    store.playSound("Pop")
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "link")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        
                        Text(store.host)
                            .font(.system(size: 11, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(.primary.opacity(0.8))
                        
                        Spacer()
                        
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .opacity(isHoveringCopy ? 1 : 0)
                            .transition(.opacity)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(isHoveringCopy ? Color.primary.opacity(0.06) : Color.primary.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .onHover { isHoveringCopy = $0 }
                .padding(.horizontal, 12)
                
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    
                    Text("PIN:")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    
                    Text(store.pin)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.primary)
                }
            }
            .padding(.vertical, 16)
            
            Divider()
                .opacity(0.5)
            
            VStack(spacing: 2) {
                MenuBarItem(title: "Open Inbox", icon: "arrow.up.left.and.arrow.down.right") {
                    NSApp.setActivationPolicy(.regular)
                    openWindow(id: "mainWindow")
                    NSApp.activate(ignoringOtherApps: true)
                }
                
                MenuBarItem(title: "Quit", icon: "power") {
                    NSApp.terminate(nil)
                }
            }
            .padding(5)
        }
        .frame(width: 260)
    }
}

struct MenuBarItem: View {
    let title: String
    let icon: String
    let action: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 13))
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(isHovering ? Color.white : .secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHovering ? Color.accentColor : Color.clear)
            )
            .foregroundStyle(isHovering ? .white : .primary)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
