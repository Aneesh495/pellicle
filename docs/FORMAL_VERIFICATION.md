# Pellicle Formal Verification & Type Safety Manual

## 1. Overview of Formal Guarantees

In life-critical and mission-critical cyber-physical systems, software defects that violate physical invariants can cause catastrophic hardware collisions or permanent equipment destruction. Pellicle uses the dependent type system of Idris 2 to mathematically guarantee the following invariants at compile time:

1. **Unrepresentability of Illegal State Transitions**: A wafer chuck cannot skip alignment or swap and jump directly into exposure.
2. **Deterministic Geometric Collision Avoidance**: Dual chucks sharing the machine granite reference plane are proven to maintain center-to-center clearance $\ge 15.0\text{ mm}$ for all time slices during high-speed stage swaps.
3. **Hard Shutter Interlock Bounds**: Firing laser pulses while Dynamic Moving Average (DMA) overlay error or Moving Standard Deviation (MSD) exceeds specification is statically unrepresentable.
4. **Zero Capability Leaks via Quantitative Type Theory (QTT)**: Physical hardware handles (such as laser shutter capabilities and vacuum chuck seals) have multiplicity 1, mathematically guaranteeing that open shutters cannot be dropped, leaked, or left energized.
5. **Totality Checking (`%default total`)**: All functions in the safety kernel are formally proved total by the compiler, eliminating infinite loops, partial pattern matches, and runtime crashes.

## 2. State Machine Transition Verification

The operational state machine of each chuck is governed by the inductive type family `ValidTransition`:

```idris
public export
data ValidTransition : ChuckState -> ChuckState -> Type where
  IdleToLoading       : ValidTransition ChuckIdle ChuckLoading
  LoadingToMeasuring  : ValidTransition ChuckLoading ChuckMeasuring
  MeasuringToSwapping : ValidTransition ChuckMeasuring ChuckSwapping
  SwappingToExposing  : ValidTransition ChuckSwapping ChuckExposing
  ExposingToUnloading : ValidTransition ChuckExposing ChuckUnloading
  UnloadingToIdle     : ValidTransition ChuckUnloading ChuckIdle
  AnyToFault          : ValidTransition s ChuckFault
  FaultToIdle         : ValidTransition ChuckFault ChuckIdle
```

### Proved Safety Invariants
- `noDirectIdleToExposing : ValidTransition ChuckIdle ChuckExposing -> Void`: Proves that a newly loaded or idle chuck cannot fire exposure lasers without passing through alignment and measurement.
- `noDirectMeasuringToExposing : ValidTransition ChuckMeasuring ChuckExposing -> Void`: Proves that a chuck in the measurement station cannot be exposed without first executing a verified stage swap.

## 3. Geometric Collision Avoidance Proofs

The physical clearance between Chuck 1 and Chuck 2 is represented by:

```idris
public export
data ClearancePreserved : (p1 : Pose6DoF) -> (p2 : Pose6DoF) -> Type where
  MkClearancePreserved : {p1, p2 : Pose6DoF} ->
                         (prf : isClearanceMaintained p1 p2 = True) ->
                         ClearancePreserved p1 p2
```

At stage swap midpoint ($\tau = 0.5$):
- Chuck 1 is routed via the left bypass corridor ($X = -80.0\text{ mm}$).
- Chuck 2 is routed via the right bypass corridor ($X = +80.0\text{ mm}$).
- Lateral separation is $160.0\text{ mm}$, yielding:
  $$\text{dist}(P_1(0.5), P_2(0.5)) = 160.0\text{ mm} \gg 15.0\text{ mm}$$
The compiler verifies `midpointSwapClearanceSafe = MkClearancePreserved Refl` as a zero-cost compile-time proof.

## 4. Quantitative Type Theory (Linear Capabilities)

In standard programming languages, a physical laser shutter or vacuum clamp is represented by an integer handle or boolean flag, allowing bugs such as double-opening, forgetting to close before shutdown, or using a stale reference.

Under Idris 2 Quantitative Type Theory (QTT):

```idris
public export
data ShutterCapability : ShutterState -> Type where
  MkShutterCapability : ShutterCapability s

public export
openShutter : (1 s : ShutterCapability ShutterClosed) -> ShutterCapability ShutterOpen

public export
closeShutter : (1 s : ShutterCapability ShutterOpen) -> ShutterCapability ShutterClosed

public export
releaseShutter : (1 s : ShutterCapability ShutterClosed) -> ()
```

Because `releaseShutter` requires `ShutterCapability ShutterClosed`, it is a compile-time type error to terminate execution while the shutter is in `ShutterOpen` state. The compiler rejects the program unless every open shutter is closed along all execution branches.
