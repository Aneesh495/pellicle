module Pellicle.Exposure.ScanSync

import Pellicle.Core.Types

%default total

||| Physical width of the projection optical exposure slit in mm (across scanning direction)
public export
SLIT_WIDTH_MM : Double
SLIT_WIDTH_MM = 26.0

||| Physical height of the projection optical exposure slit in mm (along scanning direction)
public export
SLIT_HEIGHT_MM : Double
SLIT_HEIGHT_MM = 8.0

||| State of the reticle stage scanning relative to wafer stage
public export
record ReticleWaferSyncState where
  constructor MkReticleWaferSyncState
  waferPosMm : Double
  waferVelMps : Double
  reticlePosMm : Double
  reticleVelMps : Double
  syncErrorNm : Double
  isSynchronized : Bool

public export
Show ReticleWaferSyncState where
  show (MkReticleWaferSyncState wp wv rp rv err sync) =
    "SyncState[W_pos=" ++ show wp ++ "mm, W_vel=" ++ show wv ++ "m/s, " ++
    "R_pos=" ++ show rp ++ "mm, R_vel=" ++ show rv ++ "m/s, SyncErr=" ++ show err ++ "nm, Sync=" ++ show sync ++ "]"

||| Compute nominal synchronized reticle target position given wafer position
||| Y_reticle = -4.0 * Y_wafer (due to 4:1 optical inversion reduction)
public export
nominalReticlePosMm : Double -> Double
nominalReticlePosMm waferPosMm =
  -RETICLE_REDUCTION_RATIO * waferPosMm

||| Compute nominal synchronized reticle target velocity given wafer velocity
||| V_reticle = -4.0 * V_wafer
public export
nominalReticleVelMps : Double -> Double
nominalReticleVelMps waferVelMps =
  -RETICLE_REDUCTION_RATIO * waferVelMps

||| Compute exposure transit time for any wafer point traversing through the exposure slit
||| T_exp = slit_height / v_scan
public export
computeSlitTransitTimeSec : (vScanMps : Double) -> Double
computeSlitTransitTimeSec vScanMps =
  let v = abs vScanMps
  in if v < 1.0e-4 then 0.0 else (SLIT_HEIGHT_MM * 1.0e-3) / v

||| Evaluate synchronization error between reticle and wafer stages in nanometers (at wafer scale)
||| e = (Y_wafer + (1.0 / 4.0) * Y_reticle) * 1e6
public export
computeSyncErrorNm : (waferPosMm : Double) -> (reticlePosMm : Double) -> Double
computeSyncErrorNm waferPosMm reticlePosMm =
  let errMm = waferPosMm + (reticlePosMm / RETICLE_REDUCTION_RATIO)
  in errMm * 1.0e6

||| Maximum allowable instantaneous synchronization error to qualify as locked in nm
public export
SYNC_LOCK_THRESHOLD_NM : Double
SYNC_LOCK_THRESHOLD_NM = 2.50

||| Evaluate current reticle-wafer dynamic synchronization lock
public export
checkSyncLock : (waferPosMm : Double) -> (waferVelMps : Double) ->
              (reticlePosMm : Double) -> (reticleVelMps : Double) -> ReticleWaferSyncState
checkSyncLock wp wv rp rv =
  let errNm = computeSyncErrorNm wp rp
      isLocked = abs errNm <= SYNC_LOCK_THRESHOLD_NM && abs wv >= 0.05
  in MkReticleWaferSyncState wp wv rp rv errNm isLocked
