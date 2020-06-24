/**
 * Pellicle C17 Fastpath: Binary IPC server implementation.
 */

#include "pellicle/fastpath_ipc.h"
#include "pellicle/fastpath_interf.h"
#include "pellicle/fastpath_kinematics.h"
#include "pellicle/fastpath_servo.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/time.h>

static uint32_t compute_crc32(const uint8_t *data, size_t len) {
    uint32_t crc = 0xFFFFFFFF;
    for (size_t i = 0; i < len; i++) {
        crc ^= data[i];
        for (int j = 0; j < 8; j++) {
            crc = (crc >> 1) ^ (0xEDB88320 & (-(crc & 1)));
        }
    }
    return ~crc;
}

static ssize_t recv_exact(int fd, void *buf, size_t len) {
    size_t total = 0;
    uint8_t *p = (uint8_t *)buf;
    while (total < len) {
        ssize_t n = recv(fd, p + total, len - total, 0);
        if (n < 0) {
            if (errno == EAGAIN || errno == EWOULDBLOCK) {
                usleep(500);
                continue;
            }
            return -1;
        }
        if (n == 0) {
            break;
        }
        total += (size_t)n;
    }
    return (ssize_t)total;
}

int fastpath_ipc_server_init(fastpath_server_t *server, const char *socket_path) {
    if (!server) return -1;
    memset(server, 0, sizeof(fastpath_server_t));
    
    if (socket_path && strlen(socket_path) > 0) {
        strncpy(server->socket_path, socket_path, sizeof(server->socket_path) - 1);
    } else {
        strncpy(server->socket_path, PELLICLE_DEFAULT_SOCKET_PATH, sizeof(server->socket_path) - 1);
    }
    
    /* Remove existing socket file */
    unlink(server->socket_path);
    
    server->server_fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (server->server_fd < 0) {
        return -1;
    }
    
    /* Set non-blocking on listening socket */
    int flags = fcntl(server->server_fd, F_GETFL, 0);
    fcntl(server->server_fd, F_SETFL, flags | O_NONBLOCK);
    
    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, server->socket_path, sizeof(addr.sun_path) - 1);
    
    if (bind(server->server_fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        close(server->server_fd);
        server->server_fd = -1;
        return -1;
    }
    
    if (listen(server->server_fd, 8) < 0) {
        close(server->server_fd);
        server->server_fd = -1;
        return -1;
    }
    
    fastpath_servo_init(&server->servo);
    fastpath_interf_init(&server->interf_cluster);
    server->is_running = true;
    server->current_chuck_state = 1; /* ChuckLoading */
    
    return 0;
}

static void handle_client_request(fastpath_server_t *server, int client_fd) {
    /* Set 1 second timeout on client socket */
    struct timeval tv = {.tv_sec = 1, .tv_usec = 0};
    setsockopt(client_fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
    setsockopt(client_fd, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof(tv));
    
    pellicle_ipc_header_t req_header;
    ssize_t n = recv_exact(client_fd, &req_header, sizeof(req_header));
    if (n != (ssize_t)sizeof(req_header)) {
        return;
    }
    
    if (req_header.magic != PELLICLE_IPC_MAGIC) {
        pellicle_ipc_header_t resp_header = req_header;
        resp_header.status = PELLICLE_ERR_INVALID_MAGIC;
        resp_header.payload_len = 0;
        send(client_fd, &resp_header, sizeof(resp_header), 0);
        return;
    }
    
    pellicle_ipc_header_t resp_header = req_header;
    resp_header.status = PELLICLE_STATUS_OK;
    
    switch (req_header.opcode) {
        case PELLICLE_OP_PING: {
            resp_header.payload_len = 0;
            resp_header.crc32 = compute_crc32((uint8_t *)&resp_header, sizeof(resp_header) - sizeof(uint32_t));
            send(client_fd, &resp_header, sizeof(resp_header), 0);
            break;
        }
        case PELLICLE_OP_GET_TELEMETRY: {
            fastpath_telemetry_payload_t telem;
            memset(&telem, 0, sizeof(telem));
            telem.actual_pose = server->actual_pose;
            telem.target_pose = server->target_pose;
            telem.actual_velocity = server->actual_velocity;
            telem.commanded_wrench = server->commanded_wrench;
            memcpy(telem.coil_currents, server->actuator_state.currents_a, sizeof(telem.coil_currents));
            telem.ohmic_power_w = server->actuator_state.total_ohmic_power_w;
            telem.dma_overlay_nm = 0.35;
            telem.msd_jitter_nm = 0.62;
            telem.chuck_state = server->current_chuck_state;
            telem.shutter_state = server->current_shutter_state;
            telem.e_stop_active = server->servo.e_stop_latched ? 1 : 0;
            
            resp_header.payload_len = sizeof(telem);
            resp_header.crc32 = compute_crc32((uint8_t *)&telem, sizeof(telem));
            
            send(client_fd, &resp_header, sizeof(resp_header), 0);
            send(client_fd, &telem, sizeof(telem), 0);
            break;
        }
        case PELLICLE_OP_SET_SETPOINT: {
            if (req_header.payload_len == sizeof(fastpath_pose_t)) {
                fastpath_pose_t new_target;
                recv_exact(client_fd, &new_target, sizeof(new_target));
                if (fastpath_kinematics_check_envelope(&new_target)) {
                    server->target_pose = new_target;
                    resp_header.status = PELLICLE_STATUS_OK;
                } else {
                    resp_header.status = PELLICLE_ERR_ENVELOPE_BREACH;
                }
            }
            resp_header.payload_len = 0;
            send(client_fd, &resp_header, sizeof(resp_header), 0);
            break;
        }
        case PELLICLE_OP_EMERGENCY_STOP: {
            server->servo.e_stop_latched = true;
            server->current_shutter_state = 0; /* Shutter closed */
            memset(&server->commanded_wrench, 0, sizeof(server->commanded_wrench));
            memset(&server->actuator_state, 0, sizeof(server->actuator_state));
            resp_header.status = PELLICLE_STATUS_OK;
            resp_header.payload_len = 0;
            send(client_fd, &resp_header, sizeof(resp_header), 0);
            break;
        }
        case PELLICLE_OP_RESET_FAULTS: {
            server->servo.e_stop_latched = false;
            resp_header.status = PELLICLE_STATUS_OK;
            resp_header.payload_len = 0;
            send(client_fd, &resp_header, sizeof(resp_header), 0);
            break;
        }
        case PELLICLE_OP_SHUTDOWN: {
            server->is_running = false;
            resp_header.status = PELLICLE_STATUS_OK;
            resp_header.payload_len = 0;
            send(client_fd, &resp_header, sizeof(resp_header), 0);
            break;
        }
        default: {
            resp_header.status = PELLICLE_ERR_UNKNOWN_OPCODE;
            resp_header.payload_len = 0;
            send(client_fd, &resp_header, sizeof(resp_header), 0);
            break;
        }
    }
}

int fastpath_ipc_server_poll(fastpath_server_t *server) {
    if (!server || server->server_fd < 0) return -1;
    
    struct sockaddr_un client_addr;
    socklen_t client_len = sizeof(client_addr);
    int client_fd = accept(server->server_fd, (struct sockaddr *)&client_addr, &client_len);
    
    if (client_fd >= 0) {
        handle_client_request(server, client_fd);
        close(client_fd);
        return 1;
    }
    
    /* Progress servo simulation step */
    fastpath_servo_step(&server->servo,
                        &server->target_pose,
                        &server->target_velocity,
                        &server->actual_pose,
                        &server->commanded_wrench);
                        
    fastpath_kinematics_allocate_currents(&server->commanded_wrench, &server->actuator_state);
    
    /* Simulate actual pose following with low-pass inertia */
    double inertia = 0.05;
    server->actual_pose.x_mm += (server->target_pose.x_mm - server->actual_pose.x_mm) * inertia;
    server->actual_pose.y_mm += (server->target_pose.y_mm - server->actual_pose.y_mm) * inertia;
    server->actual_pose.z_mm += (server->target_pose.z_mm - server->actual_pose.z_mm) * inertia;
    
    return 0;
}

void fastpath_ipc_server_close(fastpath_server_t *server) {
    if (!server) return;
    if (server->server_fd >= 0) {
        close(server->server_fd);
        server->server_fd = -1;
    }
    unlink(server->socket_path);
    server->is_running = false;
}
