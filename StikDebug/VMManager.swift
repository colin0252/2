import Foundation

class VMManager: ObservableObject {
    func prepareImageAndStart() {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        ios_qemu_init(documentsPath)
        
        let imageDir = (documentsPath as NSString).appendingPathComponent("android.img")
        if FileManager.default.fileExists(atPath: imageDir) {
            ios_qemu_start()
        } else {
            downloadAndExtractImage(to: documentsPath)
        }
    }
    
    private func downloadAndExtractImage(to basePath: String) {
        guard let url = URL(string: "https://your-cdn.com/android_image.zip") else { return }
        let task = URLSession.shared.downloadTask(with: url) { tempURL, _, error in
            guard let tempURL = tempURL, error == nil else { return }
            let destZip = (basePath as NSString).appendingPathComponent("image.zip")
            try? FileManager.default.moveItem(at: tempURL, to: URL(fileURLWithPath: destZip))
            // 解压后启动 QEMU (需集成解压库)
            DispatchQueue.main.async {
                ios_qemu_start()
            }
        }
        task.resume()
    }
}
