import SwiftUI

struct ContentView: View {
    @EnvironmentObject var vmManager: VMManager
    @State private var uiImage: UIImage? = nil
    let timer = Timer.publish(every: 1.0/30.0, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geo in
            if let image = uiImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let point = convertToVirtualCoordinate(value.location, in: geo.size, vmSize: image.size)
                                ios_qemu_send_touch(Int32(point.x), Int32(point.y), 2)
                            }
                            .onEnded { value in
                                let point = convertToVirtualCoordinate(value.location, in: geo.size, vmSize: image.size)
                                ios_qemu_send_touch(Int32(point.x), Int32(point.y), 1)
                            }
                    )
            } else {
                ProgressView("Waiting for frame...")
            }
        }
        .onReceive(timer) { _ in
            updateFrame()
        }
    }
    
    func updateFrame() {
        var buffer: UnsafeMutablePointer<UInt8>?
        var width: Int32 = 0, height: Int32 = 0, stride: Int32 = 0
        ios_qemu_get_frame(&buffer, &width, &height, &stride)
        guard let data = buffer, width > 0, height > 0 else { return }
        
        let dataProvider = CGDataProvider(data: NSData(bytes: data, length: Int(stride * height)))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.union(CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue))
        
        if let cgImage = CGImage(width: Int(width), height: Int(height),
                                 bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: Int(stride),
                                 space: colorSpace, bitmapInfo: bitmapInfo,
                                 provider: dataProvider!, decode: nil, shouldInterpolate: false,
                                 intent: .defaultIntent) {
            uiImage = UIImage(cgImage: cgImage)
        }
    }
    
    private func convertToVirtualCoordinate(_ point: CGPoint, in viewSize: CGSize, vmSize: CGSize) -> CGPoint {
        let scale = min(viewSize.width / vmSize.width, viewSize.height / vmSize.height)
        let renderWidth = vmSize.width * scale
        let renderHeight = vmSize.height * scale
        let offsetX = (viewSize.width - renderWidth) / 2
        let offsetY = (viewSize.height - renderHeight) / 2
        let x = (point.x - offsetX) / renderWidth * vmSize.width
        let y = (point.y - offsetY) / renderHeight * vmSize.height
        return CGPoint(x: max(0, min(vmSize.width, x)), y: max(0, min(vmSize.height, y)))
    }
}
