module Pellicle.Proof.LinearResources

import Pellicle.Core.Types

%default total

||| Linear hardware capability governing the physical laser optical shutter
||| Multiplicity 1 guarantees no aliasing, no double-firing, and no unclosed leaks
public export
data ShutterCapability : ShutterState -> Type where
  MkShutterCapability : ShutterCapability s

||| Acquire a closed shutter capability at startup
public export
acquireShutter : (1 p : (1 _ : ShutterCapability ShutterClosed) -> a) -> a
acquireShutter p = p MkShutterCapability

||| Open the physical laser shutter (consumes closed capability, yields open capability)
public export
openShutter : (1 s : ShutterCapability ShutterClosed) -> ShutterCapability ShutterOpen
openShutter MkShutterCapability = MkShutterCapability

||| Close the physical laser shutter (consumes open capability, yields closed capability)
public export
closeShutter : (1 s : ShutterCapability ShutterOpen) -> ShutterCapability ShutterClosed
closeShutter MkShutterCapability = MkShutterCapability

||| Release and power down the shutter capability (ONLY permitted when shutter is closed)
||| Attempting to release an open shutter is a compile-time type error
public export
releaseShutter : (1 s : ShutterCapability ShutterClosed) -> ()
releaseShutter MkShutterCapability = ()

||| Linear hardware handle governing wafer chuck vacuum clamp
||| Bool parameter: True = vacuum engaged, False = vented
public export
data ChuckVacuumHandle : ChuckId -> Bool -> Type where
  MkChuckVacuumHandle : (cid : ChuckId) -> ChuckVacuumHandle cid isEngaged

||| Engage vacuum clamp on the wafer chuck (consumes vented handle, yields clamped handle)
public export
engageVacuum : {cid : ChuckId} -> (1 h : ChuckVacuumHandle cid False) -> ChuckVacuumHandle cid True
engageVacuum (MkChuckVacuumHandle cid) = MkChuckVacuumHandle cid

||| Vent and release vacuum clamp on the wafer chuck (consumes clamped handle, yields vented handle)
public export
ventVacuum : {cid : ChuckId} -> (1 h : ChuckVacuumHandle cid True) -> ChuckVacuumHandle cid False
ventVacuum (MkChuckVacuumHandle cid) = MkChuckVacuumHandle cid

||| Dispose of vacuum handle (ONLY permitted when vacuum is safely vented)
public export
disposeVacuumHandle : {cid : ChuckId} -> (1 h : ChuckVacuumHandle cid False) -> ()
disposeVacuumHandle (MkChuckVacuumHandle _) = ()
