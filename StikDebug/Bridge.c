#include "Bridge.h"
#include <string.h>
#include <stdlib.h>

static char g_image_path[1024] = {0};

void ios_qemu_init(const char* documentPath) {
    // 真机版会在这里初始化 QEMU 工作目录
}

void ios_qemu_set_image_path(const char* imagePath) {
    strncpy(g_image_path, imagePath, sizeof(g_image_path)-1);
    g_image_path[sizeof(g_image_path)-1] = '\0';
}

void ios_qemu_start(void) {
    // 真机版会在这里创建线程启动 qemu_main()
}

void ios_qemu_send_touch(int32_t x, int32_t y, int32_t action) {
    // 真机版会转发给 QEMU 输入处理
}

void ios_qemu_get_frame(unsigned char** buffer, int* width, int* height, int* bytesPerRow) {
    // 返回模拟的一帧静态画面（纯白）
    static unsigned char fake[1920 * 1080 * 4];
    memset(fake, 255, sizeof(fake));
    *buffer = fake;
    *width = 1920;
    *height = 1080;
    *bytesPerRow = 1920 * 4;
}