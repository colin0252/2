import SwiftUI
import UniformTypeIdentifiers

extension String: Identifiable {
    public var id: String { self }
}

struct ContentView: View {
    @StateObject private var systemManager = SystemManager()
    @State private var showVM = false
    @State private var selectedImagePath: String? = nil
    @State private var isImporting = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(systemManager.systems) { item in
                    VStack(alignment: .leading) {
                        HStack {
                            Text(item.name).font(.headline)
                            if item.isLocal {
                                Image(systemName: "folder.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        let status = systemManager.downloadStatuses[item.id] ?? (item.isLocal ? .downloaded(localPath: item.url) : .notDownloaded)
                        switch status {
                        case .notDownloaded:
                            Button("下载") { systemManager.download(item) }
                                .disabled(systemManager.isDownloading)
                        case .downloading(let progress):
                            ProgressView(value: progress)
                            Text("下载中 \(Int(progress * 100))%").font(.caption)
                        case .downloaded(let path):
                            HStack {
                                Text("已下载").foregroundColor(.green)
                                Spacer()
                                Button("启动") {
                                    selectedImagePath = path
                                    showVM = true
                                }
                                Button("删除") {
                                    systemManager.delete(item)
                                }.foregroundColor(.red)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("选择安卓系统")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isImporting = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .imageScale(.large)
                    }
                }
            }
            .fullScreenCover(isPresented: $showVM) {
                if let path = selectedImagePath {
                    VMView(imagePath: path)
                }
            }
            .fileImporter(isPresented: $isImporting,
                          allowedContentTypes: [.item], // 通用文件类型，确保能选所有镜像
                          allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        // 检查扩展名，给予提示
                        let ext = url.pathExtension.lowercased()
                        if ext == "img" || ext == "iso" || ext == "zip" {
                            systemManager.importImage(from: url)
                        } else {
                            systemManager.errorMessage = "请选择 .img / .iso / .zip 格式的镜像文件"
                        }
                    }
                case .failure(let error):
                    systemManager.errorMessage = "文件选择失败：\(error.localizedDescription)"
                }
            }
            .alert(item: $systemManager.errorMessage) { msg in
                Alert(title: Text("提示"), message: Text(msg), dismissButton: .default(Text("好")))
            }
        }
        .onAppear {
            systemManager.scanForLocalImages()
        }
    }
}

// VMView 保持不变（此处省略，与之前提供的一致即可）
// ... 请继续使用之前的 VMView 代码