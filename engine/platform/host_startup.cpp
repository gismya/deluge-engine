// Headless firmware startup (spec §3.4): replaces deluge_main() without PIC/OLED-DMA/USB/startup-song waits,
// then hands off to the firmware's own scheduler (registerTasks + startTaskManager).
// Checked against firmware/src/deluge/deluge.cpp by tools/startup_guard.py (hashes in startup_hashes.json).
#include "OSLikeStuff/scheduler_api.h"
#include "OSLikeStuff/task_scheduler/task_scheduler.h"
#include "gui/ui_timer_manager.h"
#include "hid/display/display.h"
#include "hid/display/oled.h"
#include "hid/display/oled_canvas/canvas.h"
#include "hid/display/screensaver.h"
#include "hid/encoders.h"
#include "io/midi/midi_device_manager.h"
#include "io/midi/midi_follow.h"
#include "model/settings/runtime_feature_settings.h"
#include "playback/mode/playback_mode.h"
#include "playback/mode/session.h"
#include "platform/host_platform.h"
#include "processing/engines/audio_engine.h"
#include "storage/audio/audio_file_manager.h"
#include "storage/flash_storage.h"
#include "util/functions.h"
#include "util/pack.h"

extern "C" void ssiInit(uint8_t, uint8_t);
void setupBlankSong();
void inputRoutine();
void registerTasks();
extern bool sdRoutineLock;
extern TaskManager taskManager;

namespace deluge::engine::platform {

void enableFlushToZero() {
#if defined(__aarch64__)
	// Flush denormals to zero, matching ARMv7 NEON on the Deluge (spec §3.3).
	__builtin_arm_wsr64("fpcr", __builtin_arm_rsr64("fpcr") | (1ull << 24));
#endif
}

void bootFirmware() {
	enableFlushToZero();

	// Engine half of deluge_main() (perform_engine.cpp's proven init list, spec §3.4):
	// skips PIC setup, GPIO/codec/RSPI/OLED-DMA waits, CVEngine::init (busy-waits delayMS), USB, and setupStartupSong.
	functionsInit();
	currentPlaybackMode = &session;
	deluge::hid::display::have_oled_screen = true;
	display = createHostDisplay();
	ssiInit(0, 1);
	deluge::hid::encoders::init();
	init_crc_table();
	AudioEngine::init();
	audioFileManager.init();
	FlashStorage::readSettings();
	runtimeFeatureSettings.init();
	runtimeFeatureSettings.readSettingsFromFile();
	deluge::hid::display::oled_canvas::Canvas::roundedCornersEnabled =
	    runtimeFeatureSettings.isOn(RuntimeFeatureSettingType::RoundedCorners);
	MIDIDeviceManager::readDevicesFromFile();
	midiFollow.readDefaultsFromFile();
	setupBlankSong();
	inputRoutine();
	uiTimerManager.setTimer(TimerName::GRAPHICS_ROUTINE, 50);
	sdRoutineLock = false;
	deluge::hid::display::Screensaver::settingsChanged();

	registerTasks();
}

void runScheduler(double durationSeconds) {
	if (durationSeconds > 0.0) {
		taskManager.start(Time(durationSeconds));
	}
	else {
		startTaskManager();
	}
}

} // namespace deluge::engine::platform
