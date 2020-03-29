/**
 * Pellicle C17 Fastpath: Binary IPC server over POSIX domain sockets.
 */

#ifndef PELLICLE_FASTPATH_IPC_H
#define PELLICLE_FASTPATH_IPC_H

#include "pellicle/fastpath_types.h"

typedef struct {
    int server_fd;
    char socket_path[256];
    bool is_running;
    fastpath_servo_t servo;
    fastpath_pose_t target_pose;
    fastpath_velocity_t target_velocity;
    fastpath_pose_t actual_pose;
    fastpath_velocity_t actual_velocity;
    fastpath_wrench_t commanded_wrench;
    fastpath_actuator_state_t actuator_state;
    fastpath_interf_cluster_t interf_cluster;
    uint32_t current_chuck_state;
    uint8_t current_shutter_state;
} fastpath_server_t;

/* Initialize IPC server and bind to UNIX domain socket */
int fastpath_ipc_server_init(fastpath_server_t *server, const char *socket_path);

/* Process incoming IPC client requests (non-blocking) */
int fastpath_ipc_server_poll(fastpath_server_t *server);

/* Close socket and clean up IPC server */
void fastpath_ipc_server_close(fastpath_server_t *server);

#endif /* PELLICLE_FASTPATH_IPC_H */
