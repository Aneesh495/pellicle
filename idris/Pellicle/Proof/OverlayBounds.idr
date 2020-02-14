module Pellicle.Proof.OverlayBounds

import Decidable.Equality
import Pellicle.Core.Types
import Pellicle.Exposure.Overlay

%default total

||| Formal evidence that laser firing is safe under current slit overlay metrics
public export
data SafeLaserFiring : (metrics : SlitOverlayMetrics) -> Type where
  MkSafeLaserFiring : {metrics : SlitOverlayMetrics} ->
                      (prf : shouldAllowLaserPulse metrics = True) ->
                      SafeLaserFiring metrics

||| Decidable verification of laser pulse firing permission
public export
checkLaserFiringSafety : (m : SlitOverlayMetrics) -> Dec (SafeLaserFiring m)
checkLaserFiringSafety m =
  case decEq (shouldAllowLaserPulse m) True of
    Yes prf => Yes (MkSafeLaserFiring prf)
    No contra => No (\(MkSafeLaserFiring prf) => contra prf)

||| Formally proved theorem: Excessive DMA error strictly prohibits laser firing
public export
excessiveDmaBlocksLaser : (m : SlitOverlayMetrics) -> (dmaPrf : m.isWithinDmaLimit = False) -> SafeLaserFiring m -> Void
excessiveDmaBlocksLaser (MkSlitOverlayMetrics _ _ _ False _) Refl (MkSafeLaserFiring prf) =
  case prf of {}

||| Formally proved theorem: Excessive MSD jitter strictly prohibits laser firing
public export
excessiveMsdBlocksLaser : (m : SlitOverlayMetrics) -> (msdPrf : m.isWithinMsdLimit = False) -> SafeLaserFiring m -> Void
excessiveMsdBlocksLaser (MkSlitOverlayMetrics _ _ _ True False) Refl (MkSafeLaserFiring prf) =
  case prf of {}
excessiveMsdBlocksLaser (MkSlitOverlayMetrics _ _ _ False False) Refl (MkSafeLaserFiring prf) =
  case prf of {}

||| Proved witness for nominal overlay metrics
public export
nominalOverlayPermitsFiring : SafeLaserFiring (MkSlitOverlayMetrics 0.5 0.8 1.0 True True)
nominalOverlayPermitsFiring = MkSafeLaserFiring Refl
