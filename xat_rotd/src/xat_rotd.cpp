/* dummy node
 */

#include "xat/xat.h"
#include "hidapi/hidapi.h"
#include "xat_rotd/hid_conn.h"
#include <thread>
#include <cmath>

namespace po = boost::program_options;
namespace report = xat_hid::report;

#include "xat_msgs/joint_state_t.hpp"
#include "xat_msgs/voltage_t.hpp"


class StepperSpec {
public:
	uint32_t steps_per_rev;
	float reduction_ratio;
	bool reversed;

	StepperSpec(
			uint32_t steps_per_rev_ = 200,
			float reduction_ratio_ = 1.0,
			bool reversed_ = false
		   ) :
		steps_per_rev(steps_per_rev_),
		reduction_ratio(reduction_ratio_),
		reversed(reversed_),

		_step_to_rad(0.0)
	{ };

	void update()
	{
		_step_to_rad = (2 * M_PI / steps_per_rev) * reduction_ratio;
		if (reversed)	_step_to_rad = -_step_to_rad;
	}

	void log_info(const char *name=nullptr)
	{
		update();
		logInform("%s motor specs:", name);
		logInform("\tSteps per revolution: %d", steps_per_rev);
		logInform("\tReduction ratio:      %f", reduction_ratio);
		logInform("\tDirection:            %s", (!reversed)? "Normal" : "Reversed");
		logDebug ("\tStep to rad:          %f", _step_to_rad);
	}

	float to_rad(int32_t steps)
	{
		check_update();
		return steps * _step_to_rad;
	}

	int32_t to_steps(float rad)
	{
		check_update();
		return rad / _step_to_rad;
	}

private:
	float _step_to_rad;

	inline void check_update()
	{
		if (_step_to_rad == 0.0)
			update();

		if (_step_to_rad == 0.0)
			throw std::runtime_error("Invalid StepperSpec settings. step-to-rad is zero!");
	}
};

class RotD {
public:
	RotD(lcm::LCM &lcm_, xat_hid::HIDConn &conn_,
		report::Stepper_Settings &tracking_settings_,
		report::Stepper_Settings &homing_settings_,
		report::QTR &qtr_settings_,
		StepperSpec &az_motor_spec_,
		StepperSpec &el_motor_spec_) :
		lcm(lcm_),
		conn(conn_),
		tracking_settings(tracking_settings_),
		homing_settings(homing_settings_),
		qtr_settings(qtr_settings_),
		az_motor_spec(az_motor_spec_),
		el_motor_spec(el_motor_spec_),

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

		conn.set_Stop(true, true);
		return EXIT_SUCCESS;
	}

private:
	lcm::LCM &lcm;
	xat_hid::HIDConn &conn;
	report::Stepper_Settings &tracking_settings;
	report::Stepper_Settings &homing_settings;
	report::QTR &qtr_settings;
	StepperSpec &az_motor_spec;
	StepperSpec &el_motor_spec;

	std::string device_caps;
	report::Status last_status;
	xat::MsgHeader status_header;
	xat::MsgHeader vbat_header;


	void log_stepper_settings(report::Stepper_Settings &s)
	{
		logInform("Stepper settings:");
		logInform("\tAzimuth acceleration:    %d", s.azimuth_acceleration);
		logInform("\tElevation acceleration:  %d", s.elevation_acceleration);
		logInform("\tAzimuth maximum speed:   %d", s.azimuth_max_speed);
		logInform("\tElevation maximum speed: %d", s.elevation_max_speed);
	}

	void log_qtr(report::QTR &q)
	{
		logInform("Endstop levels:");
		logInform("\tAzimuth:   %d", q.azimuth_qtr_raw);
		logInform("\tElevation: %d", q.elevation_qtr_raw);
	}

	void log_status(report::Status &s)
	{
		using ST = report::Status;

		logInform("Status:");
		logInform("\tFlags:    %s%s",
				(s.flags & ST::AZ_IN_MOTION)? "AZ_IN_MOTION " : "",
				(s.flags & ST::EL_IN_MOTION)? "EL_IN_MOTION" : "");
		logInform("\tEndstops: Az: %s El: %s",
				(s.buttons & ST::AZ_BUTTON)? "True" : "False",
				(s.buttons & ST::EL_BUTTON)? "True" : "False");
		logInform("\tPositions:");
		logInform("\t\tAzimuth:   %d", s.azimuth_position);
		logInform("\t\tElevation: %d", s.elevation_position);
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
		log_qtr(qtr_settings);
		log_stepper_settings(tracking_settings);

		logInform("Settings set.");
		logInform("Motor configurations:");
		az_motor_spec.log_info("Azimuth");
		el_motor_spec.log_info("Elevation");

		conn.get_Status(status);
		log_status(status);

		return true;
	}

	bool publish_status()
	{
		using ST = report::Status;

		if (!conn.get_Status(last_status)) {
			logError("Status: communication error");
			return false;
		}

		xat_msgs::joint_state_t js;

		js.header = status_header.next_now();

		// flags
		js.homing_in_proc = false;
		js.azimuth_in_motion = last_status.flags & ST::AZ_IN_MOTION;
		js.elevation_in_motion = last_status.flags & ST::EL_IN_MOTION;
		js.in_azimuth_endstop = last_status.buttons & ST::AZ_BUTTON;
		js.in_elevation_endstop = last_status.buttons & ST::EL_BUTTON;

		// position
		js.azimuth_step_cnt = last_status.azimuth_position;
		js.elevation_step_cnt = last_status.elevation_position;
		js.azimuth_angle = az_motor_spec.to_rad(last_status.azimuth_position);
		js.elevation_angle = el_motor_spec.to_rad(last_status.elevation_position);

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
	// motor specs
	StepperSpec az_motor_spec, el_motor_spec;

	po::options_description desc("options");
	desc.add_options()
		("help", "produce help message")
		("debug,d", po::bool_switch(&debug)->default_value(false), "Emit debug information")
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

		("az-qtr", po::value(&qtr_settings.azimuth_qtr_raw)->default_value(512), "Azimuth endstop threshold level")
		("el-qtr", po::value(&qtr_settings.elevation_qtr_raw)->default_value(512), "Elevation endstop threshold level")

		("az-steps", po::value(&az_motor_spec.steps_per_rev)->default_value(200), "Azimuth steps per motor shaft revolution")
		("az-reduction", po::value(&az_motor_spec.reduction_ratio)->default_value(1.0), "Azimuth reduction ratio")
		("az-reverse", po::bool_switch(&az_motor_spec.reversed)->default_value(false), "Azimuth motor is reversed")

		("el-steps", po::value(&el_motor_spec.steps_per_rev)->default_value(200), "Elevation steps per motor shaft revolution")
		("el-reduction", po::value(&el_motor_spec.reduction_ratio)->default_value(1.0), "Elevation reduction ratio")
		("el-reverse", po::bool_switch(&el_motor_spec.reversed)->default_value(false), "Elevation motor is reversed")
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
	RotD rotd(
			lcm, conn,
			tracking_settings,
			homing_settings,
			qtr_settings,
			az_motor_spec,
			el_motor_spec
			);

	int ret = rotd.run();

	hid_exit();
	return ret;
}
