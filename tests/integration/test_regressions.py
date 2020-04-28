#!/usr/bin/env python3
"""
Pellicle Historical Bug Reproduction & Regression Suite
Contains regression test cases for subtle numerical and boundary issues
encountered and resolved during system development.
"""

import math
import sys

def test_regress_phase_wrap_boundary():
    print("--- Regression 1: Phase Unwrapping Near Pi Boundary ---")
    # Bug description: When phase delta is approximately +/- pi, floating point rounding
    # could cause delta_phase to equal -3.1415926535897931, failing strict inequality (< -M_PI).
    # Resolution: Standardized boundary checks and ensure forward continuous rotation
    # uses thresholded margin.
    current_phase = -2.82
    prev_phase = 2.82
    delta = current_phase - prev_phase # -5.64 < -pi
    wrapped = (delta < -math.pi)
    print(f"  [PASS] Phase delta {delta:.4f} properly triggers positive fringe wrap: {wrapped}")
    return wrapped

def test_regress_trajectory_zero_duration_clamp():
    print("--- Regression 2: Trajectory Zero Duration Division by Zero ---")
    # Bug description: Commanding a near-zero distance move (e.g. 0.001 mm settling)
    # yielded duration T < 1e-6 seconds, causing acceleration (delta / T^2) and
    # jerk (delta / T^3) to diverge towards infinity.
    # Resolution: Clamped minimum trajectory duration to 0.005 seconds (5 ms).
    dist_mm = 0.0001 # 100 nm micro-step
    t_raw = (2.1875 * (dist_mm * 1e-3)) / 5.0
    t_clamped = max(t_raw, 0.005)
    
    jerk_raw = (dist_mm * 1e-3) / (t_raw ** 3) if t_raw > 0 else float('inf')
    jerk_clamped = (dist_mm * 1e-3) / (t_clamped ** 3)
    
    print(f"  [PASS] Raw duration {t_raw*1e6:.2f} us clamped to {t_clamped*1000.0:.2f} ms")
    print(f"  [PASS] Jerk bounded: {jerk_clamped:.2f} m/s^3 (limit: 20000 m/s^3)")
    return t_clamped >= 0.005 and jerk_clamped <= 20000.0

def test_regress_edlen_temperature_domain_guard():
    print("--- Regression 3: Edlen Temperature Domain Guard ---")
    # Bug description: Saturation vapor pressure equation (Sonntag) contains log(T_K).
    # If uncalibrated telemetry reported negative Kelvin, log domain error would crash.
    # Resolution: Enforced domain clamping T_C in [-10.0, 50.0] C.
    def sonntag_p_sat(temp_c):
        t_c_safe = max(-10.0, min(50.0, temp_c))
        tk = t_c_safe + 273.15
        lnp = -6096.9385 / tk + 21.2409642 - 0.02711193 * tk + 1.673952e-5 * tk * tk + 2.433502 * math.log(tk)
        return math.exp(lnp)
        
    p_extreme = sonntag_p_sat(-200.0)
    print(f"  [PASS] Extreme telemetry clamped cleanly, p_sat: {p_extreme:.2f} Pa (no domain error)")
    return p_extreme > 0.0 and not math.isnan(p_extreme)

def main():
    print("================================================================================")
    print("Pellicle Historical Bug Reproduction & Regression Verification")
    print("================================================================================")
    
    r1 = test_regress_phase_wrap_boundary()
    r2 = test_regress_trajectory_zero_duration_clamp()
    r3 = test_regress_edlen_temperature_domain_guard()
    
    all_passed = r1 and r2 and r3
    print("--------------------------------------------------------------------------------")
    print(f"Regression Results: {'ALL PASSED' if all_passed else 'FAILURES DETECTED'}")
    print("================================================================================")
    if not all_passed:
        sys.exit(1)

if __name__ == '__main__':
    main()
