/* dummy node
 */

#include <boost/program_options.hpp>
#include <console_bridge/console.h>
#include <lcm/lcm-cpp.hpp>
#include <libgpsmm.h>

#include "xat_msgs/gps_fix_t.hpp"

namespace po = boost::program_options;


int main(int argc, char *argv[])
{
	bool debug;
	std::string gps_host;
	std::string gps_port;
	std::string lcm_url;

	po::options_description desc("options");
	desc.add_options()
		("help", "produce help message")
		("lcm-url,l", po::value(&lcm_url), "LCM connection URL")
		("gps-host,h", po::value(&gps_host)->default_value("127.0.0.1"), "Host running GPSD, IP or DNS address")
		("gps-port,p", po::value(&gps_port)->default_value("2947"), "GPSD port")
		("debug,d", po::bool_switch(&debug)->default_value(false), "Emit debug information")
		;
	po::variables_map vm;
	po::store(po::parse_command_line(argc, argv, desc), vm);
	po::notify(vm);

	if (vm.count("help"))
	{
		std::cout << desc << std::endl;
		return 1;
	}

	if (debug)
		console_bridge::setLogLevel(console_bridge::CONSOLE_BRIDGE_LOG_DEBUG);
	else
		console_bridge::setLogLevel(console_bridge::CONSOLE_BRIDGE_LOG_INFO);

	logInform("XAT-GPSd: initializing");
	logDebug("XAT-GPSd: debug enabled");

	/* TODO */

	return EXIT_SUCCESS;
}
