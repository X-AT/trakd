/**
 * geodetic maths.
 * Thanks to PX4 and ArduPilot projects.
 */
namespace Geo {
	public const double RADIUS_OF_EARTH = 6371e3;	// meters

	internal inline double radians(double deg) {
		return deg * Math.PI / 180.0;
	}

	internal inline double degrees(double rad) {
		return rad * 180.0 / Math.PI;
	}

	/**
	 * Wrap normalized angle to ±pi.
	 */
	internal double fast_wrap_pi(double angle) {
		if (!angle.is_finite())
			return double.NAN;

		while (angle > Math.PI)
			angle -= 2.0 * Math.PI;
		while (angle < -Math.PI)
			angle += 2.0 * Math.PI;

		return angle;
	}

	/**
	 * Wrap angle to ±pi
	 */
	public double wrap_pi(double angle) {
		if (-6.0 * Math.PI < angle < 6.0 * Math.PI)
			return fast_wrap_pi(angle);
		else
			return Math.fmod(angle, 2.0 * Math.PI);
	}

	/**
	 * Returns distance between coords.
	 *
	 * Based on PX4 get_distance_to_next_waypoint() from geo.c
	 *
	 * @param lat1 current position in degrees
	 * @param lat2 mav position
	 */
	public double get_distance(double lat1, double lon1, double lat2, double lon2) {
		var lat1_rad = radians(lat1);
		var lon1_rad = radians(lon1);
		var lat2_rad = radians(lat2);
		var lon2_rad = radians(lon2);

		var d_lat = lat2_rad - lat1_rad;
		var d_lon = lon2_rad - lon1_rad;

		var d_lat_2_sin = Math.sin(d_lat / 2.0);
		var d_lon_2_sin = Math.sin(d_lon / 2.0);
		var a = d_lat_2_sin * d_lat_2_sin + d_lon_2_sin * d_lon_2_sin * Math.cos(lat1_rad) * Math.cos(lat2_rad);
		var c = 2.0 * Math.atan2(Math.sqrt(a), Math.sqrt(1.0 - a));

		return RADIUS_OF_EARTH * c;
	}

	/**
	 * Returns bearing to coords 2
	 *
	 * Based on PX4 get_bearing_to_next_waypoint() from geo.c
	 *
	 * @param lat1 current position in degrees
	 * @param lat2 mav position
	 */
	public double get_bearing(double lat1, double lon1, double lat2, double lon2) {
		var lat1_rad = radians(lat1);
		var lon1_rad = radians(lon1);
		var lat2_rad = radians(lat2);
		var lon2_rad = radians(lon2);

		var d_lon = lon2_rad - lon1_rad;
		var theta = Math.atan2(Math.sin(d_lon) * Math.cos(lat2_rad),
				Math.cos(lat1_rad) * Math.sin(lat2_rad) - Math.sin(lat1_rad) * Math.cos(lat2_rad) * Math.cos(d_lon));

		return wrap_pi(theta);
	}
}
