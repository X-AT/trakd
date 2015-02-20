/* Hand made bindings to some mavlink messages
 * Limited to use in X-AT telemetry receiver.
 */

[CCode (cheader_filename = "mavlink/v1.0/common/mavlink.h")]
namespace Mavlink {

	/* common/common.h */

	[CCode (cname = "MAV_AUTOPILOT", has_type_id = false, cprefix = "MAV_AUTOPILOT_")]
	public enum Common.Autopilot {
		GENERIC,
		PIXHAWK,
		ARDUPILOTMEGA,
		INVALID,
		/* only used */
	}

	[CCode (cname = "MAV_TYPE", has_type_id = false, cprefix = "MAV_TYPE_")]
	public enum Common.Type {
		GENERIC,
		FIXED_WING,
		ANTENNA_TRACKER,
		GCS,
		/* only used */
	}

	/* common/version.h */

	[CCode (cprefix = "MAVLINK_")]
	public const string BUILD_DATE;
	[CCode (cprefix = "MAVLINK_")]
	public const string WIRE_PROTOCOL_VERSION;

	/* mavlink_types.h */

	[CCode (cprefix = "MAVLINK_")]
	public const size_t MAX_PAYLOAD_LEN;
	[CCode (cprefix = "MAVLINK_")]
	public const size_t NUM_NON_PAYLOAD_BYTES;

	[CCode (cname = "mavlink_message_t", has_type_id = false, destroy_function = "")]
	public struct Message {
		uint16 checksum;
		uint8  magic;
		uint8  len;
		uint8  sysid;
		uint8  compid;
		uint8  msgid;
		uint64 payload64[];
	}

	[CCode (cname = "mavlink_status_t", has_type_id = false, destroy_function = "")]
	public struct Status {
	}

	/* protocol.h */

	[CCode (cprefix = "mavlink_")]
	public uint8 parse_char(uint8 chan, uint8 c, ref Message r_message, ref Status r_status);

	/* messages */
	namespace Common {
		/* mavlink_msg_heartbeat.h */
		[CCode (cname = "mavlink_heartbeat_t", has_type_id = false)]
		public struct Heartbeat {
			public uint32 custom_mode;
			public uint8 type;
			public uint8 autopilot;
			public uint8 base_mode;
			public uint8 system_status;
			public uint8 mavlink_version;

			[CCode (cname = "MAVLINK_MSG_ID_HEARTBEAT")]
			public const uint8 MSG_ID;

			[CCode (cname = "mavlink_msg_heartbeat_decode", instance_pos = -1)]
			public void decode(Message mgs);
		}

		/* mavlink_msg_gps_raw_int.h */
		[CCode (cname = "mavlink_gps_raw_int_t", has_type_id = false)]
		public struct GpsRawInt {
			public uint64 time_usec;
			public int32 lat;
			public int32 lon;
			public int32 alt;
			public uint16 eph;
			public uint16 epv;
			public uint16 vel;
			public uint16 cog;
			public uint8 fix_type;
			public uint8 satellites_visible;

			[CCode (cname = "MAVLINK_MSG_ID_GPS_RAW_INT")]
			public const uint8 MSG_ID;

			[CCode (cname = "mavlink_msg_gps_raw_int_decode", instance_pos = -1)]
			public void decode(Message mgs);
		}

		/* mavlink_msg_global_position_int.h */
		[CCode (cname = "mavlink_global_position_int_t", has_type_id = false)]
		public struct GlobalPositionInt {
			public uint32 time_boot_ms;
			public int32 lat;
			public int32 lon;
			public int32 alt;
			public int32 relative_alt;
			public int16 vx;
			public int16 vy;
			public int16 vz;
			public uint16 hdg;

			[CCode (cname = "MAVLINK_MSG_ID_GLOBAL_POSITION_INT")]
			public const uint8 MSG_ID;

			[CCode (cname = "mavlink_msg_global_position_int_decode", instance_pos = -1)]
			public void decode(Message mgs);
		}
	}
}
