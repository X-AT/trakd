/**
 * This file implements interface to X-AT ROT arduino board
 * @file
 */

namespace XatHid {
	/**
	 * VID/PID donated by OpenMoko Inc, BIG THANK YOU!
	 */
	public enum USB_ID {
		VID = 0x1d50,
		PID = 0x60c3
	}

	namespace Report {
		public interface IReport {
			public abstract void decode(uint8[] report) throws ConvertError;
			public abstract uint8[] encode();
		}

		/**
		 * Get device info. RO,F.
		 */
		public class Info : IReport {
			public const uint8 REPORT_ID = 1;
			public const size_t REPORT_SIZE = 1 + 60;

			//! report data @{
			public uint8 report_id = REPORT_ID;
			public uint8 device_caps[60];
			//! @}

			public string device_caps_str {
				get {
					this.device_caps[59] = '\0';
					return (string) this.device_caps;
				}
			}

			public void decode(uint8[] report) throws ConvertError {
				size_t off = 0;

				decode_uint8(report, off, out report_id);	off += sizeof(uint8);
				if (report_id != REPORT_ID || report.length != REPORT_SIZE) {
					throw new ConvertError.ILLEGAL_SEQUENCE("not a Report.Info");
				}

				decode_uint8_array(report, off, device_caps);
			}

			public uint8[] encode() {
				var buf = new uint8[REPORT_SIZE];

				encode_uint8(buf, 0, report_id);
				// only report id for RO

				return buf;
			}
		}

		/**
		 * Get operation status. RO,G.
		 */
		public class Status : IReport {
			public const uint8 REPORT_ID = 2;
			public const size_t REPORT_SIZE = 1 + 2 + 8;

			[Flags]
			public enum Flags {
				AZ_IN_MOTION = (1<<0),
				EL_IN_MOTION = (1<<1)
			}

			[Flags]
			public enum Buttons {
				AZ_ENDSTOP = (1<<0),
				EL_ENDSTOP = (1<<1)
			}

			//! report data @{
			public uint8 report_id = REPORT_ID;
			public uint8 flags = 0;
			public uint8 buttons = 0;
			public int32 azimuth_position = 0;
			public int32 elevation_position = 0;
			//! @}

			//! flag accessors @{
			public bool az_in_motion {
				get { return (this.flags & Flags.AZ_IN_MOTION) != 0; }
			}

			public bool el_in_motion {
				get { return (this.flags & Flags.EL_IN_MOTION) != 0; }
			}

			public bool az_endstop {
				get { return (this.buttons & Buttons.AZ_ENDSTOP) != 0; }
			}

			public bool el_endstop {
				get { return (this.buttons & Buttons.EL_ENDSTOP) != 0; }
			}
			//! @}

			public void decode(uint8[] report) throws ConvertError {
				size_t off = 0;

				decode_uint8(report, off, out report_id);	off += sizeof(uint8);
				if (report_id != REPORT_ID || report.length != REPORT_SIZE) {
					throw new ConvertError.ILLEGAL_SEQUENCE("not a Report.Status");
				}

				decode_uint8(report, off, out flags);		off += sizeof(uint8);
				decode_uint8(report, off, out buttons);		off += sizeof(uint8);
				decode_int32(report, off, out azimuth_position);off += sizeof(int32);
				decode_int32(report, off, out elevation_position);
			}

			public uint8[] encode() {
				var buf = new uint8[REPORT_SIZE];

				encode_uint8(buf, 0, report_id);
				// only report id for RO

				return buf;
			}

		}

		/**
		 * Get raw adc value of Vbat. RO,G.
		 */
		public class BatVoltage : IReport {
			public const uint8 REPORT_ID = 3;
			public const size_t REPORT_SIZE = 1 + 2;

			//! report data @{
			public uint8 report_id = REPORT_ID;
			public uint16 raw_adc = 0;
			//! @}

			public float battery_voltage {
				get {
					// only for current arduino based prototype
					// Vref = 5 V, Input divider 1/3
					return (this.raw_adc / 1023.0f) * 5.0f * 3.0f;
				}
			}

			public void decode(uint8[] report) throws ConvertError {
				size_t off = 0;

				decode_uint8(report, off, out report_id);	off += sizeof(uint8);
				if (report_id != REPORT_ID || report.length != REPORT_SIZE) {
					throw new ConvertError.ILLEGAL_SEQUENCE("not a Report.BatVoltage");
				}

				decode_uint16(report, off, out raw_adc);
			}

			public uint8[] encode() {
				var buf = new uint8[REPORT_SIZE];

				encode_uint8(buf, 0, report_id);
				// only report id for RO

				return buf;
			}
		}

		/**
		 * Stepper driver settings. RW,F.
		 */
		public class StepperSettings : IReport {
			public const uint8 REPORT_ID = 4;
			public const size_t REPORT_SIZE = 1 + 2 * 4;

			//! report data @{
			public uint8 report_id = REPORT_ID;
			public uint16 azimuth_acceleration = 0;
			public uint16 elevation_acceleration = 0;
			public uint16 azimuth_max_speed = 0;
			public uint16 elevation_max_speed = 0;
			//! @}

			public void decode(uint8[] report) throws ConvertError {
				size_t off = 0;

				decode_uint8 (report, off, out report_id);	off += sizeof(uint8);
				if (report_id != REPORT_ID || report.length != REPORT_SIZE) {
					throw new ConvertError.ILLEGAL_SEQUENCE("not a Report.StepperSettings");
				}

				decode_uint16(report, off, out azimuth_acceleration);	off += sizeof(uint16);
				decode_uint16(report, off, out elevation_acceleration);	off += sizeof(uint16);
				decode_uint16(report, off, out azimuth_max_speed);	off += sizeof(uint16);
				decode_uint16(report, off, out elevation_max_speed);
			}

			public uint8[] encode() {
				var buf = new uint8[REPORT_SIZE];
				size_t off = 0;

				encode_uint8 (buf, off, report_id);		off += sizeof(uint8);
				encode_uint16(buf, off, azimuth_acceleration);	off += sizeof(uint16);
				encode_uint16(buf, off, elevation_acceleration);off += sizeof(uint16);
				encode_uint16(buf, off, azimuth_max_speed);	off += sizeof(uint16);
				encode_uint16(buf, off, elevation_max_speed);

				return buf;
			}
		}

		/**
		 * Set target position for steppers. WO,S.
		 */
		public class AzEl : IReport {
			public const uint8 REPORT_ID = 5;
			public const size_t REPORT_SIZE = 1 + 4 * 2;

			//! report data @{
			public uint8 report_id = REPORT_ID;
			public int32 azimuth_position = 0;
			public int32 elevation_position = 0;
			//! @}

			public void decode(uint8[] report) {
				size_t off = 0;

				decode_uint8(report, off, out report_id);	off += sizeof(uint8);
				// Stub. write-only
			}

			public uint8[] encode() {
				var buf = new uint8[REPORT_SIZE];
				size_t off = 0;

				encode_uint8(buf, off, report_id);		off += sizeof(uint8);
				encode_int32(buf, off, azimuth_position);	off += sizeof(int32);
				encode_int32(buf, off, elevation_position);

				return buf;
			}
		}

		/* QTR (6) report removed.
		 * This sensors replaced with discrete hall endstops.
		 */

		/**
		 * Set current stepper positions. WO,F.
		 * Use only when motors is stopped!
		 */
		public class CurPosition : IReport {
			public const uint8 REPORT_ID = 7;
			public const size_t REPORT_SIZE = 1 + 4 * 2;

			//! report data @{
			public uint8 report_id = REPORT_ID;
			public int32 azimuth_position = 0;
			public int32 elevation_position = 0;
			//! @}

			public void decode(uint8[] report) {
				size_t off = 0;

				decode_uint8(report, off, out report_id);	off += sizeof(uint8);
				// Stub. write-only
			}

			public uint8[] encode() {
				var buf = new uint8[REPORT_SIZE];
				size_t off = 0;

				encode_uint8(buf, off, report_id);		off += sizeof(uint8);
				encode_int32(buf, off, azimuth_position);	off += sizeof(int32);
				encode_int32(buf, off, elevation_position);

				return buf;
			}
		}

		/**
		 * Request to stop motors. WO,S.
		 */
		public class Stop : IReport {
			public const uint8 REPORT_ID = 8;
			public const size_t REPORT_SIZE = 1 + 1;

			public enum Motor {
				AZ = (1<<0),
				EL = (1<<1)
			}

			//! report data @{
			public uint8 report_id = REPORT_ID;
			public uint8 motor = 0;
			//! @}

			//! flag accessors @{
			public bool azimuth {
				get { return (this.motor & Motor.AZ) != 0; }
				set {
					if (value)
						this.motor |= Motor.AZ;
					else
						this.motor &= ~Motor.AZ;
				}
			}

			public bool elevation {
				get { return (this.motor & Motor.EL) != 0; }
				set {
					if (value)
						this.motor |= Motor.EL;
					else
						this.motor &= ~Motor.EL;
				}
			}
			//! @}

			public void decode(uint8[] report) {
				size_t off = 0;

				decode_uint8(report, off, out report_id);	off += sizeof(uint8);
				// Stub. write-only
			}

			public uint8[] encode() {
				var buf = new uint8[REPORT_SIZE];
				size_t off = 0;

				encode_uint8(buf, off, report_id);	off += sizeof(uint8);
				encode_uint8(buf, off, report_id);

				return buf;

			}
		}

		/**
		 * Decoder and encoder helpers
		 * @{
		 */
		internal void encode_uint8(uint8[] buf, size_t off, uint8 val) {
			buf[off] = val;
		}

		internal void encode_uint16(uint8[] buf, size_t off, uint16 val) {
			var le16 = val.to_little_endian();
			Memory.copy(&buf[off], &le16, sizeof(uint16));
		}

		internal void encode_int32(uint8[] buf, size_t off, int32 val) {
			var le32 = val.to_little_endian();
			Memory.copy(&buf[off], &le32, sizeof(int32));
		}

		internal void decode_uint8(uint8[] buf, size_t off, out uint8 val) {
			val = buf[off];
		}

		internal void decode_uint8_array(uint8[] buf, size_t off, uint8[] val) {
			Memory.copy(val, &buf[off], val.length);
		}

		internal void decode_uint16(uint8[] buf, size_t off, out uint16 val) {
			uint16 le16 = 0;
			Memory.copy(&le16, &buf[off], sizeof(uint16));
			val = uint16.from_little_endian(le16);
		}

		internal void decode_int32(uint8[] buf, size_t off, out int32 val) {
			int32 le32 = 0;
			Memory.copy(&le32, &buf[off], sizeof(int32));
			val = int32.from_little_endian(le32);
		}
		//! @}
	}

	public class HIDConn {
		private HidApi.Device handle;

		public static HIDConn? open(int index = 0) throws FileError {
			int cur_idx = 0;
			bool dev_found = false;
			string dev_path = "";

			debug("Enumerating:");
			var dev = HidApi.Info.enumerate(USB_ID.VID, USB_ID.PID);
			for (; dev != null; dev = (owned) dev.next, cur_idx++) {
				debug("Device found #%d:", cur_idx);
				debug("\tPath:         %s", dev.path);
				debug("\tManufacturer: %s", dev.manufacturer);
				debug("\tProduct:      %s", dev.product);
				debug("\tRelease:      %hx", dev.release_number);
				debug("\tS/N:          %s", dev.serial_number_str);

				if (index == cur_idx) {
					dev_found = true;
					dev_path = dev.path;
				}
			}

			if (!dev_found) {
				throw new FileError.NODEV(@"x-at rot device #$index not found");
			}

			var inst = new HIDConn();

			debug("Trying to open device: %s", dev_path);
			inst.handle = HidApi.Device.open_path(dev_path);
			if (inst.handle == null) {
				throw new FileError.ACCES(@"Could not open device: $dev_path");
			}

			message("Device #%d: %s opened.", index, dev_path);
			return inst;
		}

		//! helper methods @{
		internal void get_feature_report(Report.IReport report) throws IOChannelError, ConvertError {
			var report_buffer = report.encode();
			if (handle.get_feature_report(report_buffer) < 0) {
				throw new IOChannelError.IO("get_feature_report");
			}
			report.decode(report_buffer);
		}

		internal void send_feature_report(Report.IReport report) throws IOChannelError {
			var report_buffer = report.encode();
			if (handle.send_feature_report(report_buffer) < 0) {
				throw new IOChannelError.IO("send_feature_report");
			}
		}

		internal void output_report(Report.IReport report) throws IOChannelError {
			var report_buffer = report.encode();
			if (handle.write(report_buffer) < 0) {
				throw new IOChannelError.IO("write report");
			}
		}
		//! @}

		/**
		 * Get device information report
		 */
		public Report.Info get_info() throws IOChannelError, ConvertError {
			var info_ = new Report.Info();
			get_feature_report((Report.IReport) info_);
			return info_;
		}

		/**
		 * Get status report
		 */
		public Report.Status get_status() throws IOChannelError, ConvertError {
			var status_ = new Report.Status();
			get_feature_report((Report.IReport) status_);
			return status_;
		}

		/**
		 * Get battery voltage readings
		 */
		public Report.BatVoltage get_bat_voltage() throws IOChannelError, ConvertError {
			var bat_voltage_ = new Report.BatVoltage();
			get_feature_report((Report.IReport) bat_voltage_);
			return bat_voltage_;
		}

		/**
		 * Get current stepper settings
		 */
		public Report.StepperSettings get_stepper_settings() throws IOChannelError, ConvertError {
			var ss_ = new Report.StepperSettings();
			get_feature_report(ss_);
			return ss_;
		}

		/**
		 * Set new settings.
		 */
		public void set_stepper_settings(Report.StepperSettings ss_) throws IOChannelError {
			send_feature_report((Report.IReport) ss_);
		}

		/**
		 * Send new position targets
		 */
		public void send_az_el(Report.AzEl ae_) throws IOChannelError {
			output_report((Report.IReport) ae_);
		}

		/**
		 * Reset current position to new values
		 */
		public void set_cur_position(Report.CurPosition cp_) throws IOChannelError {
			send_feature_report((Report.IReport) cp_);
		}

		/**
		 * Send stop command.
		 */
		public void send_stop(Report.Stop st_) throws IOChannelError {
			output_report((Report.IReport) st_);
		}
	}
}
