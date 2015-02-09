
class RotD : Object {

	private static XatHid.HIDConn conn;

	private static int main(string[] args) {
		message("RotD initializing");
		if (!HidApi.init()) {
			error("hidapi initialization.");
			return 1;
		}

		conn = XatHid.HIDConn.open();

		var info_ = conn.get_info();
		message("Device caps: %s", info_.device_caps_str);

		HidApi.exit();
		return 0;
	}
}
