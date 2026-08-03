import Foundation
import Combine
import UniformTypeIdentifiers

struct SystemItem: Identifiable, Codable {
    let id: String
    let name: String
    let url: String
    var isLocal: Bool = false
}

enum DownloadStatus {
    case notDownloaded
    case downloading(progress: Double)
    case downloaded(localPath: String)
}

class SystemManager: ObservableObject {
    // 内置下载列表（请确保这些链接在浏览器中打开能直接下载）
    let builtinSystems: [SystemItem] = [
        SystemItem(id: "android8", name: "Android 8.1 x86", url: "https://github.com/colin0252/an-zhuo-xi-tong-jing-xiang/releases/download/v1.0.0/-x86-8.1-r6.iso"),
        SystemItem(id: "android9", name: "Android 9.0 x86_64", url: "https://github.com/colin0252/an-zhuo-xi-tong-jing-xiang/releases/download/v1.0.1/android-x86_64-9.0-r2.iso")
    ]
    
    @Published var systems: [SystemItem] = []
    @Published var downloadStatuses: [String: DownloadStatus] = [:]
    @Published var isDownloading: Bool = false
    @Published var errorMessage: String? = nil
    
    private let defaultsKey = "downloadedImages"
    private let localImagesKey = "localImages"
    
    init() {
        loadSystems()
    }
    
    private func loadSystems() {
        systems = builtinSystems
        if let data = UserDefaults.standard.data(forKey: localImagesKey),
           let localItems = try? JSONDecoder().decode([SystemItem].self, from: data) {
            systems.append(contentsOf: localItems)
        }
        loadDownloadedPaths()
        scanForLocalImages()
    }
    
    func scanForLocalImages() {
        let docs = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: docs) else { return }
        for file in files {
            let ext = (file as NSString).pathExtension.lowercased()
            if ext == "img" || ext == "iso" {
                let fullPath = (docs as NSString).appendingPathComponent(file)
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
                }
            }
        }
        saveLocalItems()
    }
    
    func importImage(from url: URL) {
        let docs = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let importedDir = (docs as NSString).appendingPathComponent("Imported")
        try? FileManager.default.createDirectory(atPath: importedDir, withIntermediateDirectories: true, attributes: nil)
        
        let fileName = url.lastPathComponent
        let destPath = (importedDir as NSString).appendingPathComponent(fileName)
        
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
    
    func delete(_ item: SystemItem) {
        if let index = systems.firstIndex(where: { $0.id == item.id }) {
            systems.remove(at: index)
        }
        if case .downloaded(let path) = downloadStatuses[item.id] {
            if item.isLocal {
                try? FileManager.default.removeItem(atPath: path)
            }
        }
        downloadStatuses.removeValue(forKey: item.id)
        saveLocalItems()
        saveDownloadedPaths()
    }
    
    private func loadDownloadedPaths() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else { return }
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
            errorMessage = "下载地址格式错误，请检查链接"
            return
        }
        
        let task = URLSession.shared.downloadTask(with: url) { [weak self] tempURL, response, error in
            DispatchQueue.main.async {
                self?.isDownloading = false
                if let error = error {
                    self?.downloadStatuses[item.id] = .notDownloaded
                    self?.errorMessage = "下载失败：\(error.localizedDescription)"
                    return
                }
                // 检查 HTTP 状态码
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    self?.downloadStatuses[item.id] = .notDownloaded
                    self?.errorMessage = "下载失败：服务器返回状态码 \(httpResponse.statusCode)"
                    return
                }
                guard let self = self, let tempURL = tempURL else {
                    self?.downloadStatuses[item.id] = .notDownloaded
                    self?.errorMessage = "下载失败：未获取到文件"
                    return
                }
                do {
                    try FileManager.default.moveItem(at: tempURL, to: URL(fileURLWithPath: destPath))
                    self.downloadStatuses[item.id] = .downloaded(localPath: destPath)
                    self.saveDownloadedPaths()
                } catch {
                    self.downloadStatuses[item.id] = .notDownloaded
                    self.errorMessage = "文件保存失败：\(error.localizedDescription)"
                }
            }
        }
        // 监听进度
        _ = task.progress.observe(\.fractionCompleted) { [weak self] prog, _ in
            DispatchQueue.main.async {
                self?.downloadStatuses[item.id] = .downloading(progress: prog.fractionCompleted)
            }
        }
        task.resume()
    }
}