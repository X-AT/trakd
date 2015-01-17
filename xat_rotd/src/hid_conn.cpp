
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

/**
 * Sends get feature report.
 *
 * Retruns from function if failed.
 *
 * @param[in] _report_id    report id
 * @param[in] _report       report buffer
 * @param[in] _report_type  one of report:: structs
 */
#define DO_GET_FEATURE_ERET(_report_id, _report, _report_type)			\
	do {									\
		_report.report_id = _report_id;					\
		if (hid_get_feature_report(					\
				handle.get(),					\
				reinterpret_cast<unsigned char*>(&_report),	\
				report_size(_report_type)) < 0)			\
			return false;						\
	} while (0)

#define DO_SEND_FEATURE_RET(_report_id, _report, _report_type)			\
	do {									\
		_report.report_id = _report_id;					\
		return !(hid_send_feature_report(				\
				handle.get(),					\
				reinterpret_cast<unsigned char*>(&_report),	\
				report_size(_report_type)) < 0);		\
	} while (0)

#define DO_OUTPUT_RET(_report_id, _report, _report_type)			\
	do {									\
		_report.report_id = _report_id;					\
		return !(hid_write(						\
				handle.get(),					\
				reinterpret_cast<unsigned char*>(&_report),	\
				report_size(_report_type)) < 0);		\
	} while (0)

#define NONE
#define COPY_FROM_CONV(_dest_field, _src_report, _func)				\
	_dest_field = _func(_src_report._dest_field)

#define COPY_TO_CONV(_dest_field, _src_report, _func)				\
	_src_report._dest_field = _func(_dest_field)


bool HIDConn::get_Info(report::Info &info)
{
	XAT_Report report{};

	DO_GET_FEATURE_ERET(XAT_Report::ID_F_INFO, report, info);

	info = report.info;
	return true;
}

bool HIDConn::get_Status(report::Status &status)
{
	XAT_Report report{};

	DO_GET_FEATURE_ERET(XAT_Report::ID_G_STATUS, report, status);

	COPY_FROM_CONV(status.flags, report, NONE);
	COPY_FROM_CONV(status.buttons, report, NONE);
	COPY_FROM_CONV(status.azimuth_position, report, le32toh);
	COPY_FROM_CONV(status.elevation_position, report, le32toh);
	return true;
}

bool HIDConn::get_Bat_Voltage(report::Bat_Voltage &bat_voltage)
{
	XAT_Report report{};

	DO_GET_FEATURE_ERET(XAT_Report::ID_G_BAT_VOLTAGE, report, bat_voltage);

	COPY_FROM_CONV(bat_voltage.raw_adc, report, le16toh);
	return true;
}

bool HIDConn::get_Stepper_Settings(report::Stepper_Settings &stepper_settings)
{
	XAT_Report report{};

	DO_GET_FEATURE_ERET(XAT_Report::ID_F_STEPPER_SETTINGS, report, stepper_settings);

	COPY_FROM_CONV(stepper_settings.azimuth_acceleration, report, le16toh);
	COPY_FROM_CONV(stepper_settings.elevation_acceleration, report, le16toh);
	COPY_FROM_CONV(stepper_settings.azimuth_max_speed, report, le16toh);
	COPY_FROM_CONV(stepper_settings.elevation_max_speed, report, le16toh);
	return true;
}

bool HIDConn::set_Stepper_Settings(report::Stepper_Settings &stepper_settings)
{
	XAT_Report report;

	COPY_TO_CONV(stepper_settings.azimuth_acceleration, report, le16toh);
	COPY_TO_CONV(stepper_settings.elevation_acceleration, report, le16toh);
	COPY_TO_CONV(stepper_settings.azimuth_max_speed, report, le16toh);
	COPY_TO_CONV(stepper_settings.elevation_max_speed, report, le16toh);

	DO_SEND_FEATURE_RET(XAT_Report::ID_F_STEPPER_SETTINGS, report, stepper_settings);
}

bool HIDConn::set_Az_El(report::Az_El &az_el)
{
	XAT_Report report;

	COPY_TO_CONV(az_el.azimuth_position, report, le32toh);
	COPY_TO_CONV(az_el.elevation_position, report, le32toh);

	DO_OUTPUT_RET(XAT_Report::ID_S_AZ_EL, report, az_el);
}

bool HIDConn::get_QTR(report::QTR &qtr)
{
	XAT_Report report{};

	DO_GET_FEATURE_ERET(XAT_Report::ID_F_QTR, report, qtr);

	COPY_FROM_CONV(qtr.azimuth_qtr_raw, report, le16toh);
	COPY_FROM_CONV(qtr.elevation_qtr_raw, report, le16toh);
	return true;
}

bool HIDConn::set_QTR(report::QTR &qtr)
{
	XAT_Report report;

	COPY_TO_CONV(qtr.azimuth_qtr_raw, report, le16toh);
	COPY_TO_CONV(qtr.elevation_qtr_raw, report, le16toh);

	DO_SEND_FEATURE_RET(XAT_Report::ID_F_QTR, report, qtr);
}

bool HIDConn::set_Cur_Position(report::Cur_Position &cur_position)
{
	XAT_Report report;

	COPY_TO_CONV(cur_position.azimuth_position, report, le32toh);
	COPY_TO_CONV(cur_position.elevation_position, report, le32toh);

	DO_SEND_FEATURE_RET(XAT_Report::ID_F_CUR_POSITION, report, cur_position);
}

bool HIDConn::set_Stop(report::Stop &stop)
{
	XAT_Report report;

	COPY_TO_CONV(stop.motor, report, NONE);

	DO_OUTPUT_RET(XAT_Report::ID_S_STOP, report, stop);
}

/* -*- some simplifyed eccessors -*- */

bool HIDConn::get_Info(std::string &device_caps)
{
	report::Info info;

	if (!get_Info(info))
		return false;

	// force null termination
	info.device_caps[sizeof(info.device_caps) - 1] = '\0';

	device_caps = reinterpret_cast<char*>(info.device_caps);
	return true;
}

bool HIDConn::get_Bat_Voltage(float &volts)
{
	report::Bat_Voltage bat_voltage;

	if (!get_Bat_Voltage(bat_voltage))
		return false;

	// only for current arduino based prototype
	// Vref = 5 V, Input diveider 1/3
	volts = (bat_voltage.raw_adc / 1023.0) * 5.0 * 3.0;
	return true;
}

bool HIDConn::set_Az_El(int32_t az, int32_t el)
{
	report::Az_El az_el;

	az_el.azimuth_position = az;
	az_el.elevation_position = el;
	return set_Az_El(az_el);
}

bool HIDConn::set_Stop(bool az, bool el)
{
	report::Stop stop{};

	if (az)	stop.motor |= report::Stop::MOTOR_AZ;
	if (el)	stop.motor |= report::Stop::MOTOR_EL;

	return set_Stop(stop);
}

