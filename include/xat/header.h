
#pragma once

#include <atomic>
#include <chrono>
#include "xat_msgs/header_t.hpp"

namespace xat {

class MsgHeader {
public:
	MsgHeader() :
		_next_seq(0)
	{ };

	/**
	 * Return header filled by current time and seq number
	 */
	inline xat_msgs::header_t next()
	{
		xat_msgs::header_t h;

		h.seq = _next_seq;
		_next_seq++;

		return h;
	}

	/**
	 * Return header filled by current time and seq number
	 */
	inline xat_msgs::header_t next_now()
	{
		xat_msgs::header_t h;

		h.seq = _next_seq;
		_next_seq++;

		h.stamp = stamp_now();

		return h;
	}

	/**
	 * Get current time
	 */
	inline int64_t stamp_now()
	{
		auto us = std::chrono::time_point_cast<std::chrono::microseconds>(
				std::chrono::system_clock::now());
		return us.time_since_epoch().count();
	}

private:
	std::atomic<uint32_t> _next_seq;

	// forbid object copy
	MsgHeader(const MsgHeader&) = delete;
	MsgHeader& operator= (const MsgHeader&) = delete;
};

};
