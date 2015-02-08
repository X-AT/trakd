/* test lcm.vala
 * valac --vapidir ./vapi --pkg lcm -C test.vala
 */

using lcm;

static void topic_cb(RecvBuf rbuf, string channel, void *user_data)
{
	stdout.printf("got message from %s channel, size %u bytes\n", channel, rbuf.data_size);
}

int main(string[] args)
{
	int64[] testdatamesg = { 0xd00dfeed, 0xdeeadbeef, 0xeeeeeeee, 0xffff0000, 0x5a5aa5a5 };

	// hello
	stdout.printf("testing vapi for LCM %d.%d.%d\n", lcm.Version.MAJOR, lcm.Version.MINOR, lcm.Version.MICRO);

	// create object
	var lcm = new LCM(null);

	// check file no
	var fn = lcm.get_fileno();
	stdout.printf("lcm fileno: %d\n", fn);

	// make subscription
	unowned Subscription sub = lcm.subscribe("test_topic", topic_cb);

	// publish
	stdout.printf("try to publish message\n");
	lcm.publish("test_topic", (void[])testdatamesg);

	// handle
	stdout.printf("handle\n");
	lcm.handle();

	lcm.publish("test_topic", (void[])testdatamesg);
	lcm.handle_timeout(1000);

	// change queue
	stdout.printf("set_queue_capacity\n");
	sub.set_queue_capacity(100);

	lcm.unsubscribe(sub);

	return 0;
}