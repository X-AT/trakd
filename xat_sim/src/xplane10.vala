/**
 * Publish simulated MAV data
 *
 * X-plane protocol spec: http://www.nuclearprojects.com/xplane/xplaneref.html
 */
class Xplane10 : Object {
	private static Lcm.LcmNode? lcm;
	private static MainLoop loop;

	private static xat_msgs.HeaderFiller fix_header;

	// socket watchers
	private static IOChannel lcm_iochannel = null;
	private static uint lcm_watch_id;
	private static Socket socket = null;

	// recv buffers
	private static uint8 msg_header[5];
	private static uint8[] msg_data;

	// main options
	private static int xplane_port = 49005;
	private static string? lcm_url = null;

	private const GLib.OptionEntry[] options = {
		{"lcm-url", 'l', 0, OptionArg.STRING, ref lcm_url, "LCM connection", "URL"},
		{"xplane-port", 'p', 0, OptionArg.INT, ref xplane_port, "X-Plane data out stream", "PORT"},

		{null}
	};

	static construct {
		loop = new MainLoop();
		fix_header = new xat_msgs.HeaderFiller();
		msg_data = new uint8[8 * 1024];	// maximum payload is 8 KiB
	}

	private static void sighandler(int signum) {
		// restore original handler
		Posix.signal(signum, null);
		loop.quit();
	}

	public static int main(string[] args) {
		new Xplane10();

		// from FSO fraemwork
		Posix.signal(Posix.SIGINT, sighandler);
		Posix.signal(Posix.SIGTERM, sighandler);

		try {
			var opt_context = new OptionContext("");
			opt_context.set_summary("X-Plane 10 simulation input node.");
			opt_context.set_description("This node sends MAV topics using X-Plane 10 as a source.");
			opt_context.set_help_enabled(true);
			opt_context.add_main_entries(options, null);
			opt_context.parse(ref args);
		} catch (OptionError e) {
			stderr.printf("error: %s\n", e.message);
			stderr.printf("Run '%s --help' to see a full list of available command line options.\n", args[0]);
			return 1;
		}

		message("xplane 10 sim initializing");
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

		// X-Plane UDP out
		try {
			var sa = new InetSocketAddress(new InetAddress.any(SocketFamily.IPV4), (uint16) xplane_port);
			socket = new Socket(SocketFamily.IPV4, SocketType.DATAGRAM, SocketProtocol.UDP);
			socket.bind(sa, true);
			message(@"X-Plane socket opened: $(sa.address):$(sa.port)");
		} catch (Error e) {
			error("Socket: %s", e.message);
			return 1;
		}

		// make reader source
		var source = socket.create_source(IOCondition.IN | IOCondition.ERR | IOCondition.HUP);
		source.set_callback((s, cond) => {
				if ((cond & IOCondition.IN) == IOCondition.IN) {
					InputVector vec[2] = {
						InputVector() { buffer = msg_header, size = msg_header.length },
						InputVector() { buffer = msg_data, size = msg_data.length }
					};

					// i want only read vector data
					var rsize = s.receive_message(null, vec, null, SocketMsgFlags.NONE);
					if (rsize >= msg_header.length)
						debug("got data");
						//process_message(rsize);
					else {
						error("XXX receive error.");
					}
				} else {
					error("XXX cond!");
				}

				return true;
			});

		source.attach(loop.get_context());

		message("xplane 10 sim started.");
		loop.run();
		message("xplane 10 sim quit");
		return 0;
	}
}
