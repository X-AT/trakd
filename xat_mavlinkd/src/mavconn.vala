/**
 * LibMavConn ported to Vala and GIO
 * Limited to listen only because i don't need send in X-AT.
 */
namespace MavConn {
	public interface IConn : Object {
		public abstract Source? source { get; }

		public signal void message_received(ref Mavlink.Message msg);

		public static IConn? open_url(string url) throws Error {
			var proto = GLib.Uri.parse_scheme(url);

			switch (proto) {
			case "udp":
				return new UDPConn.from_url(url);

			case "tcp":
				return new TCPClientConn.from_url(url);

			default:
				return_if_reached();
				return null;
			}
		}
	}

	internal void url_parse_host_port(string pair, out string host, out uint16 port,
			string def_host, uint16 def_port) {
			var split = pair.split(":");

			host = def_host;
			port = def_port;

			if (split.length > 0 && split[0] != "")
				host = split[0];
			if (split.length > 1 && split[1] != "")
				port = (int16) int.parse(split[1]);
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
			this.with_sockaddr(bind_addr?? new InetSocketAddress(new InetAddress.any(SocketFamily.IPV4), 14550));
		}

		public UDPConn.with_sockaddr(InetSocketAddress bind_addr) throws Error {
			message(@"UDP bind: $(bind_addr.address):$(bind_addr.port)");

			socket = new Socket(bind_addr.address.family, SocketType.DATAGRAM, SocketProtocol.UDP);
			socket.bind(bind_addr, true);

			source_ = socket.create_source(IOCondition.IN | IOCondition.ERR | IOCondition.HUP);
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

		public UDPConn.from_url(string url) throws Error {
			var proto = GLib.Uri.parse_scheme(url);
			assert(proto == "udp");

			// parse url, skip `udp://`
			var url_sub = url.substring(6);

			var dog = url_sub.index_of_char('@');
			assert(dog >= 0);

			var bind_pair = url_sub.substring(0, dog);
			string bind_host;
			uint16 bind_port;
			url_parse_host_port(bind_pair, out bind_host, out bind_port, "0.0.0.0", 14550);

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

	public class TCPClientConn : Object, IConn {
		private Mavlink.Message recv_msg;
		private Mavlink.Status recv_status;

		private SocketClient client;
		private SocketConnection conn;
		private SocketSource? source_;
		public Source? source { get { return source_; } }


		public TCPClientConn(InetSocketAddress? server_addr = null) {
			// InetSocketAddress.from_string() does not exist on travis machines (Ubuntu 12.04)
			this.with_sockaddr(server_addr?? new InetSocketAddress(new InetAddress.loopback(SocketFamily.IPV4), 5760));
		}

		public TCPClientConn.with_sockaddr(InetSocketAddress server_addr) throws Error {
			message(@"TCP server: $(server_addr.address):$(server_addr.port)");

			client = new SocketClient();
			conn = client.connect(server_addr);

			message("TCP: connected to server.");

			// maybe better to use async methods from SocketConnection?
			source_ = conn.socket.create_source(IOCondition.IN | IOCondition.ERR | IOCondition.HUP);
			source_.set_callback((s, cond) => {
					try {
						uint8 buffer[1024];

						size_t read = s.receive(buffer);
						for (size_t idx = 0; idx < read; idx++) {
							if (Mavlink.parse_char(0, buffer[idx], ref recv_msg, ref recv_status) != 0) {
								debug(@"got message #$(recv_msg.msgid) len $(recv_msg.len)");
								message_received(ref recv_msg);
							}
						}
					} catch (Error e) {
						error("TCP: %s", e.message);
						// todo handle it
					}

					return true;
				});
		}

		public TCPClientConn.from_url(string url) throws Error {
			var proto = GLib.Uri.parse_scheme(url);
			assert(proto == "tcp");

			// parse url, skip `tcp://`
			var url_sub = url.substring(6);

			var sep = url_sub.index_of_char('/');
			var server_pair = url_sub.substring(0, sep);
			string server_host;
			uint16 server_port;
			url_parse_host_port(server_pair, out server_host, out server_port, "localhost", 5760);

			// TODO parse ?ids=x,y

			debug(@"TCP server unresolved: $server_host:$server_port");

			// resolve host addr
			var resolver = Resolver.get_default();
			var addresses = resolver.lookup_by_name(server_host, null);
			var first_addr = addresses.nth_data(0);

			var server_addr = new InetSocketAddress(first_addr, server_port);
			this.with_sockaddr(server_addr);
		}
	}

}
