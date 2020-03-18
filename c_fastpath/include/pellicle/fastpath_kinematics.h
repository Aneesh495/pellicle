/**
 * Pellicle C17 Fastpath: Kinematics and actuator decoupling engine.
 */

#ifndef PELLICLE_FASTPATH_KINEMATICS_H
#define PELLICLE_FASTPATH_KINEMATICS_H

#include "pellicle/fastpath_types.h"

#define LORENTZ_KF_N_PER_A 18.5
#define ACTUATOR_LEVER_ARM_M 0.160
#define COIL_RESISTANCE_OHMS 2.40
#define MAX_COIL_CURRENT_A 12.0
#define MAX_THERMAL_POWER_W 150.0

/* Allocate 6-DoF wrench to 8 coil currents using Moore-Penrose pseudo-inverse */
void fastpath_kinematics_allocate_currents(const fastpath_wrench_t *wrench,
                                           fastpath_actuator_state_t *actuator_state);

/* Check whether 6-DoF pose is within the safe machine travel envelope */
bool fastpath_kinematics_check_envelope(const fastpath_pose_t *pose);

/* Compute Euclidean clearance between Chuck 1 and Chuck 2 */
double fastpath_kinematics_chuck_clearance(const fastpath_pose_t *p1, const fastpath_pose_t *p2);

#endif /* PELLICLE_FASTPATH_KINEMATICS_H */
