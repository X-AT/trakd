/* dummy node
 */

#include "xat/xat.h"
#include <libgpsmm.h>

#include "xat_msgs/gps_fix_t.hpp"

namespace po = boost::program_options;

#if GPSD_API_MAJOR_VERSION != 5
#error Unsupported version of libgps
#endif


inline void process_gps(const gps_data_t *data, xat_msgs::gps_fix_t &fix)
{
	fix.satellites_visible = data->satellites_visible;
	fix.satellites_used = data->satellites_used;

	if (data->fix.mode == MODE_2D)
		fix.fix_type = xat_msgs::gps_fix_t::FIX_TYPE__2D_FIX;
	else if (data->fix.mode == MODE_3D)
		fix.fix_type = xat_msgs::gps_fix_t::FIX_TYPE__3D_FIX;
	else {
		fix.fix_type = xat_msgs::gps_fix_t::FIX_TYPE__NO_FIX;
		return;
	}

	// position
	fix.latitude = data->fix.latitude;
	fix.longitude = data->fix.longitude;
	fix.altitude = data->fix.altitude;

	// DOP
	fix.eph = data->dop.hdop;
	fix.epv = data->dop.vdop;

	// course & speed
	fix.track = data->fix.track;
	fix.ground_speed = data->fix.speed;
	fix.climb_rate = data->fix.climb;
}

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
		("gps-host,h", po::value(&gps_host)->default_value("localhost"), "Host running GPSD, IP or DNS address")
		("gps-port,p", po::value(&gps_port)->default_value(DEFAULT_GPSD_PORT), "GPSD port")
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

	// GPSd v5 API
	logDebug("Connecting to GPSd...");
	gpsmm gps(gps_host.c_str(), gps_port.c_str());
	auto *resp = gps.stream(WATCH_ENABLE);

	if (resp == nullptr) {
		logError("GPSd connection failed.");
		return EXIT_FAILURE;
	}
	else
		logInform("GPSd connected.");

	// main loop vars
	int8_t prev_status = xat_msgs::gps_fix_t::FIX_TYPE__NO_FIX;
	xat::MsgHeader fix_header;

	while (lcm.good()) {
		xat_msgs::gps_fix_t fix;

		// poll for 5 sec
		if (!gps.waiting(5000000)) {
			logDebug("GPS: poll timeout");
			continue;
		}
		auto *data = gps.read();

		/* fill header_t */
		fix.header = fix_header.next_now();

		if (data == nullptr) {
			if (prev_status != xat_msgs::gps_fix_t::FIX_TYPE__NO_FIX)
				logWarn("GPS: Lost FIX");

			logDebug("GPS: no data");
			fix.fix_type = xat_msgs::gps_fix_t::FIX_TYPE__NO_FIX;
			/* XXX: original test_gpsmm.cpp terminates here */
		}
		else if (!data->online) {
			if (prev_status != xat_msgs::gps_fix_t::FIX_TYPE__NO_FIX)
				logWarn("GPS: Offline");

			logDebug("GPS: Offline");
			fix.fix_type = xat_msgs::gps_fix_t::FIX_TYPE__NO_FIX;
		}
		else {
			if (prev_status == xat_msgs::gps_fix_t::FIX_TYPE__NO_FIX)
				logInform("GPS: Online");

			logDebug("GPS: Got FIX. Time: %f", data->fix.time);
			process_gps(data, fix);
		}

		prev_status = fix.fix_type;

		lcm.publish("xat/home_fix", &fix);
	}

	return EXIT_SUCCESS;
}
