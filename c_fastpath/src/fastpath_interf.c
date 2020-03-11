/**
 * Pellicle C17 Fastpath: Interferometer metrology implementation.
 */

#include "pellicle/fastpath_interf.h"
#include <math.h>
#include <string.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

void fastpath_interf_init(fastpath_interf_cluster_t *cluster) {
    if (!cluster) return;
    memset(cluster, 0, sizeof(fastpath_interf_cluster_t));
    cluster->temperature_c = 20.000;
    cluster->pressure_pa = 101325.0;
    cluster->humidity_pct = 45.0;
    cluster->atmospheric_n_air = fastpath_edlen_calculate(20.0, 101325.0, 45.0, 450.0);
    for (int i = 0; i < 7; i++) {
        cluster->channels[i].signal_amplitude_mv = 450.0;
        cluster->channels[i].loss_of_signal = false;
    }
}

double fastpath_edlen_calculate(double temp_c, double pressure_pa, double humidity_pct, double co2_ppm) {
    double sigma = 1000.0 / HE_NE_WAVELENGTH_VACUUM_NM;
    double sigma2 = sigma * sigma;
    
    double term1 = 8342.54;
    double term2 = 2406147.0 / (130.0 - sigma2);
    double term3 = 15998.0 / (38.9 - sigma2);
    double ns_minus_1 = (term1 + term2 + term3) * 1.0e-8;
    
    double nx_minus_1 = ns_minus_1 * (1.0 + 0.534e-6 * (co2_ppm - 450.0));
    
    double alpha = 0.003661;
    double beta = 1.0e-8 * (0.601 - 0.00972 * temp_c) * pressure_pa;
    double num = pressure_pa * (1.0 + beta);
    double den = 96095.43 * (1.0 + alpha * temp_c);
    double ntp_minus_1 = nx_minus_1 * (num / den);
    
    /* Saturation vapor pressure of water */
    double tk = temp_c + 273.15;
    double lnp = -6096.9385 / tk + 21.2409642 - 0.02711193 * tk + 1.673952e-5 * tk * tk + 2.433502 * log(tk);
    double p_sat = exp(lnp);
    double f = (humidity_pct / 100.0) * p_sat;
    double vapor_corr = - f * (3.7345 - 0.0401 * sigma2) * 1.0e-10;
    
    return 1.0 + ntp_minus_1 + vapor_corr;
}

void fastpath_interf_update_channel(fastpath_interf_channel_t *channel,
                                    double in_phase_mv,
                                    double quad_phase_mv,
                                    double f_ref_hz,
                                    double f_meas_hz,
                                    double dt_sec) {
    if (!channel) return;
    (void)dt_sec;
    
    double amp = sqrt(in_phase_mv * in_phase_mv + quad_phase_mv * quad_phase_mv);
    channel->signal_amplitude_mv = amp;
    channel->loss_of_signal = (amp < 50.0);
    
    if (channel->loss_of_signal) {
        return;
    }
    
    double current_phase = atan2(quad_phase_mv, in_phase_mv);
    double delta_phase = current_phase - channel->fractional_phase_rad;
    
    /* Phase unwrapping crossing [-pi, pi] */
    if (delta_phase > M_PI) {
        channel->fringe_count -= 1;
    } else if (delta_phase < -M_PI) {
        channel->fringe_count += 1;
    }
    
    channel->fractional_phase_rad = current_phase;
    channel->doppler_freq_hz = f_meas_hz - f_ref_hz;
}

void fastpath_interf_triangulate_pose(const fastpath_interf_cluster_t *cluster,
                                      fastpath_pose_t *out_pose) {
    if (!cluster || !out_pose) return;
    
    double lambda_eff = HE_NE_WAVELENGTH_VACUUM_NM / (2.0 * cluster->atmospheric_n_air);
    double axis_pos_nm[7];
    
    for (int i = 0; i < 7; i++) {
        const fastpath_interf_channel_t *ch = &cluster->channels[i];
        double total_fringes = (double)ch->fringe_count + (ch->fractional_phase_rad / (2.0 * M_PI));
        axis_pos_nm[i] = total_fringes * lambda_eff;
    }
    
    /* Triangulation: X from X1 and X2, Y from Y1 and Y2, Z from Z1, Z2, Z3 */
    double x_nm = (axis_pos_nm[0] + axis_pos_nm[1]) * 0.5;
    double y_nm = (axis_pos_nm[2] + axis_pos_nm[3]) * 0.5;
    double z_nm = (axis_pos_nm[4] + axis_pos_nm[5] + axis_pos_nm[6]) / 3.0;
    
    double rz_rad = (axis_pos_nm[1] - axis_pos_nm[0]) / (INTERFEROMETER_BASELINE_MM * 1.0e6);
    double rx_rad = (axis_pos_nm[5] - axis_pos_nm[4]) / (INTERFEROMETER_BASELINE_MM * 1.0e6);
    double ry_rad = (axis_pos_nm[6] - axis_pos_nm[4]) / (INTERFEROMETER_BASELINE_MM * 1.0e6);
    
    out_pose->x_mm = x_nm * 1.0e-6;
    out_pose->y_mm = y_nm * 1.0e-6;
    out_pose->z_mm = z_nm * 1.0e-6;
    out_pose->rx_urad = rx_rad * 1.0e6;
    out_pose->ry_urad = ry_rad * 1.0e6;
    out_pose->rz_urad = rz_rad * 1.0e6;
}
