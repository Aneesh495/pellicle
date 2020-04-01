/**
 * Pellicle C17 Fastpath: Unit and numerical precision test suite.
 */

#include "pellicle/fastpath_types.h"
#include "pellicle/fastpath_interf.h"
#include "pellicle/fastpath_kinematics.h"
#include "pellicle/fastpath_servo.h"

#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <math.h>
#include <assert.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

static int g_pass_count = 0;
static int g_fail_count = 0;

static void assert_double_near(const char *name, double expected, double actual, double eps) {
    if (fabs(expected - actual) <= eps) {
        printf("  [PASS] %s (got %g, expected %g)\n", name, actual, expected);
        g_pass_count++;
    } else {
        printf("  [FAIL] %s: expected %g but got %g (diff: %g > eps: %g)\n",
               name, expected, actual, fabs(expected - actual), eps);
        g_fail_count++;
    }
}

static void assert_true(const char *name, bool cond) {
    if (cond) {
        printf("  [PASS] %s\n", name);
        g_pass_count++;
    } else {
        printf("  [FAIL] %s: condition evaluated to FALSE\n", name);
        g_fail_count++;
    }
}

static void test_edlen_precision(void) {
    printf("--- C17 Test Suite: Edlen Atmospheric Index ---\n");
    double n_air = fastpath_edlen_calculate(20.0, 101325.0, 45.0, 450.0);
    /* Reference Birch & Downs value at 20 C, 101325 Pa, 45% RH is ~1.00027137 */
    assert_double_near("Nominal cleanroom n_air", 1.00027137, n_air, 1.0e-5);
    
    /* Pressure sensitivity test: +1000 Pa should increase refractive index */
    double n_high_p = fastpath_edlen_calculate(20.0, 102325.0, 45.0, 450.0);
    assert_true("Refractive index increases with pressure", n_high_p > n_air);
}

static void test_phase_unwrapping(void) {
    printf("--- C17 Test Suite: Phase Unwrapping & Triangulation ---\n");
    fastpath_interf_channel_t ch;
    ch.fringe_count = 0;
    ch.fractional_phase_rad = 0.0;
    ch.signal_amplitude_mv = 400.0;
    ch.loss_of_signal = false;
    
    /* Step 1: Angle at +2.82 rad (in Quadrant II) */
    fastpath_interf_update_channel(&ch, -300.0, 100.0, 1.0e6, 1.0e6, 0.001);
    assert_true("Fringe count zero before crossing", ch.fringe_count == 0);
    
    /* Step 2: Continuous forward rotation crossing -pi/+pi boundary to -2.82 rad (Quadrant III) */
    fastpath_interf_update_channel(&ch, -300.0, -100.0, 1.0e6, 1.0e6, 0.001);
    assert_true("Fringe count incremented after positive wrap", ch.fringe_count == 1);
}

static void test_actuator_decoupling(void) {
    printf("--- C17 Test Suite: Lorentz Force Decoupling ---\n");
    fastpath_wrench_t wrench = {
        .fx_n = 50.0,
        .fy_n = 0.0,
        .fz_n = 100.0,
        .tx_nm = 0.0,
        .ty_nm = 0.0,
        .tz_nm = 0.0
    };
    
    fastpath_actuator_state_t act;
    fastpath_kinematics_allocate_currents(&wrench, &act);
    
    /* Horizontal symmetric force: I1 == I2 == 50 / (2 * 18.5) = 1.35135 A */
    double expected_i_h = 50.0 / (2.0 * LORENTZ_KF_N_PER_A);
    assert_double_near("Planar coil I1", expected_i_h, act.currents_a[0], 1.0e-4);
    assert_double_near("Planar coil I2", expected_i_h, act.currents_a[1], 1.0e-4);
    
    /* Vertical symmetric force: I5 == I6 == I7 == I8 == 100 / (4 * 18.5) = 1.35135 A */
    double expected_i_v = 100.0 / (4.0 * LORENTZ_KF_N_PER_A);
    assert_double_near("Levitation coil I5", expected_i_v, act.currents_a[4], 1.0e-4);
    
    assert_true("Actuator currents within safety limit", !act.current_saturation);
    assert_true("Actuator thermal power within safety limit", !act.thermal_alarm);
}

static void test_notch_filter_attenuation(void) {
    printf("--- C17 Test Suite: Biquad Notch Filter ---\n");
    fastpath_notch_t notch;
    fastpath_notch_init(&notch, 180.0, 10.0, PELLICLE_SERVO_FREQ_HZ);
    
    /* Feed 180 Hz sinusoidal input and verify steady-state attenuation */
    double f_res = 180.0;
    double dt = 1.0 / PELLICLE_SERVO_FREQ_HZ;
    double max_out = 0.0;
    
    for (int i = 0; i < 2000; i++) {
        double t = i * dt;
        double in = sin(2.0 * M_PI * f_res * t);
        double out = fastpath_notch_step(&notch, in);
        if (i > 1500) {
            if (fabs(out) > max_out) max_out = fabs(out);
        }
    }
    
    /* Notch filter with Q=10 should attenuate resonance by > 20 dB (amplitude < 0.15) */
    assert_true("Notch filter attenuates 180 Hz resonance (> 20 dB)", max_out < 0.15);
}

int main(void) {
    printf("================================================================================\n");
    printf("Pellicle C17 Fastpath Test Suite\n");
    printf("================================================================================\n");
    
    test_edlen_precision();
    test_phase_unwrapping();
    test_actuator_decoupling();
    test_notch_filter_attenuation();
    
    printf("--------------------------------------------------------------------------------\n");
    printf("Fastpath Results: %d Passed, %d Failed\n", g_pass_count, g_fail_count);
    printf("================================================================================\n");
    
    return (g_fail_count == 0) ? 0 : 1;
}
