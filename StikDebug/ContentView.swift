import SwiftUI

struct ContentView: View {
    @StateObject private var systemManager = SystemManager()
    @State private var showVM: Bool = false
    @State private var selectedImagePath: String? = nil
    
    var body: some View {
        NavigationView {
            List {
                ForEach(systemManager.systems) { item in
                    VStack(alignment: .leading) {
                        Text(item.name)
                            .font(.headline)
                        
                        let status = systemManager.downloadStatuses[item.id] ?? .notDownloaded
                        switch status {
                        case .notDownloaded:
                            Button("下载") {
                                systemManager.download(item)
                            }
                            .disabled(systemManager.isDownloading)
                        case .downloading(let progress):
                            ProgressView(value: progress)
                            Text("下载中 \(Int(progress * 100))%")
                                .font(.caption)
                        case .downloaded(let path):
                            HStack {
                                Text("已下载")
                                    .foregroundColor(.green)
                                Spacer()
                                Button("启动") {
                                    selectedImagePath = path
                                    showVM = true
                                }
                                Button("删除") {
                                    systemManager.delete(item)
                                }
                                .foregroundColor(.red)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("选择安卓系统")
            .fullScreenCover(isPresented: $showVM) {
                if let path = selectedImagePath {
                    VMView(imagePath: path)
                }
            }
        }
    }
}

// 虚拟机视图（后续可替换为真实 QEMU 画面）
struct VMView: View {
    let imagePath: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack {
                Text("虚拟机启动中...")
                    .foregroundColor(.white)
                Text("镜像: \(imagePath)")
                    .foregroundColor(.gray)
                    .font(.caption)
                Button("关闭虚拟机") {
                    dismiss()
                }
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .onAppear {
            // 在这里调用 VMManager 启动指定镜像
            // 例如: vmManager.startVM(withImagePath: imagePath)
        }
    }
}