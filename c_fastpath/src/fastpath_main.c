/**
 * Pellicle C17 Fastpath: Main daemon executable entrypoint.
 */

#include "pellicle/fastpath_types.h"
#include "pellicle/fastpath_ipc.h"
#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include <unistd.h>

static volatile bool g_running = true;

static void handle_signal(int sig) {
    (void)sig;
    g_running = false;
}

int main(int argc, char **argv) {
    const char *socket_path = (argc > 1) ? argv[1] : PELLICLE_DEFAULT_SOCKET_PATH;
    
    signal(SIGINT, handle_signal);
    signal(SIGTERM, handle_signal);
    
    printf("================================================================================\n");
    printf("  PELLICLE C17 Fastpath Hardware Acceleration Daemon\n");
    printf("  Binding UNIX domain socket: %s\n", socket_path);
    printf("  Executing 20 kHz discrete servo control loop with notch resonance suppression\n");
    printf("================================================================================\n");
    
    fastpath_server_t server;
    if (fastpath_ipc_server_init(&server, socket_path) < 0) {
        fprintf(stderr, "ERROR: Failed to initialize IPC server at %s\n", socket_path);
        return 1;
    }
    
    printf("Fastpath IPC daemon running. Press Ctrl+C to terminate.\n");
    
    uint64_t iter = 0;
    while (g_running && server.is_running) {
        fastpath_ipc_server_poll(&server);
        usleep(50); /* 50 microseconds cycle interval (20 kHz pacing) */
        
        iter++;
        if (iter % 40000 == 0) {
            printf("[Fastpath Servo] Cycles: %llu | Pose: (%.3f, %.3f, %.4f) mm | Power: %.2f W\n",
                   (unsigned long long)server.servo.cycle_count,
                   server.actual_pose.x_mm,
                   server.actual_pose.y_mm,
                   server.actual_pose.z_mm,
                   server.actuator_state.total_ohmic_power_w);
        }
    }
    
    printf("\nShutting down Pellicle C17 Fastpath server...\n");
    fastpath_ipc_server_close(&server);
    printf("Fastpath daemon cleanly exited.\n");
    
    return 0;
}
