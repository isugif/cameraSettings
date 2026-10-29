#include "cusb.h"

#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/usb/IOUSBLib.h>
#include <stdlib.h>
#include <string.h>

struct cusb_device {
    IOUSBDeviceInterface **intf;
};

static uint32_t number_property(io_service_t service, CFStringRef key) {
    uint32_t result = 0;
    CFTypeRef ref = IORegistryEntryCreateCFProperty(service, key, kCFAllocatorDefault, 0);
    if (ref) {
        if (CFGetTypeID(ref) == CFNumberGetTypeID()) {
            CFNumberGetValue((CFNumberRef)ref, kCFNumberSInt32Type, &result);
        }
        CFRelease(ref);
    }
    return result;
}

static void string_property(io_service_t service, CFStringRef key, char *out, size_t size) {
    out[0] = '\0';
    CFTypeRef ref = IORegistryEntryCreateCFProperty(service, key, kCFAllocatorDefault, 0);
    if (ref) {
        if (CFGetTypeID(ref) == CFStringGetTypeID()) {
            CFStringGetCString((CFStringRef)ref, out, (CFIndex)size, kCFStringEncodingUTF8);
        }
        CFRelease(ref);
    }
}

int cusb_list_devices(cusb_device_info *out, int max) {
    io_iterator_t iter;
    if (IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching(kIOUSBDeviceClassName), &iter) != KERN_SUCCESS) {
        return 0;
    }
    int count = 0;
    io_service_t service;
    while ((service = IOIteratorNext(iter))) {
        if (count < max) {
            cusb_device_info *info = &out[count];
            info->vendor_id = (uint16_t)number_property(service, CFSTR(kUSBVendorID));
            info->product_id = (uint16_t)number_property(service, CFSTR(kUSBProductID));
            info->location_id = number_property(service, CFSTR(kUSBDevicePropertyLocationID));
            string_property(service, CFSTR(kUSBProductString), info->name, sizeof info->name);
        }
        count++;
        IOObjectRelease(service);
    }
    IOObjectRelease(iter);
    return count;
}

static io_service_t find_service(uint32_t location_id) {
    io_iterator_t iter;
    if (IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching(kIOUSBDeviceClassName), &iter) != KERN_SUCCESS) {
        return IO_OBJECT_NULL;
    }
    io_service_t found = IO_OBJECT_NULL;
    io_service_t service;
    while ((service = IOIteratorNext(iter))) {
        if (!found && number_property(service, CFSTR(kUSBDevicePropertyLocationID)) == location_id) {
            found = service;
        } else {
            IOObjectRelease(service);
        }
    }
    IOObjectRelease(iter);
    return found;
}

cusb_device *cusb_open(uint32_t location_id, int32_t *err) {
    *err = kIOReturnNotFound;
    io_service_t service = find_service(location_id);
    if (!service) return NULL;

    IOCFPlugInInterface **plugin = NULL;
    SInt32 score = 0;
    kern_return_t kr = IOCreatePlugInInterfaceForService(service, kIOUSBDeviceUserClientTypeID,
                                                         kIOCFPlugInInterfaceID, &plugin, &score);
    IOObjectRelease(service);
    if (kr != KERN_SUCCESS || !plugin) {
        *err = kr;
        return NULL;
    }

    IOUSBDeviceInterface **intf = NULL;
    HRESULT hr = (*plugin)->QueryInterface(plugin, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID), (LPVOID *)&intf);
    IODestroyPlugInInterface(plugin);
    if (hr || !intf) {
        *err = kIOReturnUnsupported;
        return NULL;
    }

    cusb_device *dev = malloc(sizeof *dev);
    dev->intf = intf;
    *err = kIOReturnSuccess;
    return dev;
}

void cusb_close(cusb_device *dev) {
    if (!dev) return;
    (*dev->intf)->Release(dev->intf);
    free(dev);
}

int32_t cusb_control(cusb_device *dev, uint8_t request_type, uint8_t request,
                     uint16_t value, uint16_t index, void *data, uint16_t length,
                     uint32_t *transferred) {
    IOUSBDevRequest req = {
        .bmRequestType = request_type,
        .bRequest = request,
        .wValue = value,
        .wIndex = index,
        .wLength = length,
        .pData = data,
        .wLenDone = 0,
    };
    IOReturn kr = (*dev->intf)->DeviceRequest(dev->intf, &req);
    if (transferred) *transferred = req.wLenDone;
    return kr;
}
