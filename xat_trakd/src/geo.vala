/**
 * geodetic maths.
 * Thanks to PX4 and ArduPilot projects.
 */
namespace Geo {
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


}
