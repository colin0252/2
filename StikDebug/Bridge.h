#ifndef Bridge_h
#define Bridge_h

#include <stdint.h>

void ios_qemu_init(const char* documentPath);
void ios_qemu_start(void);
void ios_qemu_send_touch(int32_t x, int32_t y, int32_t action);
void ios_qemu_get_frame(unsigned char** buffer, int* width, int* height, int* bytesPerRow);
void ios_qemu_set_image_path(const char* imagePath);

#endif