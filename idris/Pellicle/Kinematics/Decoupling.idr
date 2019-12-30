module Pellicle.Kinematics.Decoupling

import Data.Vect
import Pellicle.Core.Types
import Pellicle.Core.Matrix

%default total

||| Generalized 6-DoF wrench commanded by the feedback/feedforward servo
||| Forces in Newtons, torques in Newton-meters
public export
record Wrench6DoF where
  constructor MkWrench6DoF
  fxN : Double
  fyN : Double
  fzN : Double
  txNm : Double
  tyNm : Double
  tzNm : Double

public export
Show Wrench6DoF where
  show (MkWrench6DoF fx fy fz tx ty tz) =
    "Wrench[Fx=" ++ show fx ++ "N, Fy=" ++ show fy ++ "N, Fz=" ++ show fz ++ "N, " ++
    "Tx=" ++ show tx ++ "Nm, Ty=" ++ show ty ++ "Nm, Tz=" ++ show tz ++ "Nm]"

||| Convert wrench record into a dimension-indexed 6-element vector
public export
wrenchToVect : Wrench6DoF -> Vect 6 Double
wrenchToVect (MkWrench6DoF fx fy fz tx ty tz) =
  [fx, fy, fz, tx, ty, tz]

||| Eight-channel actuator current vector in Amperes
||| Coils 1-4: Planar Lorentz motors (horizontal X, Y, Rz)
||| Coils 5-8: Vertical voice-coil levitation motors (vertical Z, Rx, Ry)
public export
CoilCurrents : Type
CoilCurrents = Vect 8 Double

||| Coil resistance in Ohms
public export
COIL_RESISTANCE_OHMS : Double
COIL_RESISTANCE_OHMS = 2.40

||| Maximum continuous coil current in Amperes
public export
MAX_COIL_CURRENT_A : Double
MAX_COIL_CURRENT_A = 12.0

||| Maximum allowable instantaneous thermal dissipation in Watts
public export
MAX_THERMAL_POWER_W : Double
MAX_THERMAL_POWER_W = 150.0

||| Motor force constant Kf in N/A
public export
LORENTZ_KF_N_PER_A : Double
LORENTZ_KF_N_PER_A = 18.5

||| Lever arm radius of horizontal actuators from chuck center in meters
public export
LEVER_ARM_RADIUS_M : Double
LEVER_ARM_RADIUS_M = 0.160

||| Analytical Moore-Penrose pseudo-inverse allocation matrix mapping 6-DoF wrench to 8 coil currents
||| Returns 8 currents: [I1, I2, I3, I4, I5, I6, I7, I8]
public export
allocateCoilCurrents : Wrench6DoF -> CoilCurrents
allocateCoilCurrents (MkWrench6DoF fx fy fz tx ty tz) =
  let kf = LORENTZ_KF_N_PER_A
      r  = LEVER_ARM_RADIUS_M
      -- Horizontal planar coils (Coils 1-4)
      i1 = (fx / (2.0 * kf)) + (tz / (4.0 * kf * r))
      i2 = (fx / (2.0 * kf)) - (tz / (4.0 * kf * r))
      i3 = (fy / (2.0 * kf)) + (tz / (4.0 * kf * r))
      i4 = (fy / (2.0 * kf)) - (tz / (4.0 * kf * r))
      -- Vertical levitation coils (Coils 5-8 arranged symmetrically at +/- L)
      i5 = (fz / (4.0 * kf)) + (ty / (4.0 * kf * r)) + (tx / (4.0 * kf * r))
      i6 = (fz / (4.0 * kf)) - (ty / (4.0 * kf * r)) + (tx / (4.0 * kf * r))
      i7 = (fz / (4.0 * kf)) + (ty / (4.0 * kf * r)) - (tx / (4.0 * kf * r))
      i8 = (fz / (4.0 * kf)) - (ty / (4.0 * kf * r)) - (tx / (4.0 * kf * r))
  in [i1, i2, i3, i4, i5, i6, i7, i8]

||| Compute instantaneous total Ohmic thermal dissipation power in Watts: P = sum(I_i^2 * R)
public export
computeOhmicPower : CoilCurrents -> Double
computeOhmicPower currents =
  let sumI2 = foldl (\acc, i => acc + i * i) 0.0 currents
  in sumI2 * COIL_RESISTANCE_OHMS

||| Check whether all coil currents are within electrical and thermal limits
public export
isActuationSafe : CoilCurrents -> Bool
isActuationSafe currents =
  let power = computeOhmicPower currents
      allWithinAmpLimit = foldl (\acc, i => acc && (abs i <= MAX_COIL_CURRENT_A)) True currents
  in allWithinAmpLimit && (power <= MAX_THERMAL_POWER_W)
