import Foundation
import Combine
import UniformTypeIdentifiers

struct SystemItem: Identifiable, Codable {
    let id: String
    let name: String
    let url: String
    // 是否为本地导入的镜像（用于区分）
    var isLocal: Bool = false
}

enum DownloadStatus {
    case notDownloaded
    case downloading(progress: Double)
    case downloaded(localPath: String)
}

class SystemManager: ObservableObject {
    // 内置的系统列表
    let builtinSystems: [SystemItem] = [
        SystemItem(id: "android8", name: "Android 8.1 x86", url: "https://github.com/colin0252/an-zhuo-xi-tong-jing-xiang/releases/download/v1.0.0/-x86-8.1-r6.iso"),
        SystemItem(id: "android9", name: "Android 9.0 x86_64", url: "https://github.com/colin0252/an-zhuo-xi-tong-jing-xiang/releases/download/v1.0.1/android-x86_64-9.0-r2.iso")
    ]
    
    // 所有系统列表（内置 + 导入的）
    @Published var systems: [SystemItem] = []
    @Published var downloadStatuses: [String: DownloadStatus] = [:]
    @Published var isDownloading: Bool = false
    @Published var errorMessage: String? = nil
    
    private let defaultsKey = "downloadedImages"
    private let localImagesKey = "localImages"
    
    init() {
        loadSystems()
    }
    
    // MARK: - 系统列表管理
    
    private func loadSystems() {
        // 加载内置系统
        systems = builtinSystems
        // 加载之前导入的本地镜像
        if let data = UserDefaults.standard.data(forKey: localImagesKey),
           let localItems = try? JSONDecoder().decode([SystemItem].self, from: data) {
            systems.append(contentsOf: localItems)
        }
        // 恢复下载状态
        loadDownloadedPaths()
        // 扫描 Documents 下可能通过 iTunes 直接放入的镜像
        scanForLocalImages()
    }
    
    // 扫描沙盒根目录下的 .img / .iso 文件，自动添加到列表（如果尚未添加）
    func scanForLocalImages() {
        let docs = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: docs) else { return }
        for file in files {
            let ext = (file as NSString).pathExtension.lowercased()
            if ext == "img" || ext == "iso" {
                let fullPath = (docs as NSString).appendingPathComponent(file)
                // 检查是否已经在系统中（通过路径）
                let alreadyExists = systems.contains { item in
                    if case .downloaded(let path) = downloadStatuses[item.id] {
                        return path == fullPath
                    }
                    return false
                }
                if !alreadyExists {
                    let newItem = SystemItem(id: UUID().uuidString,
                                             name: file,
                                             url: fullPath,
                                             isLocal: true)
                    systems.append(newItem)
                    downloadStatuses[newItem.id] = .downloaded(localPath: fullPath)
                    saveLocalItems()
                }
            }
        }
    }
    
    // 导入外部文件：从 URL 复制到 App 内部目录，并添加系统
    func importImage(from url: URL) {
        let docs = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let importedDir = (docs as NSString).appendingPathComponent("Imported")
        try? FileManager.default.createDirectory(atPath: importedDir, withIntermediateDirectories: true, attributes: nil)
        
        let fileName = url.lastPathComponent
        let destPath = (importedDir as NSString).appendingPathComponent(fileName)
        
        // 复制文件
        do {
            if FileManager.default.fileExists(atPath: destPath) {
                try FileManager.default.removeItem(atPath: destPath)
            }
            try FileManager.default.copyItem(at: url, to: URL(fileURLWithPath: destPath))
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.errorMessage = "导入失败：\(error.localizedDescription)"
            }
            return
        }
        
        // 创建新系统项
        let newItem = SystemItem(id: UUID().uuidString,
                                 name: fileName,
                                 url: destPath,
                                 isLocal: true)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.systems.append(newItem)
            self.downloadStatuses[newItem.id] = .downloaded(localPath: destPath)
            self.saveLocalItems()
        }
    }
    
    private func saveLocalItems() {
        let localItems = systems.filter { $0.isLocal }
        if let data = try? JSONEncoder().encode(localItems) {
            UserDefaults.standard.set(data, forKey: localImagesKey)
        }
    }
    
    // 删除某个系统（如果是本地镜像，同时删除文件）
    func delete(_ item: SystemItem) {
        if let index = systems.firstIndex(where: { $0.id == item.id }) {
            systems.remove(at: index)
        }
        if case .downloaded(let path) = downloadStatuses[item.id] {
            if item.isLocal {
                // 删除导入的文件
                try? FileManager.default.removeItem(atPath: path)
            }
        }
        downloadStatuses.removeValue(forKey: item.id)
        saveLocalItems()
        saveDownloadedPaths()
    }
    
    // MARK: - 下载管理（同之前）
    
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
}