/**
 * @brief HID reports supported by 
 * @file
 */

#pragma once

#include <endian.h>
#include <stdint.h>

namespace xat_hid {

#define ATTR_PACKED	__attribute__((packed))

namespace report {

struct Info {
	uint8_t device_caps[60];
} ATTR_PACKED;

struct Status {
	enum Flags {
		AZ_IN_MOTION	= (1<<0),
		EL_IN_MOTION	= (1<<1),
	};
	enum Buttons {
		STATUS_BUTTON1	= (1<<0),	// azimuth endstop
		STATUS_BUTTON2	= (1<<1),
	};

	uint8_t flags;
	uint8_t buttons;
	int32_t azimuth_position;
	int32_t elevation_position; /* aka USAGE(altitude) */
} ATTR_PACKED;

struct Bat_Voltage {
	uint16_t raw_adc;
} ATTR_PACKED;

struct Stepper_Settings {
	uint16_t azimuth_acceleration;
	uint16_t elevation_acceleration;
	uint16_t azimuth_max_speed;
	uint16_t elevation_max_speed;
} ATTR_PACKED;

struct Az_El {
	int32_t azimuth_position;
	int32_t elevation_position;
} ATTR_PACKED;

struct QTR {
	uint16_t azimuth_qtr_raw;
	uint16_t elevation_qtr_raw;
} ATTR_PACKED;

struct Cur_Position {
	int32_t azimuth_position;
	int32_t elevation_position;
} ATTR_PACKED;

struct Stop {
	enum Motor {
		MOTOR_AZ	= (1<<0),
		MOTOR_EL	= (1<<1),
	};

	uint8_t motor;
} ATTR_PACKED;

}; // namespace report

enum XAT_USB_ID {
	XAT_VID = 0x03EB,
	XAT_PID = 0x204F,
};

struct XAT_Report {
	enum ReportID {
		ID_F_INFO		= 1,	/**< Get device info */
		ID_G_STATUS		= 2,	/**< Get status: endstops and positions */
		ID_G_BAT_VOLTAGE	= 3,	/**< Get raw analog value of Vbat (see logical/phys min/max desc) */
		ID_F_STEPPER_SETTINGS	= 4,	/**< Get/set acceleration and velocity settings */
		ID_S_AZ_EL		= 5,	/**< Set target position for steppers */
		ID_F_QTR		= 6,	/**< Get raw analog value / Set threshold level */
		ID_F_CUR_POSITION	= 7,	/**< Set current position of steppers (cuse with caution) */
		ID_S_STOP		= 8,	/**< Require stop of motors */
	};

	uint8_t report_id;
	union {
		uint8_t data[63];
		struct report::Info info;
		struct report::Status status;
		struct report::Bat_Voltage bat_voltage;
		struct report::Stepper_Settings stepper_settings;
		struct report::Az_El az_el;
		struct report::QTR qtr;
		struct report::Cur_Position cur_position;
		struct report::Stop stop;
	};
} ATTR_PACKED;

template <typename T>
constexpr size_t report_size(T report)
{
	return 1 + sizeof(T);
}

}; // namespace

