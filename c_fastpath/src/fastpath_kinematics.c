/**
 * Pellicle C17 Fastpath: Kinematics and actuator decoupling implementation.
 */

#include "pellicle/fastpath_kinematics.h"
#include <math.h>
#include <string.h>

void fastpath_kinematics_allocate_currents(const fastpath_wrench_t *wrench,
                                           fastpath_actuator_state_t *actuator_state) {
    if (!wrench || !actuator_state) return;
    
    double kf = LORENTZ_KF_N_PER_A;
    double r  = ACTUATOR_LEVER_ARM_M;
    
    /* Horizontal Planar Coils (1 to 4) */
    double i1 = (wrench->fx_n / (2.0 * kf)) + (wrench->tz_nm / (4.0 * kf * r));
    double i2 = (wrench->fx_n / (2.0 * kf)) - (wrench->tz_nm / (4.0 * kf * r));
    double i3 = (wrench->fy_n / (2.0 * kf)) + (wrench->tz_nm / (4.0 * kf * r));
    double i4 = (wrench->fy_n / (2.0 * kf)) - (wrench->tz_nm / (4.0 * kf * r));
    
    /* Vertical Levitation Coils (5 to 8) */
    double fz_term = wrench->fz_n / (4.0 * kf);
    double ty_term = wrench->ty_nm / (4.0 * kf * r);
    double tx_term = wrench->tx_nm / (4.0 * kf * r);
    
    double i5 = fz_term + ty_term + tx_term;
    double i6 = fz_term - ty_term + tx_term;
    double i7 = fz_term + ty_term - tx_term;
    double i8 = fz_term - ty_term - tx_term;
    
    actuator_state->currents_a[0] = i1;
    actuator_state->currents_a[1] = i2;
    actuator_state->currents_a[2] = i3;
    actuator_state->currents_a[3] = i4;
    actuator_state->currents_a[4] = i5;
    actuator_state->currents_a[5] = i6;
    actuator_state->currents_a[6] = i7;
    actuator_state->currents_a[7] = i8;
    
    double sum_i2 = 0.0;
    bool sat = false;
    for (int k = 0; k < 8; k++) {
        double current = actuator_state->currents_a[k];
        if (fabs(current) > MAX_COIL_CURRENT_A) {
            sat = true;
        }
        sum_i2 += current * current;
    }
    
    actuator_state->total_ohmic_power_w = sum_i2 * COIL_RESISTANCE_OHMS;
    actuator_state->current_saturation = sat;
    actuator_state->thermal_alarm = (actuator_state->total_ohmic_power_w > MAX_THERMAL_POWER_W);
}

bool fastpath_kinematics_check_envelope(const fastpath_pose_t *pose) {
    if (!pose) return false;
    if (pose->x_mm < -250.0 || pose->x_mm > 250.0) return false;
    if (pose->y_mm < -250.0 || pose->y_mm > 250.0) return false;
    if (pose->z_mm < -5.0   || pose->z_mm > 5.0)   return false;
    return true;
}

double fastpath_kinematics_chuck_clearance(const fastpath_pose_t *p1, const fastpath_pose_t *p2) {
    if (!p1 || !p2) return 0.0;
    double dx = p2->x_mm - p1->x_mm;
    double dy = p2->y_mm - p1->y_mm;
    return sqrt(dx * dx + dy * dy);
}
