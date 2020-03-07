/**
 * Pellicle C17 Fastpath: Type definitions and binary IPC protocol layout.
 * Compliant with ISO C17 standard and POSIX.1-2008 specifications.
 */

#ifndef PELLICLE_FASTPATH_TYPES_H
#define PELLICLE_FASTPATH_TYPES_H

#include <stdint.h>
#include <stdbool.h>

#define PELLICLE_IPC_MAGIC 0x50454C4C /* "PELL" in ASCII */
#define PELLICLE_DEFAULT_SOCKET_PATH "/tmp/pellicle_fastpath.sock"

#define PELLICLE_MAX_CHANNELS 8
#define PELLICLE_SERVO_FREQ_HZ 20000.0
#define PELLICLE_SERVO_DT_SEC (1.0 / PELLICLE_SERVO_FREQ_HZ)

/* Binary IPC Opcodes */
typedef enum {
    PELLICLE_OP_PING            = 0x01,
    PELLICLE_OP_GET_TELEMETRY   = 0x02,
    PELLICLE_OP_SET_SETPOINT    = 0x03,
    PELLICLE_OP_EXECUTE_SWAP    = 0x04,
    PELLICLE_OP_SET_SHUTTER     = 0x05,
    PELLICLE_OP_EMERGENCY_STOP  = 0x06,
    PELLICLE_OP_RESET_FAULTS    = 0x07,
    PELLICLE_OP_SHUTDOWN        = 0x0F
} pellicle_opcode_t;

/* Binary IPC Status / Error Codes */
typedef enum {
    PELLICLE_STATUS_OK             = 0x00,
    PELLICLE_ERR_INVALID_MAGIC     = 0x01,
    PELLICLE_ERR_UNKNOWN_OPCODE    = 0x02,
    PELLICLE_ERR_INTERLOCK_TRIPPED = 0x03,
    PELLICLE_ERR_ENVELOPE_BREACH   = 0x04,
    PELLICLE_ERR_CLEARANCE_VIOLATED= 0x05,
    PELLICLE_ERR_ACTUATOR_OVERTEMP = 0x06,
    PELLICLE_ERR_INTERNAL          = 0xFF
} pellicle_status_t;

/* Packed wire protocol frame header */
#pragma pack(push, 1)
typedef struct {
    uint32_t magic;
    uint16_t sequence_id;
    uint8_t  opcode;
    uint8_t  status;
    uint32_t payload_len;
    uint32_t crc32;
} pellicle_ipc_header_t;
#pragma pack(pop)

/* Six Degrees of Freedom Spatial State */
typedef struct {
    double x_mm;
    double y_mm;
    double z_mm;
    double rx_urad;
    double ry_urad;
    double rz_urad;
} fastpath_pose_t;

/* Six Degrees of Freedom Velocity State */
typedef struct {
    double vx_mps;
    double vy_mps;
    double vz_mps;
    double wx_mrad_ps;
    double wy_mrad_ps;
    double wz_mrad_ps;
} fastpath_velocity_t;

/* Six Degrees of Freedom Wrench Vector */
typedef struct {
    double fx_n;
    double fy_n;
    double fz_n;
    double tx_nm;
    double ty_nm;
    double tz_nm;
} fastpath_wrench_t;

/* Optical Heterodyne Receiver Channel State */
typedef struct {
    int32_t fringe_count;
    double  fractional_phase_rad;
    double  signal_amplitude_mv;
    double  doppler_freq_hz;
    bool    loss_of_signal;
} fastpath_interf_channel_t;

/* Multi-Axis Interferometer Cluster (7 Channels) */
typedef struct {
    fastpath_interf_channel_t channels[7];
    double atmospheric_n_air;
    double temperature_c;
    double pressure_pa;
    double humidity_pct;
} fastpath_interf_cluster_t;

/* Actuator Current Allocation State (8 Coils) */
typedef struct {
    double currents_a[PELLICLE_MAX_CHANNELS];
    double total_ohmic_power_w;
    bool   current_saturation;
    bool   thermal_alarm;
} fastpath_actuator_state_t;

/* Discrete Biquad IIR Notch Filter Structure */
typedef struct {
    double b0, b1, b2;
    double a1, a2;
    double x1, x2;
    double y1, y2;
} fastpath_notch_t;

/* Single-Axis Digital PID Controller with Anti-Windup */
typedef struct {
    double kp;
    double ki;
    double kd;
    double kv_ff;
    double ka_ff;
    double integral_state;
    double prev_error;
    double max_output;
    double min_output;
    fastpath_notch_t notch1;
    fastpath_notch_t notch2;
} fastpath_pid_t;

/* Full 6-DoF Servo Controller State */
typedef struct {
    fastpath_pid_t axis_controllers[6];
    uint64_t cycle_count;
    double cycle_time_us;
    double max_jitter_us;
    bool e_stop_latched;
} fastpath_servo_t;

/* Telemetry payload delivered over IPC */
#pragma pack(push, 1)
typedef struct {
    fastpath_pose_t actual_pose;
    fastpath_pose_t target_pose;
    fastpath_velocity_t actual_velocity;
    fastpath_wrench_t commanded_wrench;
    double coil_currents[8];
    double ohmic_power_w;
    double dma_overlay_nm;
    double msd_jitter_nm;
    uint32_t chuck_state;
    uint8_t shutter_state;
    uint8_t e_stop_active;
    uint16_t reserved;
} fastpath_telemetry_payload_t;
#pragma pack(pop)

#endif /* PELLICLE_FASTPATH_TYPES_H */
