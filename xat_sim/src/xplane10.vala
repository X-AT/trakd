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
	private static uint8 msg_data[8192];
	private static MemoryInputStream msg_data_istream = null;

	// main options
	private static int xplane_port = 49005;
	private static string? lcm_url = null;

	private const GLib.OptionEntry[] options = {
		{"lcm-url", 'l', 0, OptionArg.STRING, ref lcm_url, "LCM connection", "URL"},
		{"xplane-port", 'p', 0, OptionArg.INT, ref xplane_port, "X-Plane data out stream", "PORT"},

		{null}
	};

	private static void process_xplane_message(ssize_t rsize) {
		var data_size = rsize - msg_header.length;

		if (data_size <= 0) {
			warning("SIM: short read");
			return;
		}

		// we need only DATA blocks
		if (Memory.cmp(msg_header, "DATA", 4) == 0) {
			size_t d_count = data_size / (sizeof(int32) + sizeof(float) * 8);
			//debug(@"DATA: $data_size bytes => $d_count messages");

			var dis = new DataInputStream(new MemoryInputStream.from_data(msg_data, null));
			// Assume that X-Plane running on x86 or amd64 machine
			dis.byte_order = DataStreamByteOrder.LITTLE_ENDIAN;

			for (size_t didx = 0; didx < d_count; didx++) {
				float d_data[8];

				var d_index = dis.read_int32();
				for (size_t it = 0; it < d_data.length; it++)
					d_data[it] = (float) dis.read_int32();


				switch (d_index) {
				default:
					//debug(@"DATA #$d_index: $(d_data[0]) $(d_data[1]) $(d_data[2]) $(d_data[3]) $(d_data[4]) $(d_data[5]) $(d_data[7])");
					break;
				}
			}
		}
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

					try {
						// i want only read vector data
						var rsize = s.receive_message(null, vec, null, SocketMsgFlags.NONE);
						process_xplane_message(rsize);
					} catch(Error e) {
						error("SIM: recvmsg error: %s", e.message);
					}
				} else {
					error("SIM: poll error!");
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
