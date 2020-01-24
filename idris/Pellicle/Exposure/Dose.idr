module Pellicle.Exposure.Dose

import Pellicle.Core.Types

%default total

||| Laser pulse repetition frequency in Hertz (typically 4000 to 6000 Hz)
public export
LASER_REP_RATE_HZ : Double
LASER_REP_RATE_HZ = 6000.0

||| Optical transmission efficiency of the projection lens column
public export
OPTICAL_TRANSMISSION : Double
OPTICAL_TRANSMISSION = 0.85

||| Dose control state of the scanner illuminator
public export
record DoseControlState where
  constructor MkDoseControlState
  targetDoseMilliJoulePerCm2 : Double
  accumulatedDoseMilliJoulePerCm2 : Double
  pulseCount : Int
  attenuatorAngleDeg : Double
  lastPulseEnergyMilliJoule : Double
  doseErrorPct : Double

public export
Show DoseControlState where
  show (MkDoseControlState target accum pulses att lastE err) =
    "DoseState[Target=" ++ show target ++ "mJ/cm2, Accum=" ++ show accum ++ "mJ/cm2, " ++
    "Pulses=" ++ show pulses ++ ", Attenuator=" ++ show att ++ "deg, Error=" ++ show err ++ "%]"

||| Initial dose control state for an unexposed die field
public export
initDoseState : (targetDose : Double) -> DoseControlState
initDoseState target =
  MkDoseControlState target 0.0 0 45.0 10.0 0.0

||| Compute effective illuminated slit area in cm^2 at the wafer plane
||| SLIT_WIDTH_MM * SLIT_HEIGHT_MM converted to cm^2
public export
slitAreaCm2 : Double
slitAreaCm2 = (26.0 / 10.0) * (8.0 / 10.0)

||| Compute dose increment per pulse given pulse energy in mJ and scan velocity
public export
pulseDoseIncrement : (pulseEnergyMilliJoule : Double) -> (vScanMps : Double) -> Double
pulseDoseIncrement pulseEnergy vScan =
  let v = if abs vScan < 0.001 then 0.001 else abs vScan
      -- Area illuminated per unit time is slit_width_cm * v_scan_cm_s
      widthCm = 2.6
      vCmS = v * 100.0
      areaRate = widthCm * vCmS
      deliveredEnergy = pulseEnergy * OPTICAL_TRANSMISSION
  in deliveredEnergy / (areaRate * (1.0 / LASER_REP_RATE_HZ))

||| Integrate a single laser pulse into the dose control loop
public export
integratePulse : DoseControlState -> (pulseEnergyMilliJoule : Double) -> (vScanMps : Double) -> DoseControlState
integratePulse state pulseEnergy vScan =
  let doseInc = pulseDoseIncrement pulseEnergy vScan
      newAccum = state.accumulatedDoseMilliJoulePerCm2 + doseInc
      newPulses = state.pulseCount + 1
      errPct = if state.targetDoseMilliJoulePerCm2 > 0.0
                 then ((newAccum - state.targetDoseMilliJoulePerCm2) / state.targetDoseMilliJoulePerCm2) * 100.0
                 else 0.0
      -- Proportional attenuator trimming
      deltaAtt = if errPct > 0.1 then 0.1 else if errPct < -0.1 then -0.1 else 0.0
      newAtt = state.attenuatorAngleDeg + deltaAtt
  in MkDoseControlState state.targetDoseMilliJoulePerCm2 newAccum newPulses newAtt pulseEnergy errPct

||| Check whether final delivered dose is within acceptable lithographic margin (+/- 0.5%)
public export
isDoseWithinTolerance : DoseControlState -> Bool
isDoseWithinTolerance state =
  abs state.doseErrorPct <= 0.50
