import Foundation

class VMManager: ObservableObject {
    func startVM(withImagePath imagePath: String) {
        let docs = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        ios_qemu_init(docs)
        ios_qemu_set_image_path(imagePath)
        ios_qemu_start()
    }
}