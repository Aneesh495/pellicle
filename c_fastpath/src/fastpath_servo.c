/**
 * Pellicle C17 Fastpath: 20 kHz discrete digital servo implementation.
 */

#include "pellicle/fastpath_servo.h"
#include <math.h>
#include <string.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

void fastpath_notch_init(fastpath_notch_t *notch, double f0_hz, double q_factor, double fs_hz) {
    if (!notch) return;
    memset(notch, 0, sizeof(fastpath_notch_t));
    
    double omega0 = 2.0 * M_PI * f0_hz / fs_hz;
    double alpha = sin(omega0) / (2.0 * q_factor);
    double cos_w0 = cos(omega0);
    
    double a0 = 1.0 + alpha;
    notch->b0 = 1.0 / a0;
    notch->b1 = (-2.0 * cos_w0) / a0;
    notch->b2 = 1.0 / a0;
    notch->a1 = (-2.0 * cos_w0) / a0;
    notch->a2 = (1.0 - alpha) / a0;
}

double fastpath_notch_step(fastpath_notch_t *notch, double input) {
    if (!notch) return input;
    
    double output = notch->b0 * input +
                    notch->b1 * notch->x1 +
                    notch->b2 * notch->x2 -
                    notch->a1 * notch->y1 -
                    notch->a2 * notch->y2;
                    
    notch->x2 = notch->x1;
    notch->x1 = input;
    notch->y2 = notch->y1;
    notch->y1 = output;
    
    return output;
}

static void init_axis_pid(fastpath_pid_t *pid, double kp, double ki, double kd, double kv_ff, double max_out) {
    memset(pid, 0, sizeof(fastpath_pid_t));
    pid->kp = kp;
    pid->ki = ki;
    pid->kd = kd;
    pid->kv_ff = kv_ff;
    pid->max_output = max_out;
    pid->min_output = -max_out;
    
    /* Cascaded notch filters at 180 Hz and 450 Hz for wafer stage resonance */
    fastpath_notch_init(&pid->notch1, 180.0, 8.0, PELLICLE_SERVO_FREQ_HZ);
    fastpath_notch_init(&pid->notch2, 450.0, 10.0, PELLICLE_SERVO_FREQ_HZ);
}

void fastpath_servo_init(fastpath_servo_t *servo) {
    if (!servo) return;
    memset(servo, 0, sizeof(fastpath_servo_t));
    
    /* X and Y axes: Planar translation (120 m/s^2 capable) */
    init_axis_pid(&servo->axis_controllers[0], 25000.0, 1200.0, 85.0, 4.2, 450.0);
    init_axis_pid(&servo->axis_controllers[1], 25000.0, 1200.0, 85.0, 4.2, 450.0);
    
    /* Z axis: Vertical leveling (sub-nanometer focus) */
    init_axis_pid(&servo->axis_controllers[2], 40000.0, 3500.0, 120.0, 6.0, 250.0);
    
    /* Rx, Ry, Rz axes: Angular tip/tilt/yaw */
    init_axis_pid(&servo->axis_controllers[3], 15000.0, 800.0, 45.0, 2.0, 80.0);
    init_axis_pid(&servo->axis_controllers[4], 15000.0, 800.0, 45.0, 2.0, 80.0);
    init_axis_pid(&servo->axis_controllers[5], 18000.0, 950.0, 55.0, 2.5, 90.0);
}

static double step_axis_pid(fastpath_pid_t *pid, double target_pos, double target_vel, double actual_pos) {
    double error = target_pos - actual_pos;
    
    /* Integral with anti-windup clamping */
    pid->integral_state += error * PELLICLE_SERVO_DT_SEC;
    if (pid->integral_state > 0.05) pid->integral_state = 0.05;
    if (pid->integral_state < -0.05) pid->integral_state = -0.05;
    
    /* Derivative based on error rate */
    double derivative = (error - pid->prev_error) / PELLICLE_SERVO_DT_SEC;
    pid->prev_error = error;
    
    /* Feedback + Feedforward */
    double u_raw = (pid->kp * error) +
                   (pid->ki * pid->integral_state) +
                   (pid->kd * derivative) +
                   (pid->kv_ff * target_vel);
                   
    /* Notch filtering */
    double u_notch = fastpath_notch_step(&pid->notch1, u_raw);
    double u_filtered = fastpath_notch_step(&pid->notch2, u_notch);
    
    /* Output saturation */
    if (u_filtered > pid->max_output) u_filtered = pid->max_output;
    if (u_filtered < pid->min_output) u_filtered = pid->min_output;
    
    return u_filtered;
}

void fastpath_servo_step(fastpath_servo_t *servo,
                         const fastpath_pose_t *target_pose,
                         const fastpath_velocity_t *target_vel,
                         const fastpath_pose_t *actual_pose,
                         fastpath_wrench_t *out_wrench) {
    if (!servo || !target_pose || !target_vel || !actual_pose || !out_wrench) return;
    
    if (servo->e_stop_latched) {
        memset(out_wrench, 0, sizeof(fastpath_wrench_t));
        return;
    }
    
    out_wrench->fx_n = step_axis_pid(&servo->axis_controllers[0], target_pose->x_mm, target_vel->vx_mps, actual_pose->x_mm);
    out_wrench->fy_n = step_axis_pid(&servo->axis_controllers[1], target_pose->y_mm, target_vel->vy_mps, actual_pose->y_mm);
    out_wrench->fz_n = step_axis_pid(&servo->axis_controllers[2], target_pose->z_mm, target_vel->vz_mps, actual_pose->z_mm);
    
    out_wrench->tx_nm = step_axis_pid(&servo->axis_controllers[3], target_pose->rx_urad, target_vel->wx_mrad_ps, actual_pose->rx_urad);
    out_wrench->ty_nm = step_axis_pid(&servo->axis_controllers[4], target_pose->ry_urad, target_vel->wy_mrad_ps, actual_pose->ry_urad);
    out_wrench->tz_nm = step_axis_pid(&servo->axis_controllers[5], target_pose->rz_urad, target_vel->wz_mrad_ps, actual_pose->rz_urad);
    
    servo->cycle_count++;
}
