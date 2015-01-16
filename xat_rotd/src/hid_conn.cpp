
#include "xat_rotd/hid_conn.h"

using namespace xat_hid;
#define PFX	"hid: "

HIDConn::HIDConn(int index) :
	handle(nullptr, hid_close)
{
	logDebug(PFX "Enumeriating:");

	std::string dev_path;
	bool dev_found = false;
	hid_device_info *devs, *cur_dev;
	int cur_idx = 0;

	devs = hid_enumerate(XAT_VID, XAT_PID);
	for (cur_dev = devs; cur_dev != nullptr; cur_dev = cur_dev->next, cur_idx++) {
		logDebug(PFX "Device found #%d:", cur_idx);
		logDebug(PFX "\tPath:         %s", cur_dev->path);
		logDebug(PFX "\tManufacturer: %ls", cur_dev->manufacturer_string);
		logDebug(PFX "\tProduct:      %ls", cur_dev->product_string);
		logDebug(PFX "\tRelease:      %hx", cur_dev->release_number);
		logDebug(PFX "\tS/N:          %ls", cur_dev->serial_number);

		if (index == cur_idx) {
			dev_found = true;
			dev_path = cur_dev->path;
		}
	}
	hid_free_enumeration(devs);

	if (!dev_found)
		throw std::runtime_error("XAT HID device not found!");

	logDebug(PFX "Trying to open device: %s", dev_path.c_str());
	handle.reset(hid_open_path(dev_path.c_str()));
	if (!handle)
		throw std::runtime_error("Could not open device!");

	logInform(PFX "Device %s opened.", dev_path.c_str());
}

/* -*- report input/output/feauture accessors -*- */

bool HIDConn::get_Info(report::Info &info)
{
	XAT_Report report{};

	report.report_id = XAT_Report::ID_F_INFO;
	if (hid_get_feature_report(handle.get(), reinterpret_cast<unsigned char*>(&report), report_size(info)) < 0)
		return true;

	info = report.info;
	return true;
}

//bool get_Status(report::Status &status);
//bool get_Bat_Voltage(report::Bat_Voltage &bat_voltage);
//bool get_Stepper_Settings(report::Stepper_Settings &stepper_settings);
//bool set_Stepper_Settings(report::Stepper_Settings &stepper_settings);
//bool set_Az_El(report::Az_El *az_el);
//bool get_QTR(report::QTR &qtr);
//bool set_QTR(report::QTR &qtr);
//bool set_Stop(report::Stop &stop);


