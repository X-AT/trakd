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
			public abstract void decode(uint8[] report);
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

			//public string device_caps_str {
			//	get { return "" }
			//}

			public void decode(uint8[] report) {
				// XXX TODO
			}

			public uint8[] encode() {
				// XXX TODO

				return new uint8[REPORT_SIZE];
			}
		}

		/**
		 * Get operation status. RO,G.
		 */
		public class Status : IReport {
			public const uint8 REPORT_ID = 2;
			public const size_t REPORT_SIZE = 1 + 2 + 8;

			public enum Flags {
				AZ_IN_MOTION = (1<<0),
				EL_IN_MOTION = (1<<1)
			}

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

			public void decode(uint8[] report) {
				// XXX TODO
			}

			public uint8[] encode() {
				// XXX TODO

				return new uint8[REPORT_SIZE];
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
				// XXX compute actual value
				get { return 0.0f; }
			}

			public void decode(uint8[] report) {
				// XXX TODO
			}

			public uint8[] encode() {
				// XXX TODO

				return new uint8[REPORT_SIZE];
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

			public void decode(uint8[] report) {
				// XXX TODO
			}

			public uint8[] encode() {
				// XXX TODO

				return new uint8[REPORT_SIZE];
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
				// XXX TODO
			}

			public uint8[] encode() {
				// XXX TODO

				return new uint8[REPORT_SIZE];
			}
		}

		/* QTR (6) report removed.
		 * This sensors replaced with discrete hall endstops.
		 */

		/**
		 * Set current stepper positions. WO,F.
		 * Use only when motors is stopped.
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
				// XXX TODO
			}

			public uint8[] encode() {
				// XXX TODO

				return new uint8[REPORT_SIZE];
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
				set { this.motor |= Motor.AZ; }
			}

			public bool elevation {
				get { return (this.motor & Motor.EL) != 0; }
				set { this.motor |= Motor.EL; }
			}
			//! @}

			public void decode(uint8[] report) {
				// XXX TODO
			}

			public uint8[] encode() {
				// XXX TODO

				return new uint8[REPORT_SIZE];
			}
		}
	}
}
