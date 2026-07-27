import Foundation

class VMManager: ObservableObject {
    // 启动指定镜像的 QEMU
    func startVM(withImagePath imagePath: String) {
        // 初始化环境（假设之前已初始化过，这里可以重复调用，C 层需支持幂等）
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        ios_qemu_init(documentsPath)
        
        // 设置镜像路径给 QEMU（需要修改 Bridge 层支持外部传参）
        ios_qemu_set_image_path(imagePath)
        ios_qemu_start()
    }
    
    // 保留原来的默认启动逻辑（如果还想用）
    func prepareImageAndStart() {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        ios_qemu_init(documentsPath)
        let imageDir = (documentsPath as NSString).appendingPathComponent("android.img")
        if FileManager.default.fileExists(atPath: imageDir) {
            ios_qemu_start()
        } else {
            // 下载默认镜像逻辑...
        }
    }
}