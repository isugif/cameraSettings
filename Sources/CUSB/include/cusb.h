// Minimal IOKit USB access: enumerate devices and send default-pipe control requests.
// Kept in C because the IOKit plug-in (COM-style) interfaces do not import cleanly into Swift.
#ifndef CUSB_H
#define CUSB_H

#include <stdint.h>

typedef struct cusb_device cusb_device;

typedef struct {
    uint16_t vendor_id;
    uint16_t product_id;
    uint32_t location_id;
    char name[128];
} cusb_device_info;

// Fills up to `max` entries; returns the number of USB devices found (may exceed `max`).
int cusb_list_devices(cusb_device_info *out, int max);

// Opens the device at `location_id`. Returns NULL on failure; `*err` receives the IOReturn.
cusb_device *cusb_open(uint32_t location_id, int32_t *err);
void cusb_close(cusb_device *dev);

// Sends a control request on the default pipe. Returns an IOReturn (0 = success).
int32_t cusb_control(cusb_device *dev, uint8_t request_type, uint8_t request,
                     uint16_t value, uint16_t index, void *data, uint16_t length,
                     uint32_t *transferred);

#endif
