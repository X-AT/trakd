
using XatHid.Report;


class MotConv {
	private float _step_to_rad = 0.0f;

	/**
	 * @param steps_per_rev   check datacheet to your stepper, default for 1.8° deg per step
	 * @param reduction_ratio i = n1/n2, where n1 motor shaft speed, n2 output shaft
	 * @param reversed        motor reversed?
	 */
	public void update(int steps_per_rev = 200, double reduction_ratio = 1.0, bool reversed = false) {
		_step_to_rad = (float) ((2 * Math.PI / steps_per_rev) / reduction_ratio);
		assert(_step_to_rad != 0.0f);

		if (reversed)
			_step_to_rad = -_step_to_rad;
	}

	public float to_rad(int32 steps) {
		return (float) (steps * _step_to_rad);
	}

	public int32 to_steps(float rad) {
		return (int32) (rad / _step_to_rad);
	}
}

class RotD : Object {
	private static XatHid.HIDConn conn;
	private static Lcm.LcmNode? lcm;
	private static MainLoop loop;

	// header data
	private static xat_msgs.HeaderFiller status_header;
	private static xat_msgs.HeaderFiller bat_voltage_header;

	// motor settings
	private static MotConv az_mc;
	private static MotConv el_mc;
	private static StepperSettings homing_settings;
	private static StepperSettings tracking_settings;

	// report from device
	private static Status last_status;

	// main opts
	private static string? lcm_url = null;
	private static int dev_index = 0;
	// azimuth motor
	private static int az_steps_per_rev = 200;
	private static double az_reduction_ratio = 1.0;
	private static bool az_reversed = false;
	// elecation motor
	private static int el_steps_per_rev = 200;
	private static double el_reduction_ratio = 1.0;
	private static bool el_reversed = false;
	// homing settings
	private static int hm_az_acc = 100;
	private static int hm_el_acc = 100;
	private static int hm_az_msp = 200;
	private static int hm_el_msp = 200;
	// tracking settings
	private static int tr_az_acc = 200;
	private static int tr_el_acc = 200;
	private static int tr_az_msp = 200;
	private static int tr_el_msp = 200;

	// lcm polling
	private static IOChannel lcm_iochannel = null;
	private static uint lcm_watch_id = 0;

	private const GLib.OptionEntry[] options = {
		{"lcm-url", 'l', 0, OptionArg.STRING, ref lcm_url, "LCM connection URL", "URL"},
		{"dev-idx", 'i', 0, OptionArg.INT, ref dev_index, "Device index", "NUM"},

		{"az-steps", 0, 0, OptionArg.INT, ref az_steps_per_rev, "AZ steps per motor shaft revolution", "NUM"},
		{"az-ratio", 0, 0, OptionArg.DOUBLE, ref az_reduction_ratio, "AZ reduction ratio", "NUM"},
		{"az-reversed", 0, 0, OptionArg.NONE, ref az_reversed, "AZ direction reversed", null},

		{"el-steps", 0, 0, OptionArg.INT, ref el_steps_per_rev, "EL steps per motor shaft revolution", "NUM"},
		{"el-ratio", 0, 0, OptionArg.DOUBLE, ref el_reduction_ratio, "EL reduction ratio", "NUM"},
		{"el-reversed", 0, 0, OptionArg.NONE, ref el_reversed, "EL direction reversed", null},

		{"hm-az-acc", 0, 0, OptionArg.INT, ref hm_az_acc, "AZ accelaration [step/sec2]", "NUM"},
		{"hm-el-acc", 0, 0, OptionArg.INT, ref hm_el_acc, "EL accelaration [step/sec2]", "NUM"},
		{"hm-az-msp", 0, 0, OptionArg.INT, ref hm_az_msp, "AZ maximum speed [step/sec]", "NUM"},
		{"hm-el-msp", 0, 0, OptionArg.INT, ref hm_el_msp, "EL maximum speed [step/sec]", "NUM"},

		{"tr-az-acc", 0, 0, OptionArg.INT, ref tr_az_acc, "AZ accelaration [step/sec2]", "NUM"},
		{"tr-el-acc", 0, 0, OptionArg.INT, ref tr_el_acc, "EL accelaration [step/sec2]", "NUM"},
		{"tr-az-msp", 0, 0, OptionArg.INT, ref tr_az_msp, "AZ maximum speed [step/sec]", "NUM"},
		{"tr-el-msp", 0, 0, OptionArg.INT, ref tr_el_msp, "EL maximum speed [step/sec]", "NUM"},

		{null}
	};


	private static void debug_stepper_settings(XatHid.Report.StepperSettings ss, string name) {
		debug("%s stepper settings:", name);
		debug("\tAZ acceleration: %d", ss.azimuth_acceleration);
		debug("\tEL acceleration: %d", ss.elevation_acceleration);
		debug("\tAZ max speed:    %d", ss.azimuth_max_speed);
		debug("\tEL max speed:    %d", ss.elevation_max_speed);
	}


	private static void handle_command(xat_msgs.command_t cmd) {
		message("got command");
	}

	private static void handle_joint_goal(xat_msgs.joint_goal_t goal) {
		message("got goal");
	}

	private static bool lcm_watch_callback(IOChannel source, IOCondition condition) {
		lcm.handle();
		// todo check handle error
		return true;
	}

	private static bool timer_publish_status() {
		last_status = conn.get_status();
		var ps = new xat_msgs.joint_state_t();

		ps.header = status_header.next_now();
		// flags
		ps.homing_in_proc = false; // TODO
		ps.azimuth_in_motion = last_status.az_in_motion;
		ps.elevation_in_motion = last_status.el_in_motion;
		ps.azimuth_in_endstop = last_status.az_endstop;
		ps.elevation_in_endstop = last_status.el_endstop;
		// positions
		ps.azimuth_step_cnt = last_status.azimuth_position;
		ps.elevation_step_cnt = last_status.elevation_position;
		ps.azimuth_angle = az_mc.to_rad(last_status.azimuth_position);
		ps.elevation_angle = el_mc.to_rad(last_status.elevation_position);

		lcm.publish("xat/rot_state", ps.encode());
		// todo terminate on error
		return true;
	}

	private static bool timer_publish_bat_voltage() {
		var rv = conn.get_bat_voltage();
		var pv = new xat_msgs.voltage_t();

		pv.header = bat_voltage_header.next_now();
		pv.voltage = rv.battery_voltage;

		lcm.publish("xat/battery_voltage", pv.encode());
		// todo terminate on error
		return true;
	}

	public static int run() {
		// start periodic jobs
		Timeout.add(100 /* ms */, timer_publish_status);
		Timeout.add(1000 /* ms */, timer_publish_bat_voltage);

		// setup watch on LCM FD
		var fd = lcm.get_fileno();
		lcm_iochannel = new IOChannel.unix_new(fd);
		lcm_watch_id = lcm_iochannel.add_watch(
				IOCondition.IN | IOCondition.ERR | IOCondition.HUP,
				lcm_watch_callback);

		// subscribe to topics
		lcm.subscribe("xat/command",
			(rbuf, channel, ud) => {
				try {
					var msg = new xat_msgs.command_t();
					msg.decode(rbuf.data);
					handle_command(msg);
				} catch (Lcm.MessageError e) {
					error("Message error: %s", e.message);
				}
			});
		lcm.subscribe("xat/rot_goal",
			(rbuf, channel, ud) => {
				try {
					var msg = new xat_msgs.joint_goal_t();
					msg.decode(rbuf.data);
					handle_joint_goal(msg);
				} catch (Lcm.MessageError e) {
					error("Message error: %s", e.message);
				}
			});

		loop.run();
		return 0;
	}

	static construct {
		loop = new MainLoop();
		az_mc = new MotConv();
		el_mc = new MotConv();
		homing_settings = new StepperSettings();
		tracking_settings = new StepperSettings();
		status_header = new xat_msgs.HeaderFiller();
		bat_voltage_header = new xat_msgs.HeaderFiller();
	}

	public static int main(string[] args) {
		message("rotd initializing");
		// vala faq
		new RotD();

		if (!HidApi.init()) {
			error("hidapi initialization.");
			return 1;
		}

		try {
			var opt_context = new OptionContext("");
			opt_context.set_help_enabled(true);
			opt_context.add_main_entries(options, null);
			opt_context.parse(ref args);

			// apply options to motor conversions
			az_mc.update(az_steps_per_rev, az_reduction_ratio, az_reversed);
			el_mc.update(el_steps_per_rev, el_reduction_ratio, el_reversed);
			debug("AZ one revolution steps: %" + int32.FORMAT, az_mc.to_steps((float) (2 * Math.PI)));
			debug("EL one revolution steps: %" + int32.FORMAT, el_mc.to_steps((float) (2 * Math.PI)));

			// apply options to homing
			homing_settings.azimuth_acceleration = (uint16) hm_az_acc;
			homing_settings.elevation_acceleration = (uint16) hm_el_acc;
			homing_settings.azimuth_max_speed = (uint16) hm_az_msp;
			homing_settings.elevation_max_speed = (uint16) hm_el_msp;
			debug_stepper_settings(homing_settings, "Homing");

			// apply options to tracking
			tracking_settings.azimuth_acceleration = (uint16) tr_az_acc;
			tracking_settings.elevation_acceleration = (uint16) tr_el_acc;
			tracking_settings.azimuth_max_speed = (uint16) tr_az_msp;
			tracking_settings.elevation_max_speed = (uint16) tr_el_msp;
			debug_stepper_settings(tracking_settings, "Tracking");
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

		try {
			conn = XatHid.HIDConn.open(dev_index);
			message("HID ok.");
		} catch (FileError e) {
			error("HID error: %s", e.message);
			return 1;
		}

		message("rotd started.");
		var ret = run();

		HidApi.exit();
		return ret;
	}
}
