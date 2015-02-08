/* LCM bindings
 *
 */

[CCode (cheader_filename = "lcm.h")]
namespace lcm {
	[CCode (cname = "lcm_t", free_function = "lcm_destroy")]
	[Compact]
	public class LCM {
		[CCode (cname = "lcm_create")]
		public LCM(string? provider);

		[CCode (cname = "lcm_get_fileno")]
		public int get_fileno();

		[CCode (cname = "lcm_subscribe")]
		public unowned Subscription subscribe(string channel, MsgHandler handler, void *user_data = null);

		[CCode (cname = "lcm_unsubscribe")]
		public int unsubscribe(Subscription handler);

		[CCode (cname = "lcm_publish")]
		public int publish(string channel, void[] data);

		[CCode (cname = "lcm_handle")]
		public int handle();

		[CCode (cname = "lcm_handle_timeout")]
		public int handle_timeout(int timeout_millis);
	}

	// XXX!!!!
	[CCode (cname = "lcm_subscription_t", free_function = "")]
	public class Subscription {
	}

	[CCode (cname = "lcm_recv_buf_t", has_type_id = false)]
	public struct RecvBuf {
		void *data;
		uint32 data_size;
		int64 recv_utime;
		unowned LCM lcm;
	}

	[CCode (cname = "lcm_msg_handler_t", has_target = false)]
	public delegate void MsgHandler(RecvBuf rbuf, string channel, void *user_data);
}


