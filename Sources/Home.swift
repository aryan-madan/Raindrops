import SwiftUI
import AppKit

struct Home: View {
    @EnvironmentObject var store: Store
    @State private var showCopied: Bool = false

    let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 16)
    ]

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
                            .frame(width: 33, height: 33)
                    }

                    Text("Raindrops")
                        .font(.system(size: 28, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.85))

                    Spacer()

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
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 40)
                .padding(.top, 40)
                .padding(.bottom, 20)

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
                        .padding(.horizontal, 40)
                        .padding(.bottom, 100)
                        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: store.files)
                    }
                }
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        HStack(spacing: 8) {
                            Circle().fill(Color.green).frame(width: 8, height: 8)
                            Text(showCopied ? "Copied!" : store.host)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.primary)
                                .contentTransition(.numericText())
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.black.opacity(0.3))
                        .clipShape(Capsule())
                        .glassEffect(.regular, in: Capsule())
                        .onTapGesture {
                            let pasteboard = NSPasteboard.general
                            pasteboard.clearContents()
                            pasteboard.setString(store.host, forType: .string)
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showCopied = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showCopied = false
                                }
                            }
                        }

                        Text("Active on Network")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.bottom, 30)
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
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
            .padding(6)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
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