import SwiftUI

struct Home: View {
    @EnvironmentObject var store: Store
    @State private var showCopied: Bool = false
    @Namespace private var glassNamespace

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(0.55))
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 20) {
                    Text("Raindrops")
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.9))

                    Spacer()

                    Button(action: { store.clear() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                                .font(.system(size: 12, weight: .medium))
                            Text("Clear Cache")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(.red.opacity(0.9))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.red.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 32)
                .padding(.top, 32)
                .padding(.bottom, 16)

                Spacer(minLength: 0)

                ScrollView {
                    LazyVStack(spacing: 10) {
                        if store.files.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "tray")
                                    .font(.system(size: 44))
                                    .foregroundStyle(.secondary.opacity(0.35))
                                Text("Waiting for drops…")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.secondary.opacity(0.55))
                            }
                            .padding(.top, 80)
                        } else {
                            ForEach(store.files, id: \.self) { name in
                                FileRow(name: name, store: store)
                            }
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
                }

                Spacer(minLength: 0)
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 7, height: 7)

                            Text(showCopied ? "Copied!" : store.host)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(.primary.opacity(0.95))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.28))
                        .clipShape(Capsule())
                        .glassEffect(.regular, in: Capsule())
                        .matchedGeometryEffect(id: "glassCapsule", in: glassNamespace)
                        .onTapGesture {
                            let pasteboard = NSPasteboard.general
                            pasteboard.clearContents()
                            pasteboard.setString(store.host, forType: .string)
                            withAnimation(.easeInOut(duration: 0.18)) {
                                showCopied = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    showCopied = false
                                }
                            }
                        }

                        Text("Active on Network")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(.secondary.opacity(0.7))
                    }
                    Spacer()
                }
                .padding(.bottom, 26)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

struct FileRow: View {
    let name: String
    let store: Store

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "doc.fill")
                .font(.system(size: 18))
                .foregroundStyle(.blue.opacity(0.85))
                .frame(width: 30, height: 30)
                .background(.blue.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))

            Text(name)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary.opacity(0.95))

            Spacer()

            Button(action: { store.open(name) }) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .background(.black.opacity(0.06))
                    .clipShape(Circle())
                    .glassEffect(.regular, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(.black.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
    }
}
