import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ShelfView: View {
    @EnvironmentObject var model: ShelfModel
    @State private var isTargeted = false
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("DropShelf")
                    .font(.headline)
                Spacer()
                Button(action: { NSApp.terminate(nil) }) {
                    Image(systemName: "power")
                        .help("退出 DropShelf")
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(model.files, id: \.self) { url in
                        HStack(spacing: 8) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                .resizable()
                                .frame(width: 28, height: 28)
                                .cornerRadius(6)
                            Text(url.lastPathComponent)
                                .lineLimit(1)
                            Spacer()
                            Button(role: .destructive) {
                                model.remove(url: url)
                            } label: {
                                Image(systemName: "trash.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 6)
                        .onDrag {
                            return NSItemProvider(contentsOf: url) ?? NSItemProvider(object: url as NSURL)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 260)
            
            HStack {
                Text("拖拽文件到此处或到菜单栏图标")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(10)
        .overlay(
            Group {
                if model.lastDropSuccess {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                        Text("已添加到暂存")
                            .foregroundColor(.white)
                    }
                    .padding(10)
                    .background(Color.green.opacity(0.9))
                    .cornerRadius(8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
                .animation(.easeOut(duration: 0.28), value: model.lastDropSuccess)
            , alignment: .top)
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isTargeted) { providers -> Bool in
            return handleDrop(providers: providers)
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                handled = true
                // Prefer modern API that requests a concrete class. Extract
                // the add+feedback sequence to avoid duplication.
                func addAndNotify(_ url: URL) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        self.model.add(urls: [url])
                        self.model.triggerSuccess()
                        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                    }
                }

                if #available(macOS 11.0, *) {
                    provider.loadObject(ofClass: NSURL.self) { item, error in
                        if let nsurl = item as? NSURL, let url = nsurl as URL? {
                            addAndNotify(url)
                        } else {
                            provider.loadFileRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { fileUrl, fileError in
                                if let fileUrl = fileUrl {
                                    addAndNotify(fileUrl)
                                }
                            }
                        }
                    }
                } else {
                    provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (item, error) in
                        if let data = item as? Data, let str = String(data: data, encoding: .utf8), let url = URL(string: str) {
                            addAndNotify(url)
                        } else if let url = item as? URL {
                            addAndNotify(url)
                        } else if let urlStr = item as? String, let url = URL(string: urlStr) {
                            addAndNotify(url)
                        }
                    }
                }
            }
        }
        return handled
    }
}

struct ShelfView_Previews: PreviewProvider {
    static var previews: some View {
        ShelfView().environmentObject(ShelfModel())
    }
}
