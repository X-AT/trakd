/* dummy node
 */

#include "xat/xat.h"
#include "hidapi/hidapi.h"
#include "xat_rotd/hid_conn.h"
#include <thread>

namespace po = boost::program_options;
namespace report = xat_hid::report;

#include "xat_msgs/joint_state_t.hpp"
#include "xat_msgs/voltage_t.hpp"


class RotD {
public:
	RotD(lcm::LCM &lcm_, xat_hid::HIDConn &conn_,
		report::Stepper_Settings &tracking_settings_,
		report::Stepper_Settings &homing_settings_,
		report::QTR qtr_settings_) :
		lcm(lcm_),
		conn(conn_),
		tracking_settings(tracking_settings_),
		homing_settings(homing_settings_),
		qtr_settings(qtr_settings_),

		device_caps{}
	{ };

	int run()
	{
		auto read_duration = std::chrono::milliseconds(100);
		auto vbat_duration = std::chrono::milliseconds(1000);
		auto read_start = std::chrono::steady_clock::now();
		auto vbat_start = std::chrono::steady_clock::now();

		// initialize
		if (!initiaize())
			return EXIT_FAILURE;

		while (lcm.good()) {
			auto now = std::chrono::steady_clock::now();

			if (!publish_status())
				return EXIT_FAILURE;

			if (now - vbat_start > vbat_duration) {
				vbat_start = now;
				if (!publish_vbat())
					return EXIT_FAILURE;
			}

			lcm.handleTimeout(80);

			auto end_time = now + read_duration;
			std::this_thread::sleep_until(end_time);
		}

		return EXIT_SUCCESS;
	}

private:
	lcm::LCM &lcm;
	xat_hid::HIDConn &conn;
	report::Stepper_Settings &tracking_settings;
	report::Stepper_Settings &homing_settings;
	report::QTR &qtr_settings;

	std::string device_caps;
	xat::MsgHeader status_header;
	xat::MsgHeader vbat_header;


	void log_stepper_settings(report::Stepper_Settings &s)
	{
		logDebug("Stepper settings:");
		logDebug("\tAzimuth acceleration:    %d", s.azimuth_acceleration);
		logDebug("\tElevation acceleration:  %d", s.elevation_acceleration);
		logDebug("\tAzimuth maximum speed:   %d", s.azimuth_max_speed);
		logDebug("\tElevation maximum speed: %d", s.elevation_max_speed);
	}

	void log_qtr(report::QTR &q)
	{
		logDebug("Endstop levels:");
		logDebug("\tAzimuth:   %d", q.azimuth_qtr_raw);
		logDebug("\tElevation: %d", q.elevation_qtr_raw);
	}

	void log_status(report::Status &s)
	{
		using ST = report::Status;

		logDebug("Status:");
		logDebug("\tFlags:    %s%s",
				(s.flags & ST::AZ_IN_MOTION)? "AZ_IN_MOTION " : "",
				(s.flags & ST::EL_IN_MOTION)? "EL_IN_MOTION" : "");
		logDebug("\tEndstops: Az: %s El: %s",
				(s.buttons & ST::AZ_BUTTON)? "True" : "False",
				(s.buttons & ST::EL_BUTTON)? "True" : "False");
		logDebug("\tPositions:");
		logDebug("\t\tAzimuth:   %d", s.azimuth_position);
		logDebug("\t\tElevation: %d", s.elevation_position);
	}

	bool initiaize()
	{
		// reading current status
		if (!conn.get_Info(device_caps)) {
			logError("Wrong respond to Info request!");
			return false;
		}
		else
			logInform("Device caps: %s", device_caps.c_str());

		report::Stepper_Settings cur_stepper_settings;
		conn.get_Stepper_Settings(cur_stepper_settings);
		log_stepper_settings(cur_stepper_settings);

		report::QTR qtr;
		conn.get_QTR(qtr);
		log_qtr(qtr);

		report::Status status;
		conn.get_Status(status);
		log_status(status);

		// stop motors
		conn.set_Stop(true, true);

		// apply new settings
		logInform("Apply tracking settings");
		conn.set_QTR(qtr_settings);
		conn.set_Stepper_Settings(tracking_settings);

		return true;
	}

	bool publish_status()
	{
		using ST = report::Status;

		report::Status status;
		if (!conn.get_Status(status)) {
			logError("Status: communication error");
			return false;
		}

		xat_msgs::joint_state_t js;

		js.header = status_header.next_now();

		// flags
		js.homing_in_proc = false;
		js.azimuth_in_motion = status.flags & ST::AZ_IN_MOTION;
		js.elevation_in_motion = status.flags & ST::EL_IN_MOTION;
		js.in_azimuth_endstop = status.buttons & ST::AZ_BUTTON;
		js.in_elevation_endstop = status.buttons & ST::EL_BUTTON;

		// position
		js.azimuth_step_cnt = status.azimuth_position;
		js.elevation_step_cnt = status.elevation_position;
		js.azimuth_angle = 1080.0;
		js.elevation_angle = 3080.0;

		lcm.publish("xat/rot_status", &js);
		return true;
	}

	bool publish_vbat()
	{
		float bat_voltage;
		if (!conn.get_Bat_Voltage(bat_voltage)) {
			logError("Vbat: communication error");
			return false;
		}

		xat_msgs::voltage_t v;

		v.header = vbat_header.next_now();
		v.voltage = bat_voltage;

		lcm.publish("xat/bat_voltage", &v);
		return true;
	}
};

int main(int argc, char *argv[])
{
	bool debug;
	int dev_idx;
	std::string lcm_url;

	// stepper configruration used for tracking
	report::Stepper_Settings tracking_settings;
	// stepper configruration used for homing
	report::Stepper_Settings homing_settings;
	// endstop configuration
	report::QTR qtr_settings;

	po::options_description desc("options");
	desc.add_options()
		("help", "produce help message")
		("lcm-url,l", po::value(&lcm_url), "LCM connection URL")
		("dev-idx,i", po::value(&dev_idx)->default_value(0), "Devide index")
		("tr-az-acc", po::value(&tracking_settings.azimuth_acceleration)->default_value(50), "Tracking azimuth acceleration")
		("tr-el-acc", po::value(&tracking_settings.elevation_acceleration)->default_value(50), "Tracking elevation acceleration")
		("tr-az-msp", po::value(&tracking_settings.azimuth_max_speed)->default_value(200), "Tracking azimuth maximum speed")
		("tr-el-msp", po::value(&tracking_settings.elevation_max_speed)->default_value(200), "Tracking elevation maximum speed")
		("hm-az-acc", po::value(&homing_settings.azimuth_acceleration)->default_value(50), "Homing azimuth acceleration")
		("hm-el-acc", po::value(&homing_settings.elevation_acceleration)->default_value(50), "Homing elevation acceleration")
		("hm-az-msp", po::value(&homing_settings.azimuth_max_speed)->default_value(200), "Homing azimuth maximum speed")
		("hm-el-msp", po::value(&homing_settings.elevation_max_speed)->default_value(200), "Homing elevation maximum speed")
		("qtr-az", po::value(&qtr_settings.azimuth_qtr_raw)->default_value(512), "Azimuth endstop threshold level")
		("qtr-el", po::value(&qtr_settings.elevation_qtr_raw)->default_value(512), "Elevation endstop threshold level")
		("debug,d", po::bool_switch(&debug)->default_value(false), "Emit debug information")
		;
	po::variables_map vm;
	po::store(po::parse_command_line(argc, argv, desc), vm);
	po::notify(vm);

	if (vm.count("help")) {
		std::cout << desc << std::endl;
		return 1;
	}

	if (debug)
		console_bridge::setLogLevel(console_bridge::CONSOLE_BRIDGE_LOG_DEBUG);
	else
		console_bridge::setLogLevel(console_bridge::CONSOLE_BRIDGE_LOG_INFO);

	logInform("Initializing");
	logDebug("Debug enabled");

	logDebug("Connecting to LCM...");
	lcm::LCM lcm(lcm_url);

	if (!lcm.good()) {
		logError("LCM connection failed.");
		return EXIT_FAILURE;
	}
	else
		logInform("LCM connected.");

	hid_init();

	xat_hid::HIDConn conn(dev_idx);
	RotD rotd(lcm, conn, tracking_settings, homing_settings, qtr_settings);

	int ret = rotd.run();

	hid_exit();
	return ret;
}
