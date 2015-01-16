
#pragma once

#include "xat/xat.h"
#include "hid_reports.h"
#include "hidapi/hidapi.h"

namespace xat_hid {

class HIDConn {
public:
	HIDConn(int index = 0);

	/* -*- report input/output/feauture accessors -*- */
	bool get_Info(report::Info &info);
	bool get_Status(report::Status &status);
	bool get_Bat_Voltage(report::Bat_Voltage &bat_voltage);
	bool get_Stepper_Settings(report::Stepper_Settings &stepper_settings);
	bool set_Stepper_Settings(report::Stepper_Settings &stepper_settings);
	bool set_Az_El(report::Az_El &az_el);
	bool get_QTR(report::QTR &qtr);
	bool set_QTR(report::QTR &qtr);
	bool set_Cur_Position(report::Cur_Position &cur_position);
	bool set_Stop(report::Stop &stop);

	/* -*- some simplifyed eccessors -*- */
	//bool set_Stop(bool az, bool el);
	//bool get_Bat_Voltage(uint16_t &millivolt);
	//bool get_Info(std::string &device_caps);

private:
	std::unique_ptr<hid_device, void (*)(hid_device*)> handle;
};

}; // namespace xat_hid
