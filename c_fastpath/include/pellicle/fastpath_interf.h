/**
 * Pellicle C17 Fastpath: Interferometer metrology and Edlen compensation.
 */

#ifndef PELLICLE_FASTPATH_INTERF_H
#define PELLICLE_FASTPATH_INTERF_H

#include "pellicle/fastpath_types.h"

#define HE_NE_WAVELENGTH_VACUUM_NM 632.816460
#define INTERFEROMETER_BASELINE_MM 120.0

/* Initialize interferometer cluster with cleanroom default calibration */
void fastpath_interf_init(fastpath_interf_cluster_t *cluster);

/* Compute dynamic refractive index of air using Edlen equation in C17 */
double fastpath_edlen_calculate(double temp_c, double pressure_pa, double humidity_pct, double co2_ppm);

/* Unwarp raw heterodyne receiver I/Q voltages into fringe count and fractional phase */
void fastpath_interf_update_channel(fastpath_interf_channel_t *channel,
                                    double in_phase_mv,
                                    double quad_phase_mv,
                                    double f_ref_hz,
                                    double f_meas_hz,
                                    double dt_sec);

/* Convert interferometer readings into 6-DoF stage pose */
void fastpath_interf_triangulate_pose(const fastpath_interf_cluster_t *cluster,
                                      fastpath_pose_t *out_pose);

#endif /* PELLICLE_FASTPATH_INTERF_H */
