
class RotD : Object {

	private static XatHid.HIDConn conn;

	private static int main(string[] args) {
		message("RotD initializing");

		message("LCM connectiong...");
		var lcm = new Lcm.LcmNode();
		message("LCM ok.");

		if (!HidApi.init()) {
			error("hidapi initialization.");
			return 1;
		}

		conn = XatHid.HIDConn.open();

		var info_ = conn.get_info();
		message("Device caps: %s", info_.device_caps_str);

		int32 i = 0;
		while(true) {
			var s = conn.get_bat_voltage();

			var v = new xat_msgs.voltage_t();
			v.header.seq = i++;
			v.voltage = s.battery_voltage;

			lcm.publish("xat/battery_voltage", v.encode());
		}

		HidApi.exit();
		return 0;
	}
}
