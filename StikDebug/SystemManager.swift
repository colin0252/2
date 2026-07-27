import Foundation
import Combine

// 单个系统模型
struct SystemItem: Identifiable, Codable {
    let id: String
    let name: String
    let url: String   // 镜像下载地址（zip/raw）
}

// 下载状态
enum DownloadStatus {
    case notDownloaded
    case downloading(progress: Double)
    case downloaded(localPath: String)
}

class SystemManager: ObservableObject {
    // 内置的系统列表（你可以在下面随意增删改）
    let systems: [SystemItem] = [
        SystemItem(id: "android9", name: "Android 9.0", url: "https://your-cdn.com/android9.zip"),
        SystemItem(id: "android11", name: "Android 11.0", url: "https://your-cdn.com/android11.zip"),
        SystemItem(id: "lineageos20", name: "LineageOS 20", url: "https://your-cdn.com/lineage20.zip")
    ]
    
    @Published var downloadStatuses: [String: DownloadStatus] = [:]
    @Published var isDownloading: Bool = false
    
    private let defaultsKey = "downloadedImages"
    
    init() {
        loadDownloadedPaths()
    }
    
    // 加载已下载记录
    private func loadDownloadedPaths() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            return
        }
        for (id, path) in dict {
            if FileManager.default.fileExists(atPath: path) {
                downloadStatuses[id] = .downloaded(localPath: path)
            }
        }
    }
    
    // 保存已下载记录
    private func saveDownloadedPaths() {
        var dict = [String: String]()
        for (id, status) in downloadStatuses {
            if case .downloaded(let path) = status {
                dict[id] = path
            }
        }
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.default.set(data, forKey: defaultsKey)
        }
    }
    
    // 开始下载某个系统
    func download(_ item: SystemItem) {
        guard !isDownloading else { return }
        isDownloading = true
        downloadStatuses[item.id] = .downloading(progress: 0)
        
        let documents = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let destDir = (documents as NSString).appendingPathComponent(item.id) // 每个镜像放自己的文件夹
        
        // 创建目录
        try? FileManager.default.createDirectory(atPath: destDir, withIntermediateDirectories: true, attributes: nil)
        
        let destZip = (destDir as NSString).appendingPathComponent("image.zip")
        
        guard let url = URL(string: item.url) else {
            isDownloading = false
            downloadStatuses[item.id] = .notDownloaded
            return
        }
        
        let task = URLSession.shared.downloadTask(with: url) { tempURL, response, error in
            DispatchQueue.main.async { [weak self] in
                self?.isDownloading = false
                guard let self = self, let tempURL = tempURL, error == nil else {
                    self?.downloadStatuses[item.id] = .notDownloaded
                    return
                }
                
                // 移动zip到目标位置
                try? FileManager.default.moveItem(at: tempURL, to: URL(fileURLWithPath: destZip))
                
                // 模拟解压（你需要集成真正的解压库，这里简化为假设解压后得到 android.img）
                // 实际中请使用 SSZipArchive 等库解压，然后将镜像路径记为:
                // let imagePath = (destDir as NSString).appendingPathComponent("android.img")
                // 下面直接假设解压成功，镜像就是 destZip 的同目录下 android.img
                let imagePath = (destDir as NSString).appendingPathComponent("android.img")
                
                self.downloadStatuses[item.id] = .downloaded(localPath: imagePath)
                self.saveDownloadedPaths()
            }
        }
        // 进度监听（可选）
        let observation = task.progress.observe(\.fractionCompleted) { [weak self] prog, _ in
            DispatchQueue.main.async {
                self?.downloadStatuses[item.id] = .downloading(progress: prog.fractionCompleted)
            }
        }
        task.resume()
    }
    
    // 删除某个已下载系统
    func delete(_ item: SystemItem) {
        if case .downloaded(let path) = downloadStatuses[item.id] {
            let dir = (path as NSString).deletingLastPathComponent
            try? FileManager.default.removeItem(atPath: dir)
        }
        downloadStatuses[item.id] = .notDownloaded
        saveDownloadedPaths()
    }
}