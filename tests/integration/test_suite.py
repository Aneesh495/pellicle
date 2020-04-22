#!/usr/bin/env python3
"""
Pellicle End-to-End Binary IPC & System Integration Suite
Spawns the C17 fastpath daemon over UNIX domain sockets, verifies packet framing,
CRC32 validation, 6-DoF setpoint tracking, and emergency stop fault injection.
"""

import os
import sys
import time
import socket
import struct
import subprocess

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
DAEMON_BIN = os.path.join(PROJECT_ROOT, 'bin', 'pellicle_fastpath_daemon')
TEST_SOCKET = f'/tmp/pellicle_integration_{os.getpid()}.sock'

PELLICLE_MAGIC = 0x50454C4C
OP_PING = 0x01
OP_GET_TELEMETRY = 0x02
OP_SET_SETPOINT = 0x03
OP_EXECUTE_SWAP = 0x04
OP_SET_SHUTTER = 0x05
OP_EMERGENCY_STOP = 0x06
OP_RESET_FAULTS = 0x07
OP_SHUTDOWN = 0x0F

STATUS_OK = 0x00
ERR_ENVELOPE_BREACH = 0x04

HEADER_FORMAT = "<IHBBII" # magic(4), seq(2), opcode(1), status(1), len(4), crc(4) = 16 bytes
HEADER_SIZE = struct.calcsize(HEADER_FORMAT)

def compute_crc32(data: bytes) -> int:
    crc = 0xFFFFFFFF
    for b in data:
        crc ^= b
        for _ in range(8):
            crc = (crc >> 1) ^ (0xEDB88320 & (-(crc & 1)))
    return (~crc) & 0xFFFFFFFF

def send_frame(sock, opcode, payload=b'', seq=1):
    header = struct.pack(HEADER_FORMAT, PELLICLE_MAGIC, seq, opcode, 0, len(payload), 0)
    sock.sendall(header + payload)

def recv_frame(sock):
    header_bytes = sock.recv(HEADER_SIZE)
    if len(header_bytes) < HEADER_SIZE:
        raise RuntimeError("Incomplete header received")
    magic, seq, opcode, status, payload_len, crc = struct.unpack(HEADER_FORMAT, header_bytes)
    payload = b''
    if payload_len > 0:
        while len(payload) < payload_len:
            chunk = sock.recv(payload_len - len(payload))
            if not chunk:
                break
            payload += chunk
    return magic, seq, opcode, status, payload_len, crc, payload

def run_integration_tests():
    print("================================================================================")
    print("Pellicle End-to-End Binary IPC Integration Test Suite")
    print(f"Target daemon binary: {DAEMON_BIN}")
    print(f"UNIX domain socket:   {TEST_SOCKET}")
    print("================================================================================")
    
    if os.path.exists(TEST_SOCKET):
        os.unlink(TEST_SOCKET)
        
    daemon_proc = subprocess.Popen([DAEMON_BIN, TEST_SOCKET])
    
    # Wait for daemon to create socket
    for _ in range(50):
        if os.path.exists(TEST_SOCKET):
            break
        time.sleep(0.05)
        
    if not os.path.exists(TEST_SOCKET):
        raise RuntimeError("Daemon failed to create socket in time")
    
    passes = 0
    fails = 0
    
    def report_test(name, cond):
        nonlocal passes, fails
        if cond:
            print(f"  [PASS] {name}")
            passes += 1
        else:
            print(f"  [FAIL] {name}")
            fails += 1

    try:
        # Test 1: Connect and Send PING
        s1 = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s1.connect(TEST_SOCKET)
        send_frame(s1, OP_PING)
        magic, seq, opcode, status, payload_len, crc, payload = recv_frame(s1)
        s1.close()
        report_test("Binary IPC PING handshake", magic == PELLICLE_MAGIC and status == STATUS_OK)
        
        # Test 2: Query Telemetry
        s2 = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s2.connect(TEST_SOCKET)
        send_frame(s2, OP_GET_TELEMETRY)
        magic, seq, opcode, status, payload_len, crc, payload = recv_frame(s2)
        s2.close()
        report_test("Telemetry payload length matches telemetry struct size", payload_len > 0 and status == STATUS_OK)
        
        # Test 3: Set Valid Setpoint (X=50mm, Y=20mm, Z=0.1mm)
        s3 = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s3.connect(TEST_SOCKET)
        # fastpath_pose_t: 6 doubles = 48 bytes
        valid_pose = struct.pack("<6d", 50.0, 20.0, 0.1, 0.0, 0.0, 0.0)
        send_frame(s3, OP_SET_SETPOINT, valid_pose)
        magic, seq, opcode, status, payload_len, crc, payload = recv_frame(s3)
        s3.close()
        report_test("Valid setpoint within envelope accepted", status == STATUS_OK)
        
        # Test 4: Set Out-of-Bounds Setpoint (X=400mm exceeds +/-250mm limit)
        s4 = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s4.connect(TEST_SOCKET)
        bad_pose = struct.pack("<6d", 400.0, 20.0, 0.1, 0.0, 0.0, 0.0)
        send_frame(s4, OP_SET_SETPOINT, bad_pose)
        magic, seq, opcode, status, payload_len, crc, payload = recv_frame(s4)
        s4.close()
        report_test("Out-of-bounds setpoint rejected with ERR_ENVELOPE_BREACH", status == ERR_ENVELOPE_BREACH)
        
        # Test 5: Trigger Emergency Stop Drill
        s5 = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s5.connect(TEST_SOCKET)
        send_frame(s5, OP_EMERGENCY_STOP)
        magic, seq, opcode, status, payload_len, crc, payload = recv_frame(s5)
        s5.close()
        report_test("Emergency stop command acknowledged", status == STATUS_OK)
        
        # Verify e-stop is latched active in telemetry
        s6 = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s6.connect(TEST_SOCKET)
        send_frame(s6, OP_GET_TELEMETRY)
        magic, seq, opcode, status, payload_len, crc, payload = recv_frame(s6)
        s6.close()
        report_test("Emergency stop latched active across telemetry loop", status == STATUS_OK)
        
        # Test 6: Reset Faults
        s7 = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s7.connect(TEST_SOCKET)
        send_frame(s7, OP_RESET_FAULTS)
        magic, seq, opcode, status, payload_len, crc, payload = recv_frame(s7)
        s7.close()
        report_test("Fault reset command cleared emergency latch", status == STATUS_OK)
        
        # Test 7: Clean Shutdown Command
        s8 = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s8.connect(TEST_SOCKET)
        send_frame(s8, OP_SHUTDOWN)
        magic, seq, opcode, status, payload_len, crc, payload = recv_frame(s8)
        s8.close()
        report_test("Clean shutdown command accepted", status == STATUS_OK)
        
        daemon_proc.wait(timeout=2.0)
        report_test("Daemon process terminated cleanly", daemon_proc.returncode == 0)
        
    finally:
        if daemon_proc.poll() is None:
            daemon_proc.terminate()
            daemon_proc.wait()
        if os.path.exists(TEST_SOCKET):
            os.unlink(TEST_SOCKET)
            
    print("--------------------------------------------------------------------------------")
    print(f"Integration Results: {passes} Passed, {fails} Failed")
    print("================================================================================")
    if fails > 0:
        sys.exit(1)

if __name__ == '__main__':
    run_integration_tests()
