module Pellicle.Proof.CollisionAvoidance

import Decidable.Equality
import Pellicle.Core.Types
import Pellicle.Kinematics.DegreesOfFreedom
import Pellicle.Kinematics.DualStageSwap

%default total

||| Formal evidence that two chuck poses maintain physical clearance >= 15 mm
public export
data ClearancePreserved : (p1 : Pose6DoF) -> (p2 : Pose6DoF) -> Type where
  MkClearancePreserved : {p1, p2 : Pose6DoF} ->
                         (prf : isClearanceMaintained p1 p2 = True) ->
                         ClearancePreserved p1 p2

||| Decidable verification of physical clearance maintenance between chucks
public export
checkClearance : (p1 : Pose6DoF) -> (p2 : Pose6DoF) -> Dec (ClearancePreserved p1 p2)
checkClearance p1 p2 =
  case decEq (isClearanceMaintained p1 p2) True of
    Yes prf => Yes (MkClearancePreserved prf)
    No contra => No (\(MkClearancePreserved prf) => contra prf)

||| Formal evidence of exposure station mutual exclusion
public export
data ExposureMutualExclusion : (p1 : Pose6DoF) -> (p2 : Pose6DoF) -> Type where
  MkExposureMutualExclusion : {p1, p2 : Pose6DoF} ->
                              (prf : isExposureMutualExclusionSatisfied p1 p2 = True) ->
                              ExposureMutualExclusion p1 p2

||| Decidable verification of exposure station mutual exclusion
public export
checkExposureMutualExclusion : (p1 : Pose6DoF) -> (p2 : Pose6DoF) -> Dec (ExposureMutualExclusion p1 p2)
checkExposureMutualExclusion p1 p2 =
  case decEq (isExposureMutualExclusionSatisfied p1 p2) True of
    Yes prf => Yes (MkExposureMutualExclusion prf)
    No contra => No (\(MkExposureMutualExclusion prf) => contra prf)

||| Formally proved theorem: When Chuck 1 is at Measure and Chuck 2 is at Exposure, clearance is preserved
public export
initialStationsClearanceSafe : ClearancePreserved
  (MkPose6DoF 0.0 MEASURE_STATION_Y_MM 0.0 0.0 0.0 0.0)
  (MkPose6DoF 0.0 EXPOSURE_STATION_Y_MM 0.0 0.0 0.0 0.0)
initialStationsClearanceSafe = MkClearancePreserved Refl

||| Formally proved theorem: At midpoint tau=0.5 of swap path, lateral corridor separation preserves clearance
public export
midpointSwapClearanceSafe : ClearancePreserved (chuck1SwapWaypoint 0.5) (chuck2SwapWaypoint 0.5)
midpointSwapClearanceSafe = MkClearancePreserved Refl
