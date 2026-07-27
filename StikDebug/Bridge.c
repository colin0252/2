#include "Bridge.h"
#include <pthread.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

extern int qemu_main(int argc, char **argv);
extern void qemu_set_runtime_root(const char *root);
extern void qemu_input_send_touch_event(int x, int y, int is_down);

static unsigned char *g_framebuffer = NULL;
static int g_width = 0, g_height = 0, g_stride = 0;
static pthread_t g_qemu_thread = 0;

// 镜像路径
static char g_image_path[1024] = {0};

void qemu_frame_update_callback(unsigned char *fb, int w, int h, int stride) {
    g_framebuffer = fb;
    g_width = w;
    g_height = h;
    g_stride = stride;
}

void ios_qemu_set_image_path(const char* imagePath) {
    strncpy(g_image_path, imagePath, sizeof(g_image_path) - 1);
    g_image_path[sizeof(g_image_path) - 1] = '\0';
}

static void* qemu_thread_func(void *arg) {
    // 动态构造 -drive 参数
    char drive_arg[1280];
    if (strlen(g_image_path) == 0) {
        strcpy(g_image_path, "android.img");
    }
    snprintf(drive_arg, sizeof(drive_arg), "file=%s,format=raw,if=none,id=drive0", g_image_path);
    
    char *argv[] = {
        "qemu-system-aarch64",
        "-M", "virt",
        "-cpu", "cortex-a57",
        "-m", "2048",
        "-drive", drive_arg,
        "-device", "virtio-blk-device,drive=drive0",
        "-netdev", "user,id=net0",
        "-device", "virtio-net-device,netdev=net0",
        "-display", "cocoa",
        NULL
    };
    int argc = 0;
    while (argv[argc] != NULL) argc++;
    
    qemu_main(argc, argv);
    return NULL;
}

void ios_qemu_init(const char* documentPath) {
    qemu_set_runtime_root(documentPath);
}

void ios_qemu_start(void) {
    if (g_qemu_thread == 0) {
        pthread_create(&g_qemu_thread, NULL, qemu_thread_func, NULL);
    }
}

void ios_qemu_send_touch(int32_t x, int32_t y, int32_t action) {
    int is_down = (action == 0 || action == 2) ? 1 : 0;
    qemu_input_send_touch_event(x, y, is_down);
}

void ios_qemu_get_frame(unsigned char** buffer, int* width, int* height, int* bytesPerRow) {
    if (g_framebuffer) {
        *buffer = g_framebuffer;
        *width = g_width;
        *height = g_height;
        *bytesPerRow = g_stride;
    } else {
        *buffer = NULL;
        *width = 0;
        *height = 0;
        *bytesPerRow = 0;
    }
}