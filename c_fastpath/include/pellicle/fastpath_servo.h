/**
 * Pellicle C17 Fastpath: 20 kHz discrete digital servo and notch filter.
 */

#ifndef PELLICLE_FASTPATH_SERVO_H
#define PELLICLE_FASTPATH_SERVO_H

#include "pellicle/fastpath_types.h"

/* Initialize single-axis notch filter for target resonance frequency and Q factor */
void fastpath_notch_init(fastpath_notch_t *notch, double f0_hz, double q_factor, double fs_hz);

/* Process one sample through the discrete biquad notch filter */
double fastpath_notch_step(fastpath_notch_t *notch, double input);

/* Initialize 6-DoF servo controller with tuned PID gains and notch filters */
void fastpath_servo_init(fastpath_servo_t *servo);

/* Execute single 20 kHz discrete servo step across all 6 degrees of freedom */
void fastpath_servo_step(fastpath_servo_t *servo,
                         const fastpath_pose_t *target_pose,
                         const fastpath_velocity_t *target_vel,
                         const fastpath_pose_t *actual_pose,
                         fastpath_wrench_t *out_wrench);

#endif /* PELLICLE_FASTPATH_SERVO_H */
