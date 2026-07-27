import Foundation
import Combine

struct SystemItem: Identifiable, Codable {
    let id: String
    let name: String
    let url: String
}

enum DownloadStatus {
    case notDownloaded
    case downloading(progress: Double)
    case downloaded(localPath: String)
}

class SystemManager: ObservableObject {
    // 👇 你自己的下载链接（已经填好）
    let systems: [SystemItem] = [
        SystemItem(id: "android8", name: "Android 8.1 x86", url: "https://github.com/colin0252/an-zhuo-xi-tong-jing-xiang/releases/download/v1.0.0/-x86-8.1-r6.iso"),
        SystemItem(id: "android9", name: "Android 9.0 x86_64", url: "https://github.com/colin0252/an-zhuo-xi-tong-jing-xiang/releases/download/v1.0.1/android-x86_64-9.0-r2.iso")
    ]
    
    @Published var downloadStatuses: [String: DownloadStatus] = [:]
    @Published var isDownloading: Bool = false
    @Published var errorMessage: String? = nil
    
    private let defaultsKey = "downloadedImages"
    
    init() {
        loadDownloadedPaths()
    }
    
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
    
    private func saveDownloadedPaths() {
        var dict = [String: String]()
        for (id, status) in downloadStatuses {
            if case .downloaded(let path) = status {
                dict[id] = path
            }
        }
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
    
    func download(_ item: SystemItem) {
        guard !isDownloading else { return }
        isDownloading = true
        downloadStatuses[item.id] = .downloading(progress: 0)
        
        let documents = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let destDir = (documents as NSString).appendingPathComponent(item.id)
        try? FileManager.default.createDirectory(atPath: destDir, withIntermediateDirectories: true)
        let destPath = (destDir as NSString).appendingPathComponent(item.url.components(separatedBy: "/").last ?? "image.iso")
        
        guard let url = URL(string: item.url) else {
            isDownloading = false
            downloadStatuses[item.id] = .notDownloaded
            errorMessage = "下载地址无效"
            return
        }
        
        let task = URLSession.shared.downloadTask(with: url) { tempURL, response, error in
            DispatchQueue.main.async { [weak self] in
                self?.isDownloading = false
                if let error = error {
                    self?.downloadStatuses[item.id] = .notDownloaded
                    self?.errorMessage = "下载失败：\(error.localizedDescription)"
                    return
                }
                guard let self = self, let tempURL = tempURL else {
                    self?.downloadStatuses[item.id] = .notDownloaded
                    self?.errorMessage = "下载失败：文件不存在"
                    return
                }
                try? FileManager.default.moveItem(at: tempURL, to: URL(fileURLWithPath: destPath))
                self.downloadStatuses[item.id] = .downloaded(localPath: destPath)
                self.saveDownloadedPaths()
            }
        }
        _ = task.progress.observe(\.fractionCompleted) { [weak self] prog, _ in
            DispatchQueue.main.async {
                self?.downloadStatuses[item.id] = .downloading(progress: prog.fractionCompleted)
            }
        }
        task.resume()
    }
    
    func delete(_ item: SystemItem) {
        if case .downloaded(let path) = downloadStatuses[item.id] {
            try? FileManager.default.removeItem(atPath: path)
        }
        downloadStatuses[item.id] = .notDownloaded
        saveDownloadedPaths()
    }
}