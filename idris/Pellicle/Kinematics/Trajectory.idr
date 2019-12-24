module Pellicle.Kinematics.Trajectory

import Pellicle.Core.Types
import Pellicle.Core.Bounded
import Pellicle.Kinematics.DegreesOfFreedom

%default total

||| Trajectory point state at time t
public export
record TrajectoryPoint where
  constructor MkTrajectoryPoint
  timeSec : Double
  positionMm : Double
  velocityMps : Double
  accelMpss : Double
  jerkMps3 : Double

public export
Show TrajectoryPoint where
  show (MkTrajectoryPoint t s v a j) =
    "t=" ++ show t ++ "s: pos=" ++ show s ++ "mm, vel=" ++ show v ++ "m/s, accel=" ++ show a ++ "m/s^2, jerk=" ++ show j ++ "m/s^3"

||| Normalized 7th-order polynomial: P(tau) = 35*tau^4 - 84*tau^5 + 70*tau^6 - 20*tau^7
||| Guarantees C^3 continuity: P'(0)=P''(0)=P'''(0) = P'(1)=P''(1)=P'''(1) = 0
public export
poly7Pos : Double -> Double
poly7Pos tau =
  if tau <= 0.0 then 0.0
  else if tau >= 1.0 then 1.0
  else
    let tau2 = tau * tau
        tau4 = tau2 * tau2
        tau5 = tau4 * tau
        tau6 = tau5 * tau
        tau7 = tau6 * tau
    in 35.0 * tau4 - 84.0 * tau5 + 70.0 * tau6 - 20.0 * tau7

||| Normalized first derivative: P'(tau) = 140*tau^3 - 420*tau^4 + 420*tau^5 - 140*tau^6
public export
poly7Vel : Double -> Double
poly7Vel tau =
  if tau <= 0.0 || tau >= 1.0 then 0.0
  else
    let tau2 = tau * tau
        tau3 = tau2 * tau
        tau4 = tau3 * tau
        tau5 = tau4 * tau
        tau6 = tau5 * tau
    in 140.0 * tau3 - 420.0 * tau4 + 420.0 * tau5 - 140.0 * tau6

||| Normalized second derivative: P''(tau) = 420*tau^2 - 1680*tau^3 + 2100*tau^4 - 840*tau^5
public export
poly7Accel : Double -> Double
poly7Accel tau =
  if tau <= 0.0 || tau >= 1.0 then 0.0
  else
    let tau2 = tau * tau
        tau3 = tau2 * tau
        tau4 = tau3 * tau
        tau5 = tau4 * tau
    in 420.0 * tau2 - 1680.0 * tau3 + 2100.0 * tau4 - 840.0 * tau5

||| Normalized third derivative (jerk): P'''(tau) = 840*tau - 5040*tau^2 + 8400*tau^3 - 4200*tau^4
public export
poly7Jerk : Double -> Double
poly7Jerk tau =
  if tau <= 0.0 || tau >= 1.0 then 0.0
  else
    let tau2 = tau * tau
        tau3 = tau2 * tau
        tau4 = tau3 * tau
    in 840.0 * tau - 5040.0 * tau2 + 8400.0 * tau3 - 4200.0 * tau4

||| Calculate minimum required move duration T (in seconds) to respect velocity, acceleration, and jerk limits
public export
calculateMinimumDuration : (distMm : Double) -> Double
calculateMinimumDuration distMm =
  let deltaM = abs distMm * 1.0e-3
      -- Peak coefficients for 7th-order polynomial
      peakVelCoeff = 2.1875
      peakAccelCoeff = 5.7735
      peakJerkCoeff = 13.125
      tVel = (peakVelCoeff * deltaM) / MAX_STAGE_VELOCITY_MPS
      tAccel = sqrt ((peakAccelCoeff * deltaM) / MAX_STAGE_ACCEL_MPSS)
      tJerk = exp ((log ((peakJerkCoeff * deltaM) / MAX_STAGE_JERK_MPS3)) / 3.0)
      tMin = if tVel > tAccel then tVel else tAccel
      tFinal = if tJerk > tMin then tJerk else tMin
  in if tFinal < 0.005 then 0.005 else tFinal

||| Evaluates trajectory state at time tSec given start position, end position, and move duration
public export
sampleTrajectory : (s0Mm : Double) -> (s1Mm : Double) -> (durationSec : Double) -> (tSec : Double) -> TrajectoryPoint
sampleTrajectory s0 s1 duration t =
  let deltaMm = s1 - s0
      deltaM = deltaMm * 1.0e-3
      tau = if duration <= 0.0 then 1.0 else t / duration
      sNorm = poly7Pos tau
      vNorm = poly7Vel tau
      aNorm = poly7Accel tau
      jNorm = poly7Jerk tau
      pos = s0 + deltaMm * sNorm
      vel = (deltaM / duration) * vNorm
      accel = (deltaM / (duration * duration)) * aNorm
      jerk = (deltaM / (duration * duration * duration)) * jNorm
  in MkTrajectoryPoint t pos vel accel jerk

||| Discretize full trajectory into N equal time steps
public export
discretizeTrajectory : (s0Mm : Double) -> (s1Mm : Double) -> (durationSec : Double) -> (steps : Nat) -> List TrajectoryPoint
discretizeTrajectory s0 s1 duration steps =
  let numSteps = cast steps
      dt = if numSteps == 0.0 then duration else duration / numSteps
      indices = [0 .. cast steps]
  in map (\i => sampleTrajectory s0 s1 duration (cast i * dt)) indices
