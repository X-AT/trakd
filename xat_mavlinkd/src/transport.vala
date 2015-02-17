/**
 * LibMavConn ported to Vala and GIO
 * Limited to listen only because i don't need send in X-AT.
 */
namespace MavConn {
	public interface IConn : Object {
		public abstract Source? source { get; }

		public signal void message_received(ref Mavlink.Message msg);

		public static IConn? open_url(string url) {
			var proto = GLib.Uri.parse_scheme(url);
			assert(proto == "udp");

			return new UDPConn.from_url(url);
		}
	}

	public class UDPConn : Object, IConn {
		private Mavlink.Message recv_msg;
		private Mavlink.Status recv_status;

		private InetSocketAddress? sender_addr = null;
		private Socket socket;
		private SocketSource? source_;
		public Source? source { get { return source_; } }


		public UDPConn(InetSocketAddress? bind_addr = null) {
			// InetSocketAddress.from_string() does not exist on travis machines (Ubuntu 12.04)
			this.with_sockaddr(bind_addr?? new InetSocketAddress(new InetAddress.loopback(SocketFamily.IPV4), 14550));
		}

		public UDPConn.with_sockaddr(InetSocketAddress bind_addr) {
			message(@"UDP bind: $(bind_addr.address):$(bind_addr.port)");

			socket = new Socket(bind_addr.address.family, SocketType.DATAGRAM, SocketProtocol.UDP);
			socket.bind(bind_addr, true);

			source_ = socket.create_source(IOCondition.IN);
			source_.set_callback((s, cond) => {
					try {
						uint8 buffer[1024];
						SocketAddress sa;

						size_t read = s.receive_from(out sa, buffer);
						if (sender_addr != sa) {
							sender_addr = sa as InetSocketAddress;
							debug(@"UDP remote: $(sender_addr.address):$(sender_addr.port)");
						}

						for (size_t idx = 0; idx < read; idx++) {
							if (Mavlink.parse_char(0, buffer[idx], ref recv_msg, ref recv_status) != 0) {
								//debug(@"got message #$(recv_msg.msgid) len $(recv_msg.len)");
								message_received(ref recv_msg);
							}
						}
					} catch (Error e) {
						error("UDP: %s", e.message);
						// todo handle it
					}

					return true;
				});
		}

		public UDPConn.from_url(string url) {
			// parse url
			var url_sub = url.substring(6);

			var dog = url_sub.index_of_char('@');
			assert(dog >= 0);

			var bind_pair = url_sub.substring(0, dog);
			var bind_split = bind_pair.split(":");

			var bind_host = "localhost";
			uint16 bind_port = 14550;

			if (bind_split.length > 0)
				bind_host = bind_split[0];
			if (bind_split.length > 1) {
				bind_port = (int16) int.parse(bind_split[1]);
			}

			// TODO parse ?ids=x,y

			debug(@"UDP bind unresolved: $bind_host:$bind_port");

			// resolve host addr
			var resolver = Resolver.get_default();
			var addresses = resolver.lookup_by_name(bind_host, null);
			var first_addr = addresses.nth_data(0);

			var bind_addr = new InetSocketAddress(first_addr, bind_port);
			this.with_sockaddr(bind_addr);
		}
	}
}
