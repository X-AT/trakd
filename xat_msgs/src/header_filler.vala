/**
 * Common header message filler.
 */
public class xat_msgs.HeaderFiller : Object {
	private int32 last_seq = 0;

	public xat_msgs.header_t next_now() {
		var h = new xat_msgs.header_t();

		// prevent signed int overflow
		if (last_seq == int32.MAX)
			last_seq = 0;

		h.seq = last_seq++;
		h.stamp = now();
		return h;
	}

	/**
	 * Return current timestamp in microseconds
	 */
	public static int64 now() {
		var tv = TimeVal();
		tv.get_current_time();
		return tv.tv_sec * 1000000 + tv.tv_usec;
	}
}
