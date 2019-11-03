module Pellicle.Core.Bounded

import Decidable.Equality
import Pellicle.Core.Types

%default total

||| Evidence that a Double value lies within [lower, upper]
public export
data InRange : (val : Double) -> (lower : Double) -> (upper : Double) -> Type where
  MkInRange : {val, lower, upper : Double} ->
              (inLower : (val >= lower) = True) ->
              (inUpper : (val <= upper) = True) ->
              InRange val lower upper

||| A Double tagged with a proof that it lies within [lower, upper]
public export
record BoundedVal (lower : Double) (upper : Double) where
  constructor MkBoundedVal
  val : Double
  0 inBounds : InRange val lower upper

||| Smart constructor for BoundedVal returning Maybe
public export
mkBoundedVal : (lower : Double) -> (upper : Double) -> (v : Double) -> Maybe (BoundedVal lower upper)
mkBoundedVal lower upper v =
  case decEq (v >= lower) True of
    Yes prfLower =>
      case decEq (v <= upper) True of
        Yes prfUpper => Just (MkBoundedVal v (MkInRange prfLower prfUpper))
        No _ => Nothing
    No _ => Nothing

||| Clamps an unbounded double into the range [lower, upper]
public export
clampDouble : (lower : Double) -> (upper : Double) -> Double -> Double
clampDouble lower upper x =
  if x < lower then lower
  else if x > upper then upper
  else x

||| A stage scanning velocity guaranteed to not exceed MAX_STAGE_VELOCITY_MPS
public export
record StageVelocity where
  constructor MkStageVelocity
  velocityVal : Double
  0 boundProof : InRange velocityVal (-MAX_STAGE_VELOCITY_MPS) MAX_STAGE_VELOCITY_MPS

public export
mkStageVelocity : Double -> Maybe StageVelocity
mkStageVelocity v =
  case mkBoundedVal (-MAX_STAGE_VELOCITY_MPS) MAX_STAGE_VELOCITY_MPS v of
    Just (MkBoundedVal val prf) => Just (MkStageVelocity val prf)
    Nothing => Nothing

||| A stage acceleration guaranteed to not exceed MAX_STAGE_ACCEL_MPSS
public export
record StageAccel where
  constructor MkStageAccel
  accelVal : Double
  0 boundProof : InRange accelVal (-MAX_STAGE_ACCEL_MPSS) MAX_STAGE_ACCEL_MPSS

public export
mkStageAccel : Double -> Maybe StageAccel
mkStageAccel a =
  case mkBoundedVal (-MAX_STAGE_ACCEL_MPSS) MAX_STAGE_ACCEL_MPSS a of
    Just (MkBoundedVal val prf) => Just (MkStageAccel val prf)
    Nothing => Nothing

||| A stage jerk guaranteed to not exceed MAX_STAGE_JERK_MPS3
public export
record StageJerk where
  constructor MkStageJerk
  jerkVal : Double
  0 boundProof : InRange jerkVal (-MAX_STAGE_JERK_MPS3) MAX_STAGE_JERK_MPS3

public export
mkStageJerk : Double -> Maybe StageJerk
mkStageJerk j =
  case mkBoundedVal (-MAX_STAGE_JERK_MPS3) MAX_STAGE_JERK_MPS3 j of
    Just (MkBoundedVal val prf) => Just (MkStageJerk val prf)
    Nothing => Nothing

||| Dynamic moving average overlay error verified within MAX_OVERLAY_DMA_NM
public export
record ValidOverlayDMA where
  constructor MkValidOverlayDMA
  dmaErrorNm : Double
  0 boundProof : InRange dmaErrorNm 0.0 MAX_OVERLAY_DMA_NM

public export
mkValidOverlayDMA : Double -> Maybe ValidOverlayDMA
mkValidOverlayDMA err =
  case mkBoundedVal 0.0 MAX_OVERLAY_DMA_NM err of
    Just (MkBoundedVal val prf) => Just (MkValidOverlayDMA val prf)
    Nothing => Nothing

||| Wafer radial boundary proof: radius <= 150.0 mm
public export
record WaferRadialPosition where
  constructor MkWaferRadialPosition
  radiusMm : Double
  0 boundProof : InRange radiusMm 0.0 (WAFER_DIAMETER_MM / 2.0)

public export
mkWaferRadialPosition : Point2D -> Maybe WaferRadialPosition
mkWaferRadialPosition (MkPoint2D x y) =
  let r = sqrt (x * x + y * y)
  in case mkBoundedVal 0.0 (WAFER_DIAMETER_MM / 2.0) r of
       Just (MkBoundedVal val prf) => Just (MkWaferRadialPosition val prf)
       Nothing => Nothing
