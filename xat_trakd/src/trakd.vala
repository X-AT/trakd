/**
 * Tracking goal solver node
 */
class TrakD : Object {
	private static Lcm.LcmNode? lcm;
	private static MainLoop loop;

	private static xat_msgs.HeaderFiller goal_header;
	private static xat_msgs.HeaderFiller cmd_header;
	private static xat_msgs.HeaderFiller ts_header;

	// socket watchers
	private static IOChannel lcm_iochannel = null;

	// subscribed topic data
	private static xat_msgs.gps_fix_t? home_fix;
	private static xat_msgs.gps_fix_t? mav_fix;
	private static int64 mav_fix_rtime = 0;
	private static xat_msgs.global_position_t? mav_global_position;
	private static int64 mav_global_position_rtime = 0;
	private static int64 mav_heartbeat_rtime = 0;

	// main options
	private static string? lcm_url = null;
	private static double _home_lat = 0.0;
	private static double _home_lon = 0.0;
	private static double _home_alt = 0.0;
	private static int _mav_timeout_ms = 5000;
	private static int64 mav_timeout_us;

	private const GLib.OptionEntry[] options = {
		{"lcm-url", 'l', 0, OptionArg.STRING, ref lcm_url, "LCM connection", "URL"},
		{"hm-lat", 0, 0, OptionArg.DOUBLE, ref _home_lat, "Home latitude", "DEG"},
		{"hm-lon", 0, 0, OptionArg.DOUBLE, ref _home_lon, "Home longitude", "DEG"},
		{"hm-alt", 0, 0, OptionArg.DOUBLE, ref _home_alt, "Home altitude", "M"},
		{"mav-to", 0, 0, OptionArg.INT, ref _mav_timeout_ms, "MAV timeout", "MS"},

		{null}
	};

	/**
	 * Checks receive time of mav topic
	 */
	private inline static bool is_mav_timedout(int64 rtime) {
		var ct = get_monotonic_time();
		return (ct - rtime) > mav_timeout_us;
	}

	/**
	 * Returns current tracker position.
	 */
	private static void get_tracker_position(out double latitude, out double longitude, out float altitude) {
		if (home_fix == null) {
			// no home fix, use home params
			latitude = _home_lat;
			longitude = _home_lon;
			altitude = (float) _home_alt;
		} else {
			// bad home fix filtered in subscriber callback
			latitude = home_fix.latitude;
			longitude = home_fix.longitude;
			altitude = home_fix.altitude;
		}
	}

	private static bool get_mav_position(out double latitude, out double longitude, out float altitude) {
		// XXX TODO
		return false;
	}

	static construct {
		loop = new MainLoop();
		goal_header = new xat_msgs.HeaderFiller();
		cmd_header = new xat_msgs.HeaderFiller();
		ts_header = new xat_msgs.HeaderFiller();
	}

	private static void sighandler(int signum) {
		// restore original handler
		Posix.signal(signum, null);
		loop.quit();
	}

	public static int main(string[] args) {
		new TrakD();

		// from FSO fraemwork
		Posix.signal(Posix.SIGINT, sighandler);
		Posix.signal(Posix.SIGTERM, sighandler);

		try {
			var opt_context = new OptionContext("");
			opt_context.set_summary("Tracking goal solver node.");
			opt_context.set_description("This node calculates goal for joints.");
			opt_context.set_help_enabled(true);
			opt_context.add_main_entries(options, null);
			opt_context.parse(ref args);

			mav_timeout_us = _mav_timeout_ms * 1000;
		} catch (OptionError e) {
			stderr.printf("error: %s\n", e.message);
			stderr.printf("Run '%s --help' to see a full list of available command line options.\n", args[0]);
			return 1;
		}

		message("trakd initializing");
		lcm = new Lcm.LcmNode(lcm_url);
		if (lcm == null) {
			error("LCM connection fail.");
			return 1;
		} else {
			message("LCM ok.");
		}

		// setup watch on LCM FD
		var lcm_fd = lcm.get_fileno();
		lcm_iochannel = new IOChannel.unix_new(lcm_fd);
		lcm_iochannel.add_watch(
			IOCondition.IN | IOCondition.ERR | IOCondition.HUP,
			(source, condition) => {
				if (lcm.handle() < 0) {
					error("lcm handle failure");
					loop.quit();
				}
				return true;
			});

		// subscribe to topics
		lcm.subscribe("xat/command",
			(rbuf, channel, ud) => {
				try {
					var msg = new xat_msgs.command_t.from_rbuf(rbuf);

					if (msg.command == xat_msgs.command_t.TERMINATE_ALL) {
						message("Requested to quit.");
						loop.quit();
					}
				} catch (Lcm.MessageError e) {
					error("Message error: %s", e.message);
				}
			});

		lcm.subscribe("xat/home/fix",
			(rbuf, channel, ud) => {
				try {
					var fix = new xat_msgs.gps_fix_t.from_rbuf(rbuf);

					if (fix.fix_type >= xat_msgs.gps_fix_t.FIX_TYPE__2D_FIX) {
						if (home_fix == null)
							message("Got home fix.");
						if (home_fix != null && home_fix.fix_type > fix.fix_type)
							warning("Home fix type degrades");

						home_fix = fix;
					} else {
						debug("Home fix skipped (no fix).");
					}
				} catch (Lcm.MessageError e) {
					error("Message error: %s", e.message);
				}
			});

		lcm.subscribe("xat/mav/heartbeat",
			(rbuf, channel, ud) => {
				//try {
					//var hb = new xat_msgs.heartbeat_t.from_rbuf(rbuf);

					if (mav_heartbeat_rtime == 0)
						message("Got HEARTBEAT");

					mav_heartbeat_rtime = get_monotonic_time();
				//} catch (Lcm.MessageError e) {
				//	error("Message error: %s", e.message);
				//}
			});

		lcm.subscribe("xat/mav/fix",
			(rbuf, channel, ud) => {
				try {
					var fix = new xat_msgs.gps_fix_t.from_rbuf(rbuf);

					if (fix.fix_type >= xat_msgs.gps_fix_t.FIX_TYPE__2D_FIX) {
						if (mav_fix == null)
							message("Got mav fix.");
						if (mav_fix != null && mav_fix.fix_type > fix.fix_type)
							warning("MAV fix type degrades");

						mav_fix = fix;
						mav_fix_rtime = get_monotonic_time();
					} else {
						debug("MAV fix skipped (no fix).");
					}
				} catch (Lcm.MessageError e) {
					error("Message error: %s", e.message);
				}
			});

		lcm.subscribe("xat/mav/global_position",
			(rbuf, channel, ud) => {
				try {
					var gp = new xat_msgs.global_position_t.from_rbuf(rbuf);

					if (mav_global_position == null)
						message("Got mav global position.");

					mav_global_position = gp;
					mav_global_position_rtime = get_monotonic_time();
				} catch (Lcm.MessageError e) {
					error("Message error: %s", e.message);
				}
			});


		message("trakd started.");
		loop.run();
		message("trakd quit");
		return 0;
	}
}
