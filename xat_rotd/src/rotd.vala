
using XatHid.Report;


class MotConv {
	private float _step_to_rad = 0.0f;

	/**
	 * @param steps_per_rev   check datacheet to your stepper, default for 1.8° deg per step
	 * @param reduction_ratio i = n1/n2, where n1 motor shaft speed, n2 output shaft
	 * @param reversed        motor reversed?
	 */
	public void update(int steps_per_rev = 200, double reduction_ratio = 1.0, bool reversed = false)
		requires(steps_per_rev > 0)
		requires(reduction_ratio > 0.0)
	{
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

	// lcm polling
	private static IOChannel lcm_iochannel = null;
	private static uint lcm_watch_id = 0;

	// homing
	private static Cancellable homing_cancelable;
	private static bool homing_in_proc;

	// polling rates
	private const int STATUS_PERIOD_MS = 100;	// -> 10 Hz
	private const int BAT_VOLTAGE_PERIOD_MS = 1000;	// ->  1 Hz
	private const int HOMING_PERIOD_MS = 50;	// -> 20 Hz

	// -*- options -*-

	// main opts
	private static string? lcm_url = null;
	private static int dev_index = 0;
	// azimuth motor opts
	private static int az_steps_per_rev = 200;
	private static double az_reduction_ratio = 1.0;
	private static bool az_reversed = false;
	// elecation motor opts
	private static int el_steps_per_rev = 200;
	private static double el_reduction_ratio = 1.0;
	private static bool el_reversed = false;
	// homing settings opts
	private static int hm_az_acc = 100;
	private static int hm_el_acc = 100;
	private static int hm_az_msp = 200;
	private static int hm_el_msp = 200;
	// tracking settings opts
	private static int tr_az_acc = 200;
	private static int tr_el_acc = 200;
	private static int tr_az_msp = 200;
	private static int tr_el_msp = 200;

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

	// -*- helpers -*-

	private static void debug_stepper_settings(StepperSettings ss, string name) {
		debug("%s stepper settings:", name);
		debug("\tAZ acceleration: %d", ss.azimuth_acceleration);
		debug("\tEL acceleration: %d", ss.elevation_acceleration);
		debug("\tAZ max speed:    %d", ss.azimuth_max_speed);
		debug("\tEL max speed:    %d", ss.elevation_max_speed);
	}

	private static void debug_status(Status s) {
		debug("Status:");
		debug(@"\tFlags:   %s%s", s.az_in_motion? "AZ_IN_MOTION " : "", s.el_in_motion? "EL_IN_MOTION" : "");
		debug(@"\tButtons: %s%s", s.az_endstop? "AZ_ENDSTOP " : "", s.el_endstop? "EL_ENDSTOP" : "");
		debug(@"\tAZ position: $(s.azimuth_position)");
		debug(@"\tEL position: $(s.elevation_position)");
	}

	// -*- homing process -*-

	// Stop and reset position to 0
	private static async void homing_init() {
		assert(!homing_cancelable.is_cancelled());

		debug("Homing init begins");

		// setup cancellable to stop polling
		var cancel = homing_cancelable.cancelled.connect(
				() => homing_init.callback());

		// send stop
		conn.send_stop(new Stop.with_data(true, true));

		// wait while it stops
		var to_src = Timeout.add(HOMING_PERIOD_MS,
			() => {
				// XXX error handling
				var s = conn.get_status();
				if (s.az_in_motion || s.el_in_motion)
					return true;

				debug("Reset current position to 0");
				conn.set_cur_position(new CurPosition.with_data(0, 0));

				message("Apply homing settings");
				conn.set_stepper_settings(homing_settings);

				homing_init.callback();
				return false;
			});
		yield;

		// we are done or cancelled
		Source.remove(to_src);
		homing_cancelable.disconnect(cancel);
		debug("Homing init %s", homing_cancelable.is_cancelled()? "canceled" : "done");
	}

	// Do homing
	private static async void homing_homing() {
		if (homing_cancelable.is_cancelled())
			return;

		debug("Homing process begins");

		// setup cancellable to stop
		var cancel = homing_cancelable.cancelled.connect(
				() => homing_homing.callback());

		bool az_in_home = false;
		bool el_in_home = false;
		int az_n = 1;
		int el_n = 1;
		var az_el = new AzEl.with_data(0, 0);

		var to_src = Timeout.add(HOMING_PERIOD_MS,
			() => {
				// XXX error handling
				var s = conn.get_status();

				// latch home positions
				if (s.az_endstop && !az_in_home) {
					az_in_home = true;
					az_el.azimuth_position = s.azimuth_position;
				}
				if (s.el_endstop && !el_in_home) {
					el_in_home = true;
					az_el.elevation_position = s.elevation_position;
				}

				// next move
				if (!s.az_in_motion && !az_in_home) {
					double ang = az_n * Math.PI;
					if ((az_n % 2) != 0) ang = -ang;
					az_n++;

					// limit to one shaft revolution
					if (Math.fabs(ang) > 2 * Math.PI) {
						ang = (ang < 0)? -2 * Math.PI : 2 * Math.PI;
						warning(@"Homing: reach azimuth angle limit! n: $az_n");
					}

					az_el.azimuth_position = az_mc.to_steps((float) ang);
				}
				if (!s.el_in_motion && !el_in_home) {
					double ang = el_n * Math.PI;
					if ((el_n % 2) != 0) ang = -ang;
					el_n++;

					// limit to one shaft revolution
					if (Math.fabs(ang) > 2 * Math.PI) {
						ang = (ang < 0)? -2 * Math.PI : 2 * Math.PI;
						warning(@"Homing: reach elevation angle limit! n: $el_n");
					}

					az_el.elevation_position = el_mc.to_steps((float) ang);
				}

				// apply positions
				conn.send_az_el(az_el);

				// check if we in home then terminame polling
				if (az_in_home && el_in_home) {
					homing_homing.callback();
					return false;
				} else {
					return true;
				}
			});
		yield;

		// we are done or cancelled
		Source.remove(to_src);
		homing_cancelable.disconnect(cancel);

		if (homing_cancelable.is_cancelled())
			conn.send_stop(new Stop.with_data(true, true));

		debug("Homing process %s", homing_cancelable.is_cancelled()? "canceled" : "done");
	}

	// Waits until motors stops and apply home position
	private static async void homing_finish() {
		debug("Homing finishing");

		Timeout.add(HOMING_PERIOD_MS,
			() => {
				// XXX error handling
				var s = conn.get_status();
				if (s.az_in_motion || s.el_in_motion)
					return true;

				debug("Reset current position to 0");
				conn.set_cur_position(new CurPosition.with_data(0, 0));

				message("Apply tracking settings");
				conn.set_stepper_settings(tracking_settings);

				homing_finish.callback();
				return false;
			});
		yield;
	}

	private static async void homing_proc() {
		message("Homing process started");
		homing_in_proc = true;

		yield homing_init();
		yield homing_homing();
		yield homing_finish();

		message("Hoiming finished");
		homing_in_proc = false;
	}

	// -*- subscriber callbacks -*-

	private static void handle_command(xat_msgs.command_t cmd) {
		debug(@"Got command: #$(cmd.header.seq) time: $(cmd.header.stamp) command: $(cmd.command)");

		switch (cmd.command) {
		case xat_msgs.command_t.HOMING_START:
			if (!homing_in_proc) {
				message("Requested to start homing process.");
				homing_cancelable.reset();
				homing_proc.begin();
			} else {
				warning("Requested to start homing process. But it already run.");
			}
			break;

		case xat_msgs.command_t.HOMING_CANCEL:
			// XXX buggy :(
			message("Requested to cancel homing process.");
			homing_cancelable.cancel();
			break;

		case xat_msgs.command_t.MOTOR_STOP:
			message("Requested to stop motors.");
			//homing_cancelable.cancel();
			conn.send_stop(new Stop.with_data(true, true));
			break;

		case xat_msgs.command_t.TERMINATE_ALL:
			message("Requested to quit.");
			loop.quit();
			break;

		default:
			break;
		}
	}

	private static void handle_joint_goal(xat_msgs.joint_goal_t goal) {
		if (homing_in_proc) {
			debug(@"Homing in process, goal [#$(goal.header.seq) time: $(goal.header.stamp)] is skipped.");
			return;
		}

		var az_el = new AzEl();
		az_el.azimuth_position = az_mc.to_steps(goal.azimuth_angle);
		az_el.elevation_position = el_mc.to_steps(goal.elevation_angle);

		debug(@"Got goal: #$(goal.header.seq) time: $(goal.header.stamp)");
		debug("\tAZ: %+4.6f rad (%+10d)", goal.azimuth_angle, az_el.azimuth_position);
		debug("\tEL: %+4.6f rad (%+10d)", goal.elevation_angle, az_el.elevation_position);

		conn.send_az_el(az_el);
		// todo check send error
	}

	private static bool lcm_watch_callback(IOChannel source, IOCondition condition) {
		lcm.handle();
		// todo check handle error
		return true;
	}

	// -*- timer callbacks -*-

	private static bool timer_publish_status() {
		var status = conn.get_status();
		var ps = new xat_msgs.joint_state_t();

		ps.header = status_header.next_now();
		// flags
		ps.homing_in_proc = homing_in_proc;
		ps.azimuth_in_motion = status.az_in_motion;
		ps.elevation_in_motion = status.el_in_motion;
		ps.azimuth_in_endstop = status.az_endstop;
		ps.elevation_in_endstop = status.el_endstop;
		// positions
		ps.azimuth_step_cnt = status.azimuth_position;
		ps.elevation_step_cnt = status.elevation_position;
		ps.azimuth_angle = az_mc.to_rad(status.azimuth_position);
		ps.elevation_angle = el_mc.to_rad(status.elevation_position);

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

	// -*- main loop -*-

	private static int init() {
		// homing canceled by default
		homing_cancelable.cancel();

		try {
			// get device caps, TODO parse it
			var devinfo = conn.get_info();
			message("Device caps: %s", devinfo.device_caps_str);

			// stop motors
			conn.send_stop(new Stop.with_data(true, true));

			// log current status
			var status = conn.get_status();
			debug_status(status);

			// get old settings
			var old_ss = conn.get_stepper_settings();
			debug_stepper_settings(old_ss, "Old");

			// apply new settings
			message("Apply tracking settings");
			conn.set_stepper_settings(tracking_settings);

		} catch (IOChannelError e) {
			error("Device io error: %s", e.message);
			return 1;
		}

		return 0;
	}

	public static int run() {
		// initialize
		if (init() != 0)
			return 1;

		// start periodic jobs
		Timeout.add(STATUS_PERIOD_MS, timer_publish_status);
		Timeout.add(BAT_VOLTAGE_PERIOD_MS, timer_publish_bat_voltage);

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

		message("rotd started.");
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
		homing_cancelable = new Cancellable();
		homing_in_proc = false;
	}

	private static void sighandler(int signum) {
		// restore original handler
		Posix.signal(signum, null);
		loop.quit();
	}

	public static int main(string[] args) {
		message("rotd initializing");
		// vala faq
		new RotD();

		// from FSO fraemwork
		Posix.signal(Posix.SIGINT, sighandler);
		Posix.signal(Posix.SIGTERM, sighandler);

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

		var ret = run();
		conn.send_stop(new Stop.with_data(true, true));

		HidApi.exit();
		message("rotd quit");
		return ret;
	}
}
