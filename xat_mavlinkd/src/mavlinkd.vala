
class MavlinkD {
	private static Lcm.LcmNode? lcm;
	private static MavConn.IConn? conn;
	private static MainLoop loop;

	private static xat_msgs.HeaderFiller hb_header;
	private static xat_msgs.HeaderFiller fix_header;

	// socket watchers
	private static IOChannel lcm_iochannel = null;
	private static uint lcm_watch_id;

	// main options
	private static string? mav_url = null;
	private static string? lcm_url = null;

	private const GLib.OptionEntry[] options = {
		{"lcm-url", 'l', 0, OptionArg.STRING, ref lcm_url, "LCM connection", "URL"},
		{"mav-url", 'm', 0, OptionArg.STRING, ref mav_url, "Mavlink connection", "URL"},

		{null}
	};

	private static void handle_heartbeat(ref Mavlink.Common.Heartbeat hb) {
		var lhb = new xat_msgs.heartbeat_t();

		lhb.header = hb_header.next_now();

		lcm.publish("xat/mav_heartbeat", lhb.encode());
	}

	private static void handle_gps_raw_int(ref Mavlink.Common.GpsRawInt gps) {
		var fix = new xat_msgs.gps_fix_t();

		fix.header = fix_header.next_now();

		if (gps.fix_type < 2)
			fix.fix_type = xat_msgs.gps_fix_t.FIX_TYPE__NO_FIX;
		else if (gps.fix_type == 2)
			fix.fix_type = xat_msgs.gps_fix_t.FIX_TYPE__2D_FIX;
		else if (gps.fix_type > 2)
			fix.fix_type = xat_msgs.gps_fix_t.FIX_TYPE__3D_FIX;

		// required data
		fix.satellites_visible = (int8) gps.satellites_visible;

		fix.latitude = gps.lat / 1E7;	// in degrees
		fix.longitude = gps.lon / 1E7;
		fix.altitude = gps.alt / 1E3f;	// meters

		// optinal data
		fix.eph = (gps.eph != uint16.MAX)? gps.eph / 1E2f : float.NAN;
		fix.epv = (gps.epv != uint16.MAX)? gps.epv / 1E2f : float.NAN;

		fix.track = (gps.cog != uint16.MAX)? gps.cog / 1E2f : float.NAN;
		fix.ground_speed = (gps.vel != uint16.MAX)? gps.vel / 1E2f : float.NAN;

		// no data
		fix.climb_rate = float.NAN;
		fix.satellites_used = -1;

		lcm.publish("xat/mav_fix", fix.encode());
	}

	static construct {
		loop = new MainLoop();
		hb_header = new xat_msgs.HeaderFiller();
		fix_header = new xat_msgs.HeaderFiller();
	}

	private static void sighandler(int signum) {
		// restore original handler
		Posix.signal(signum, null);
		loop.quit();
	}

	public static int main(string[] args) {
		message("mavlinkd initializing");
		new MavlinkD();

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

		// connect to MAV
		conn = MavConn.IConn.open_url(mav_url);

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

		// setup watch on mavlink source
		unowned Source mav_source = conn.source;
		var loop_context = loop.get_context();
		mav_source.attach(loop_context);

		// "subscribe" to MAV topics
		conn.message_received.connect((msg) => {
				switch (msg.msgid) {
				case Mavlink.Common.Heartbeat.MSG_ID:
					Mavlink.Common.Heartbeat hb = {};
					hb.decode(msg);
					handle_heartbeat(ref hb);
					break;

				case Mavlink.Common.GpsRawInt.MSG_ID:
					Mavlink.Common.GpsRawInt gps = {};
					gps.decode(msg);
					handle_gps_raw_int(ref gps);
					break;

				default:
					break;
				}
			});

		loop.run();
		message("mavlinkd quit");
		return 0;
	}
}
