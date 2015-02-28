/**
 * Tracking goal solver node
 */
class TrakD : Object {
	private static Lcm.LcmNode? lcm;
	private static MainLoop loop;

	private static xat_msgs.HeaderFiller goal_header;
	private static xat_msgs.HeaderFiller cmd_header;
	private static xat_msgs.HeaderFiller ns_header;

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
	private static xat_msgs.lla_point_t def_home_p;
	private static int _mav_timeout_ms = 5000;
	private static int64 mav_timeout_us;
	private static bool publish_nav_data = false;

	private const GLib.OptionEntry[] options = {
		{"lcm-url", 'l', 0, OptionArg.STRING, ref lcm_url, "LCM connection", "URL"},
		{"hm-lat", 0, 0, OptionArg.DOUBLE, ref _home_lat, "Home latitude", "DEG"},
		{"hm-lon", 0, 0, OptionArg.DOUBLE, ref _home_lon, "Home longitude", "DEG"},
		{"hm-alt", 0, 0, OptionArg.DOUBLE, ref _home_alt, "Home altitude", "M"},
		{"mav-to", 0, 0, OptionArg.INT, ref _mav_timeout_ms, "MAV timeout", "MS"},
		{"pub-nav", 0, 0, OptionArg.NONE, ref publish_nav_data, "Publish navigation calculation data", null},

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
	 * Returns last tracker position.
	 */
	private static xat_msgs.lla_point_t get_tracker_position() {
		if (home_fix == null) {
			// no home fix, use default home params
			return def_home_p;
		} else {
			// bad home fix filtered in subscriber callback
			return home_fix.p;
		}
	}

	/**
	 * Returns last received MAV position, if not timedout
	 */
	private static xat_msgs.lla_point_t? get_mav_position() {
		var fix_valid = !is_mav_timedout(mav_fix_rtime);
		var gp_valid = !is_mav_timedout(mav_global_position_rtime);

		xat_msgs.lla_point_t? p = null;

		if (gp_valid) {
			p = mav_global_position.p;
		} else if (fix_valid) {
			p = mav_fix.p;
		}

		return p;
	}

	/**
	 * Calculates goal
	 */
	private static bool timer_update_goal() {
		var home_p = get_tracker_position();
		var mav_p = get_mav_position();

		// int data
		var distance = 0.0;
		var bearing = 0.0;
		var alt_diff = 0.0f;

		// result
		var elevation_angle = 0.0;
		var azimuth_angle = 0.0;

		// valid?
		if (mav_p != null) {
			// XXX TODO estimate position
			var mav_est_p = mav_p;

			// calculations based on APM AntennaTracker (tracking.pde)
			distance = Geo.get_distance(home_p.latitude, home_p.longitude, mav_est_p.latitude, mav_est_p.longitude);
			bearing = Geo.get_bearing(home_p.latitude, home_p.longitude, mav_est_p.latitude, mav_est_p.longitude);
			alt_diff = mav_est_p.altitude - home_p.altitude;

			elevation_angle = Math.atan2((double) alt_diff, distance);

			// todo pub joint goal
		}

		if (publish_nav_data) {
			try {
				var ns = new xat_msgs.nav_status_t();

				ns.header = ns_header.next_now();
				ns.home_p = home_p;

				ns.mav_p_valid = mav_p != null;
				if (mav_p != null) {
					ns.mav_p = mav_p;
					ns.mav_est_p = mav_p;	// TODO
				}

				// int data
				ns.distance = distance;
				ns.bearing = bearing;
				ns.alt_diff = alt_diff;
				ns.bearing_deg = Geo.degrees(bearing);
				ns.elevation_deg = Geo.degrees(elevation_angle);

				// result
				ns.azimuth = bearing;
				ns.elevation = elevation_angle;

				lcm.publish("xat/nav_status", ns.encode());
			} catch (Lcm.MessageError e) {
				error("MessageError: %s", e.message);
			}
		}

		return true;
	}

	static construct {
		loop = new MainLoop();
		goal_header = new xat_msgs.HeaderFiller();
		cmd_header = new xat_msgs.HeaderFiller();
		ns_header = new xat_msgs.HeaderFiller();
		def_home_p = new xat_msgs.lla_point_t();
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
			def_home_p.latitude = _home_lat;
			def_home_p.longitude = _home_lon;
			def_home_p.altitude = (float) _home_alt;
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
		lcm_iochannel = new IOChannel.unix_new(lcm.get_fileno());
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
				try {
					var hb = new xat_msgs.heartbeat_t.from_rbuf(rbuf);

					if (mav_heartbeat_rtime == 0)
						message("Got HEARTBEAT");

					mav_heartbeat_rtime = get_monotonic_time();
				} catch (Lcm.MessageError e) {
					error("Message error: %s", e.message);
				}
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

		// start update task at 10 Hz
		Timeout.add(100, timer_update_goal);

		message("trakd started.");
		loop.run();
		message("trakd quit");
		return 0;
	}
}
