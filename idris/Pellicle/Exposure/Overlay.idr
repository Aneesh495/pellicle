module Pellicle.Exposure.Overlay

import Pellicle.Core.Types
import Pellicle.Core.Bounded

%default total

||| Slit moving average window metrics
public export
record SlitOverlayMetrics where
  constructor MkSlitOverlayMetrics
  dmaErrorNm : Double
  msdJitterNm : Double
  peakErrorNm : Double
  isWithinDmaLimit : Bool
  isWithinMsdLimit : Bool

public export
Show SlitOverlayMetrics where
  show (MkSlitOverlayMetrics dma msd peak okDma okMsd) =
    "OverlayMetrics[DMA=" ++ show dma ++ "nm (ok=" ++ show okDma ++ "), " ++
    "MSD=" ++ show msd ++ "nm (ok=" ++ show okMsd ++ "), Peak=" ++ show peak ++ "nm]"

||| Compute Dynamic Moving Average (DMA) across a window of error samples (in nm)
public export
computeDMA : List Double -> Double
computeDMA [] = 0.0
computeDMA samples =
  let sumErr = foldl (+) 0.0 samples
      n = cast (length samples)
  in sumErr / n

||| Compute Moving Standard Deviation (MSD) across a window of error samples (in nm)
public export
computeMSD : List Double -> Double -> Double
computeMSD [] _ = 0.0
computeMSD samples dma =
  let sumSqDiff = foldl (\acc, e => let diff = e - dma in acc + diff * diff) 0.0 samples
      n = cast (length samples)
  in sqrt (sumSqDiff / n)

||| Evaluate complete slit overlay metrics from a buffer of tracking errors
public export
evaluateSlitOverlay : List Double -> SlitOverlayMetrics
evaluateSlitOverlay [] = MkSlitOverlayMetrics 0.0 0.0 0.0 True True
evaluateSlitOverlay samples =
  let dma = computeDMA samples
      msd = computeMSD samples dma
      peak = foldl (\acc, e => if abs e > acc then abs e else acc) 0.0 samples
      okDma = abs dma <= MAX_OVERLAY_DMA_NM
      okMsd = msd <= MAX_OVERLAY_MSD_NM
  in MkSlitOverlayMetrics dma msd peak okDma okMsd

||| Hard interlock decision: should the exposure laser pulse fire?
||| Both DMA and MSD must remain strictly within specification
public export
shouldAllowLaserPulse : SlitOverlayMetrics -> Bool
shouldAllowLaserPulse metrics =
  metrics.isWithinDmaLimit && metrics.isWithinMsdLimit
