
class GpsD : Object {
	private static Lcm.LcmNode? lcm;
	private static Gps.Device gps;
	private static MainLoop loop;

	private static xat_msgs.HeaderFiller fix_header;

	// socket watchers
	private static IOChannel lcm_iochannel = null;
	private static uint lcm_watch_id;
	private static IOChannel gpsd_iochannel = null;
	private static uint gpsd_watch_id;

	// main options
	private static string? gpsd_host = null;
	private static string? gpsd_port = null;
	private static string? lcm_url = null;

	private const GLib.OptionEntry[] options = {
		{"lcm-url", 'l', 0, OptionArg.STRING, ref lcm_url, "LCM connection URL", "URL"},
		{"gpsd-host", 'h', 0, OptionArg.STRING, ref gpsd_host, "Host running GPSd", "HOST"},
		{"gpsd-port", 'p', 0, OptionArg.STRING, ref gpsd_port, "GPSd port", "PORT"},

		{null}
	};

	private static xat_msgs.gps_fix_t make_fix() {
		var fix = new xat_msgs.gps_fix_t();

		fix.header = fix_header.next_now();

		if (gps.online == 0.0) {
			fix.fix_type = xat_msgs.gps_fix_t.FIX_TYPE__NO_FIX;
		} else {
			fix.satellites_visible = (int8) gps.satellites_visible;
			fix.satellites_used = (int8) gps.satellites_used;

			if (gps.fix.mode == Gps.FixMode.MODE_2D)
				fix.fix_type = xat_msgs.gps_fix_t.FIX_TYPE__2D_FIX;
			else if (gps.fix.mode == Gps.FixMode.MODE_3D)
				fix.fix_type = xat_msgs.gps_fix_t.FIX_TYPE__3D_FIX;
			else {
				fix.fix_type = xat_msgs.gps_fix_t.FIX_TYPE__NO_FIX;
				return fix;
			}

			// position
			fix.latitude = gps.fix.latitude;
			fix.longitude = gps.fix.longitude;
			fix.altitude = (float) gps.fix.altitude;

			// DOP
			fix.eph = (float) gps.dop.hdop;
			fix.epv = (float) gps.dop.vdop;

			// course & speed
			fix.track = (float) gps.fix.track;
			fix.ground_speed = (float) gps.fix.speed;
			fix.climb_rate = (float) gps.fix.climb;
		}

		return fix;
	}

	static construct {
		loop = new MainLoop();
		fix_header = new xat_msgs.HeaderFiller();
	}

	private static void sighandler(int signum) {
		// restore original handler
		Posix.signal(signum, null);
		loop.quit();
	}

	public static int main(string[] args) {
		message("gpsd initializing");
		new GpsD();

		// from FSO fraemwork
		Posix.signal(Posix.SIGINT, sighandler);
		Posix.signal(Posix.SIGTERM, sighandler);

		try {
			var opt_context = new OptionContext("");
			opt_context.set_help_enabled(true);
			opt_context.add_main_entries(options, null);
			opt_context.parse(ref args);
		} catch (OptionError e) {
			stderr.printf("error: %s\n", e.message);
			stderr.printf("Run '%s --help' to see a full list of available command line options.\n", args[0]);
			return 1;
		}

		lcm = new Lcm.LcmNode(lcm_url);
		if (lcm == null) {
			error("LCM connection fail.");
			return 1;
		} else {
			message("LCM ok.");
		}

		// connect to GPSd, and setup default streams
		var ret = gps.open(gpsd_host, gpsd_port);
		if (ret == 0)
			ret = gps.stream(Gps.WatchFlags.ENABLE);

		if (ret != 0) {
			unowned string e = Gps.errstr(ret);
			error("GPSd: %s", e);
			return 1;
		} else {
			message("GPSd ok.");
		}

		// setup watch on LCM FD
		var lcm_fd = lcm.get_fileno();
		lcm_iochannel = new IOChannel.unix_new(lcm_fd);
		lcm_watch_id = lcm_iochannel.add_watch(
			IOCondition.IN | IOCondition.ERR | IOCondition.HUP,
			(source, condition) => {
				lcm.handle();
				// todo error
				return true;
			});

		// subscribe to topics
		lcm.subscribe("xat/command",
			(rbuf, channel, ud) => {
				try {
					var msg = new xat_msgs.command_t();
					msg.decode(rbuf.data);
					if (msg.command == xat_msgs.command_t.TERMINATE_ALL) {
						message("Requested to quit.");
						loop.quit();
					}
				} catch (Lcm.MessageError e) {
					error("Message error: %s", e.message);
				}
			});

		// setup watch on GPSd FD
		// (valid only for usual networked connection)
		gpsd_iochannel = new IOChannel.unix_new(gps.gps_fd);
		gpsd_watch_id = gpsd_iochannel.add_watch(
			IOCondition.IN | IOCondition.ERR | IOCondition.HUP,
			(source, condition) => {
				var r_ret = gps.read();
				if (r_ret < 0) {
					// XXX: make better error checking
					unowned string e = Gps.errstr(r_ret);
					error("gpsd read error: %s", e);
					return true;
				}

				var msg = make_fix();
				lcm.publish("xat/home_fix", msg.encode());
				return true;
			});

		loop.run();
		message("gpsd quit");
		return 0;
	}
}