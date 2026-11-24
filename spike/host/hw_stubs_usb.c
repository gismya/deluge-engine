// USB host/peripheral stand-ins (C: the RZ/A1 USB headers are C-only). Never connected.
#include "RZA1/usb/r_usb_basic/r_usb_basic_if.h"
#include "RZA1/usb/r_usb_basic/src/driver/inc/r_usb_extern.h"
#include "RZA1/usb/r_usb_hmidi/src/inc/r_usb_hmidi.h"
#include "definitions.h"

uint8_t anythingInitiallyAttachedAsUSBHost = 0;
uint16_t g_usb_usbmode = 0;
uint16_t g_usb_peri_connected = 0;
usb_utr_t* g_p_usb_pipe[USB_MAX_PIPE_NO + 1u];
uint16_t g_usb_hmidi_tmp_ep_tbl[USB_NUM_USBIP][MAX_NUM_USB_MIDI_DEVICES][(USB_EPL * 2) + 1];
void openUSBHost(void) {
}
void closeUSBHost(void) {
}
void openUSBPeripheral(void) {
}
void usb_cstd_usb_task(void) {
}
usb_regadr_t usb_hstd_get_usb_ip_adr(uint16_t ipno) {
	(void)ipno;
	return 0;
}
void change_destination_of_send_pipe(usb_utr_t* ptr, uint16_t pipe, uint16_t* tbl, int32_t sq) {
	(void)ptr, (void)pipe, (void)tbl, (void)sq;
}
void usb_send_start_rohan(usb_utr_t* ptr, uint16_t pipe, uint8_t const* data, int32_t size) {
	(void)ptr, (void)pipe, (void)data, (void)size;
}
void usb_receive_start_rohan_midi(uint16_t pipe) {
	(void)pipe;
}
