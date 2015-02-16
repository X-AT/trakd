/* libgps.vapi
 *
 * Copyright (C) 2011 Michael 'Mickey' Lauer <mlauer@vanille-media.de>
 * Copyright (C) 2015 Vladimir Ermakov <vooon341@gmail.com>
 *
 * Updated for libgps 5.1 API.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.

 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.

 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
 *
 */

[CCode (lower_case_cprefix = "gps_", cheader_filename = "gps.h")]
namespace Gps {
    /* constants */
    public const uint MAXTAGLEN;
    public const uint MAXCHANNELS;
    public const uint GPS_PRNMAX;
    public const uint GPS_PATH_MAX;
    public const uint MAXUSERDEVS;

    /* enum and flags */
    [Flags]
    [CCode (cname = "uint", has_type_id = false, cprefix = "WATCH_")]
    public enum WatchFlags {
        ENABLE,
        DISABLE,
        JSON,
        NMEA,
        RARE,
        RAW,
        SCALED,
        TIMING,
        DEVICE,
        SPLIT24,
        PPS,
        NEWSTYLE,
        OLDSTYLE
    }

    [Flags]
    [CCode (cname = "gps_mask_t", has_type_id = false, cprefix = "")]
    public enum Mask {
        ONLINE_SET,
        TIME_SET,
        TIMERR_SET,
        LATLON_SET,
        ALTITUDE_SET,
        SPEED_SET,
        TRACK_SET,
        CLIMB_SET,
        STATUS_SET,
        MODE_SET,
        DOP_SET,
        HERR_SET,
        VERR_SET,
        ATTITUDE_SET,
        SATELLITE_SET,
        SPEEDERR_SET,
        TRACKERR_SET,
        CLIMBERR_SET,
        DEVICE_SET,
        DEVICELIST_SET,
        DEVICEID_SET,
        RTCM2_SET,
        RTCM3_SET,
        AIS_SET,
        PACKET_SET,
        SUBFRAME_SET,
        GST_SET,
        VERSION_SET,
        POLICY_SET,
        LOGMESSAGE_SET,
        ERROR_SET,
        TIMEDRIFT_SET,
        EOF_SET

        //[CCode (cname = "gps_maskdump")]
        //public unowned string dump();
    }

    [Flags]
    [CCode (cname = "int", has_type_id = false, cprefix = "SEEN_", cheader_filename = "gps.h")]
    public enum SeenFlags
    {
        GPS,
        RTCM2,
        RTCM3,
        AIS
    }

    [CCode (cname = "int", has_type_id = false, cprefix = "STATUS_")]
    public enum FixStatus {
        NO_FIX,
        FIX,
        DGPS_FIX,
    }

    [CCode (cname = "int", has_type_id = false, cprefix = "")]
    public enum FixMode
    {
        MODE_NOT_SEEN,
        MODE_NO_FIX,
        MODE_2D,
        MODE_3D
    }

    /* static functions */
    public static unowned string errstr(int errno);
    public void enable_debug(int fd, Posix.FILE file);

    /* timestamp_t */
    [SimpleType]
    [CCode (cname = "timestamp_t", has_type_id = false)]
    public struct TimeStamp : double {
    }

    /* fix_t */
    [CCode (cname = "struct gps_fix_t", has_type_id = false, destroy_function = "")]
    public struct Fix
    {
        public TimeStamp time;
        public FixMode mode;
        public double ept;
        public double latitude;
        public double epy;
        public double longitude;
        public double epx;
        public double altitude;
        public double epv;
        public double track;
        public double epd;
        public double speed;
        public double eps;
        public double climb;
        public double epc;

        [CCode (cname = "gps_clear_fix")]
        public void clear();

        [CCode (cname = "gps_merge_fix")]
        public void merge(Mask mask, Fix otherFix);
    }

    /* gst_t */
    /* rtcm2_t */
    /* rtcm3_t */
    /* almanac_t */
    /* subframe_t */
    /* ais_t */
    /* attitude_t */

    /* dilution of precision */
    [CCode (cname = "struct dop_t", has_type_id = false, destroy_function = "", cprefix = "")]
    public struct Dop {
        public double xdop;
        public double ydop;
        public double pdop;
        public double hdop;
        public double vdop;
        public double tdop;
        public double gdop;

        [CCode (cname = "gps_clear_dop")]
        public void clear();
    }

    /* rawdata_t */
    /* version_t */

    /* device configuration */
    [CCode (cname = "struct devconfig_t", has_type_id = false, destroy_function = "", cprefix = "")]
    public struct DeviceConfig {
        public unowned string path;
        public SeenFlags flags;
        public unowned string driver;
        public unowned string subtype;
        public double activated;
        public uint baudrate;
        public uint stopbits;
        public char parity;
        public double cycle;
        public double mincycle;
        public int driver_mode;
    }

    /* stream policy */
    [CCode (cname = "struct policy_t", has_type_id = false, destroy_function = "")]
    public struct Policy {
        public bool watcher;
        public bool json;
        public bool nmea;
        public int raw;
        public bool scaled;
        public bool timing;
        public bool split24;
        public bool pps;
        public int loglevel;
        public unowned string devpath;
        public unowned string remote;
    }

    /* timedrift_t */

    /* device */
    [CCode (cname = "struct gps_data_t", has_type_id = false, destroy_function = "gps_close", cprefix = "gps_")]
    public struct Device {
        // special host values for Device.open()
        [CCode (cprefix = "GPSD_")]
        public const string SHARED_MEMORY;
        [CCode (cprefix = "GPSD_")]
        public const string DBUS_EXPORT;

        public Mask @set;
        public TimeStamp online;
        public int gps_fd;
        public Fix fix;
        public double separation;
        public FixStatus status;
        public int satellites_used;
        public int used[];
        public Dop dop;
        public double epe;
        public TimeStamp skyview_time;
        public int satellites_visible;
        public int PRN[];
        public int elevation[];
        public int azimuth[];
        public double ss[];
        public DeviceConfig dev;
        public Policy policy;

        /* tag[] */
        /* union with rtcm2,3, subframe, ais, attitude, raw, gst,
         * version, devices, error and timedrift
         */

        [CCode (cname = "gps_open", instance_pos = -1)]
        public int open(string server = "localhost", string port = "2947");

        public void close();

        [PrintfFormat]
        public int send(string format, ...);

        public int read();

        [CCode (instance_pos = -1)]
        public int unpack(char *buf);

        public bool waiting(int timeout);

        public int stream(WatchFlags flags, void* data = null);
    }
}

#if 0

extern time_t mkgmtime(register struct tm *);
extern double timestamp(void);
extern double iso8601_to_unix(char *);
extern /*@observer@*/char *unix_to_iso8601(double t, /*@ out @*/char[], size_t len);
extern double gpstime_to_unix(int, double);
extern void unix_to_gpstime(double, /*@out@*/int *, /*@out@*/double *);
extern double earth_distance(double, double, double, double);
extern double earth_distance_and_bearings(double, double, double, double,
					  /*@null@*//*@out@*/double *,
					  /*@null@*//*@out@*/double *);
extern double wgs84_separation(double, double);

#endif

// vim:ts=4:sw=4:expandtab

