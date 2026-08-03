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
                            Text(item.name)
                                .font(.headline)
                            if item.isLocal {
                                Image(systemName: "folder")
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
                                }
                                .foregroundColor(.red)
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
                        Image(systemName: "plus")
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
                          allowedContentTypes: [UTType(filenameExtension: "img") ?? .data,
                                               UTType(filenameExtension: "iso") ?? .data,
                                               UTType(filenameExtension: "zip") ?? .data],
                          allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        systemManager.importImage(from: url)
                    }
                case .failure(let error):
                    systemManager.errorMessage = "文件选择失败：\(error.localizedDescription)"
                }
            }
            .alert(item: $systemManager.errorMessage) { msg in
                Alert(title: Text("错误"), message: Text(msg), dismissButton: .default(Text("好")))
            }
        }
        .onAppear {
            systemManager.scanForLocalImages()
        }
    }
}

// VMView 保持不变，这里略（与之前相同）
struct VMView: View {
    let imagePath: String
    @Environment(\.dismiss) var dismiss
    @StateObject private var vmManager = VMManager()
    @State private var uiImage: UIImage? = nil
    
    let timer = Timer.publish(every: 1.0/30.0, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let image = uiImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { v in
                                let p = convertToVMCoordinate(v.location, viewSize: UIScreen.main.bounds.size, vmSize: image.size)
                                ios_qemu_send_touch(Int32(p.x), Int32(p.y), 2)
                            }
                            .onEnded { v in
                                let p = convertToVMCoordinate(v.location, viewSize: UIScreen.main.bounds.size, vmSize: image.size)
                                ios_qemu_send_touch(Int32(p.x), Int32(p.y), 1)
                            }
                    )
            } else {
                ProgressView("等待虚拟机画面...")
                    .foregroundColor(.white)
            }
        }
        .onReceive(timer) { _ in updateFrame() }
        .onAppear {
            vmManager.startVM(withImagePath: imagePath)
        }
        .overlay(
            VStack {
                HStack {
                    Button("关闭") { dismiss() }
                        .padding(8)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    Spacer()
                }
                .padding()
                Spacer()
            }
        )
    }
    
    func updateFrame() {
        var buf: UnsafeMutablePointer<UInt8>?
        var w: Int32 = 0, h: Int32 = 0, stride: Int32 = 0
        ios_qemu_get_frame(&buf, &w, &h, &stride)
        guard let data = buf, w > 0, h > 0 else { return }
        let dataProvider = CGDataProvider(data: NSData(bytes: data, length: Int(stride * h)))
        let cs = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.union(CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue))
        if let cgImage = CGImage(width: Int(w), height: Int(h),
                                 bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: Int(stride),
                                 space: cs, bitmapInfo: bitmapInfo,
                                 provider: dataProvider!, decode: nil,
                                 shouldInterpolate: false, intent: .defaultIntent) {
            uiImage = UIImage(cgImage: cgImage)
        }
    }
    
    func convertToVMCoordinate(_ point: CGPoint, viewSize: CGSize, vmSize: CGSize) -> CGPoint {
        let scale = min(viewSize.width / vmSize.width, viewSize.height / vmSize.height)
        let rw = vmSize.width * scale, rh = vmSize.height * scale
        let ox = (viewSize.width - rw) / 2, oy = (viewSize.height - rh) / 2
        let x = (point.x - ox) / rw * vmSize.width
        let y = (point.y - oy) / rh * vmSize.height
        return CGPoint(x: max(0, min(vmSize.width, x)), y: max(0, min(vmSize.height, y)))
    }
}