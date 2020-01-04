module Pellicle.Kinematics.DualStageSwap

import Pellicle.Core.Types
import Pellicle.Kinematics.DegreesOfFreedom

%default total

||| Physical center position of the measurement and alignment station (Y in mm)
public export
MEASURE_STATION_Y_MM : Double
MEASURE_STATION_Y_MM = -180.0

||| Physical center position of the exposure projection lens station (Y in mm)
public export
EXPOSURE_STATION_Y_MM : Double
EXPOSURE_STATION_Y_MM = 180.0

||| Width of the exposure station safety zone in mm
public export
EXPOSURE_ZONE_RADIUS_MM : Double
EXPOSURE_ZONE_RADIUS_MM = 60.0

||| State of the dual-stage system
public export
record DualChuckState where
  constructor MkDualChuckState
  chuck1State : ChuckState
  chuck2State : ChuckState
  chuck1Pose : Pose6DoF
  chuck2Pose : Pose6DoF
  shutter : ShutterState

public export
Show DualChuckState where
  show (MkDualChuckState s1 s2 p1 p2 sh) =
    "DualChuckState[C1: " ++ show s1 ++ " at Y=" ++ show p1.yMm ++ "mm, " ++
    "C2: " ++ show s2 ++ " at Y=" ++ show p2.yMm ++ "mm, Shutter: " ++ show sh ++ "]"

||| Compute horizontal center-to-center planar clearance distance between chucks in mm
public export
chuckSeparationDistance : Pose6DoF -> Pose6DoF -> Double
chuckSeparationDistance p1 p2 =
  let dx = p2.xMm - p1.xMm
      dy = p2.yMm - p1.yMm
  in sqrt (dx * dx + dy * dy)

||| Invariant predicate: chucks maintain minimum physical clearance
public export
isClearanceMaintained : Pose6DoF -> Pose6DoF -> Bool
isClearanceMaintained p1 p2 =
  chuckSeparationDistance p1 p2 >= MIN_CHUCK_CLEARANCE_MM

||| Check whether a chuck pose falls within the exposure station boundary
public export
isInExposureStation : Pose6DoF -> Bool
isInExposureStation pose =
  abs (pose.yMm - EXPOSURE_STATION_Y_MM) <= EXPOSURE_ZONE_RADIUS_MM

||| Invariant predicate: at most one chuck may occupy the exposure station at any instant
public export
isExposureMutualExclusionSatisfied : Pose6DoF -> Pose6DoF -> Bool
isExposureMutualExclusionSatisfied p1 p2 =
  not (isInExposureStation p1 && isInExposureStation p2)

||| Invariant predicate: laser shutter may ONLY be open if exactly one chuck is in ChuckExposing state
public export
isShutterInterlockSafe : DualChuckState -> Bool
isShutterInterlockSafe state =
  case state.shutter of
    ShutterClosed => True
    ShutterOpen =>
      -- Shutter may only be open if one chuck is in ChuckExposing and positioned under lens
      (state.chuck1State == ChuckExposing && isInExposureStation state.chuck1Pose && state.chuck2State /= ChuckExposing) ||
      (state.chuck2State == ChuckExposing && isInExposureStation state.chuck2Pose && state.chuck1State /= ChuckExposing)

||| Overall system safety audit: all physical and operational invariants hold simultaneously
public export
isDualStageSystemSafe : DualChuckState -> Bool
isDualStageSystemSafe state =
  isClearanceMaintained state.chuck1Pose state.chuck2Pose &&
  isExposureMutualExclusionSatisfied state.chuck1Pose state.chuck2Pose &&
  isShutterInterlockSafe state

||| Swap path waypoint generator for Chuck 1 (from Measure to Exposure)
||| Routes Chuck 1 via the left bypass corridor (X = -80 mm)
public export
chuck1SwapWaypoint : (tau : Double) -> Pose6DoF
chuck1SwapWaypoint tau =
  let t = if tau < 0.0 then 0.0 else if tau > 1.0 then 1.0 else tau
      y = MEASURE_STATION_Y_MM + t * (EXPOSURE_STATION_Y_MM - MEASURE_STATION_Y_MM)
      x = -80.0 * sin (t * 3.141592653589793)
  in MkPose6DoF x y 0.0 0.0 0.0 0.0

||| Swap path waypoint generator for Chuck 2 (from Exposure to Measure)
||| Routes Chuck 2 via the right bypass corridor (X = +80 mm)
public export
chuck2SwapWaypoint : (tau : Double) -> Pose6DoF
chuck2SwapWaypoint tau =
  let t = if tau < 0.0 then 0.0 else if tau > 1.0 then 1.0 else tau
      y = EXPOSURE_STATION_Y_MM - t * (EXPOSURE_STATION_Y_MM - MEASURE_STATION_Y_MM)
      x = 80.0 * sin (t * 3.141592653589793)
  in MkPose6DoF x y 0.0 0.0 0.0 0.0

||| Verify that the planned swap path maintains minimum clearance for all tau in [0, 1]
public export
verifySwapPathSafety : (numSteps : Nat) -> Bool
verifySwapPathSafety steps =
  let n = cast steps
      dt = 1.0 / n
      indices = [0 .. cast steps]
  in foldl (\acc, i =>
       let tau = cast i * dt
           p1 = chuck1SwapWaypoint tau
           p2 = chuck2SwapWaypoint tau
       in acc && isClearanceMaintained p1 p2) True indices
