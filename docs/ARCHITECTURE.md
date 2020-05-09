# Pellicle System Architecture Specification

## 1. Architectural Topology

Pellicle is architected as a dual-engine control system designed to meet the rigorous safety and real-time execution constraints of semiconductor photolithography wafer scanners. The architecture decouples formal safety proofs and high-level trajectory planning (implemented in Idris 2) from high-frequency numerical servo execution and hardware interface routines (implemented in ISO C17).

```mermaid
flowchart TD
    subgraph Host_Layer ["Host Supervision & Operator Cockpit"]
        CTL["pelliclectl CLI & Operator Console"]
        LOT["Lot Recipe Manager & Die Scheduler"]
        VIZ["300mm Wafer Topography Visualizer"]
    end

    subgraph Idris_Kernel ["Idris 2 Safety-Critical Kernel"]
        SM["Chuck 1 & 2 State Machines"]
        PROOFS["Inductive Safety Proofs & Interlocks"]
        TRAJ["7th-Order Jerk-Continuous Trajectory Planner"]
        LEVEL["Least-Squares Topography Leveling"]
        QTT["QTT Linear Hardware Capability Manager"]
    end

    subgraph Fastpath_C17 ["C17 Hard Real-Time Fastpath (20 kHz)"]
        IPC["UNIX Domain Socket Binary Server"]
        INTERF["SIMD Quadrature Phase Unwrapping"]
        EDLEN["Dynamic Atmospheric Index Engine"]
        SERVO["Discrete Digital PID & Notch Filters"]
        DECOUPLE["Lorentz Force Current Allocation Matrix"]
    end

    subgraph Physical_Hardware ["TwinScan Physical Stage Hardware"]
        CHUCK1["Chuck 1: 6-DoF Maglev Wafer Stage"]
        CHUCK2["Chuck 2: 6-DoF Maglev Wafer Stage"]
        RETICLE["4:1 Optical Reduction Reticle Stage"]
        LASER["DUV/EUV Pulsed Laser Source (6 kHz)"]
        HENE["Heterodyne Laser Interferometer Array"]
    end

    CTL --> LOT
    LOT --> SM
    SM --> PROOFS
    SM --> TRAJ
    TRAJ --> QTT
    QTT --> IPC

    IPC --> SERVO
    SERVO --> DECOUPLE
    DECOUPLE --> CHUCK1
    DECOUPLE --> CHUCK2
    DECOUPLE --> RETICLE

    HENE --> INTERF
    INTERF --> EDLEN
    EDLEN --> SERVO

    LASER --> PROOFS
    CHUCK2 --> PROOFS
    RETICLE --> PROOFS
```

## 2. Dual-Engine Concurrency Model

### 2.1 The 20 kHz Discrete Servo Fastpath
The C17 fastpath engine executes a synchronous hard real-time loop paced at exactly 50 microseconds (20 kHz). Within each 50-microsecond cycle deadline, the fastpath executes:
1. Optical receiver quadrature I/Q signal sampling.
2. Phase unwrapping and fringe counting.
3. Edlen air refractive index scaling.
4. 6-DoF stage coordinate triangulation.
5. Error calculation against current trajectory setpoint.
6. PID feedback, velocity feedforward, and dual biquad notch filtering.
7. Planar motor Lorentz coil current allocation.
8. Thermal dissipation monitoring.

### 2.2 Idris 2 Safety Supervisor
The Idris 2 kernel supervises operational stage modes, validates exposure recipes, guarantees collision-free stage swap trajectories, and enforces physical interlocks.

```mermaid
sequenceDiagram
    participant Host as Host Operator
    participant Idris as Idris 2 Safety Kernel
    participant Fastpath as C17 Fastpath (20 kHz)
    participant Chucks as TwinScan Dual Chucks

    Host->>Idris: Load 7nm Logic Recipe (57 Dies)
    Idris->>Idris: Fit 64-Point Leveling Plane
    Idris->>Idris: Verify Leveling <= 120 nm DoF
    Idris->>Idris: Compute 7th-Order Swap Trajectory
    Idris->>Idris: Inductive Proof: Clearance >= 15 mm
    Idris->>Fastpath: OP_SET_SETPOINT (Swap Waypoints)
    Fastpath->>Chucks: Execute 20 kHz Magnetic Levitation
    Chucks-->>Fastpath: Laser Interferometer Feedback
    Fastpath-->>Idris: OP_GET_TELEMETRY (Overlay DMA & MSD)
    Idris->>Idris: Verify DMA <= 1.20 nm & MSD <= 1.80 nm
    Idris->>Fastpath: OP_SET_SHUTTER (Open for Slit Scan)
    Fastpath->>Chucks: Pulsed Laser Exposure Pulse
```

## 3. Binary IPC Wire Protocol

Communication between the safety supervisor and the C17 fastpath is mediated by non-blocking UNIX domain stream sockets using a fixed-layout, zero-copy binary wire protocol:

```text
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                      Magic: 0x50454C4C ("PELL")               |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|         Sequence ID           |    Opcode     |    Status     |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                        Payload Length                         |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                        Payload CRC-32                         |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                                                               |
|                   Variable Payload Data ...                   |
|                                                               |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

### Protocol Opcode Specifications
- `0x01 PELLICLE_OP_PING`: Zero-payload round-trip heartbeat verification.
- `0x02 PELLICLE_OP_GET_TELEMETRY`: Queries 6-DoF pose, velocity, commanded wrench, 8 coil currents, Ohmic dissipation, overlay DMA/MSD, and fault states.
- `0x03 PELLICLE_OP_SET_SETPOINT`: Commands target 6-DoF setpoint. Verified against physical travel envelope before execution.
- `0x04 PELLICLE_OP_EXECUTE_SWAP`: Initiates synchronized dual-chuck swap trajectory.
- `0x05 PELLICLE_OP_SET_SHUTTER`: Commands optical laser shutter state. Hardware-interlocked against overlay tracking errors.
- `0x06 PELLICLE_OP_EMERGENCY_STOP`: Latches immediate fail-safe shutdown: shuts off laser and zeros actuator current.
- `0x07 PELLICLE_OP_RESET_FAULTS`: Clears latched safety alarms after root cause resolution.
- `0x0F PELLICLE_OP_SHUTDOWN`: Clean daemon termination and socket unlink.
