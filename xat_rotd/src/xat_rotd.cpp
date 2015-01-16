/* dummy node
 */

#include <boost/program_options.hpp>
#include <console_bridge/console.h>
#include <lcm/lcm-cpp.hpp>
#include <chrono>

namespace po = boost::program_options;


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

	while (lcm.good()) {
	}

	return EXIT_SUCCESS;
}
