/* dummy node
 */

#include "xat/xat.h"

namespace po = boost::program_options;

#include "hidapi/hidapi.h"
#include "xat_rotd/hid_conn.h"


int main(int argc, char *argv[])
{
	bool debug;
	std::string lcm_url;

	po::options_description desc("options");
	desc.add_options()
		("help", "produce help message")
		("lcm-url,l", po::value(&lcm_url), "LCM connection URL")
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

	xat_hid::HIDConn conn;

	std::string device_caps;
	if (!conn.get_Info(device_caps)) {
		logError("Wrong respond to Info request!");
		return EXIT_FAILURE;
	}
	else
		logInform("Device caps: %s", device_caps.c_str());

	while (lcm.good()) {
		float bat_voltage;
		conn.get_Bat_Voltage(bat_voltage);

		logInform("Vbat: %02.2f", bat_voltage);
	}

	hid_exit();
	return EXIT_SUCCESS;
}
