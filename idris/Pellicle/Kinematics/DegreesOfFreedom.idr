module Pellicle.Kinematics.DegreesOfFreedom

import Pellicle.Core.Types

%default total

||| Six degrees of freedom position state for a lithography stage
||| Translation in millimeters, rotation in microradians
public export
record Pose6DoF where
  constructor MkPose6DoF
  xMm : Double
  yMm : Double
  zMm : Double
  rxUrad : Double
  ryUrad : Double
  rzUrad : Double

public export
Show Pose6DoF where
  show (MkPose6DoF x y z rx ry rz) =
    "Pose[X=" ++ show x ++ "mm, Y=" ++ show y ++ "mm, Z=" ++ show z ++ "mm, " ++
    "Rx=" ++ show rx ++ "urad, Ry=" ++ show ry ++ "urad, Rz=" ++ show rz ++ "urad]"

||| Six degrees of freedom velocity state for a lithography stage
||| Linear velocity in m/s, angular velocity in mrad/s
public export
record Velocity6DoF where
  constructor MkVelocity6DoF
  vxMps : Double
  vyMps : Double
  vzMps : Double
  wxMradPs : Double
  wyMradPs : Double
  wzMradPs : Double

public export
Show Velocity6DoF where
  show (MkVelocity6DoF vx vy vz wx wy wz) =
    "Vel[Vx=" ++ show vx ++ "m/s, Vy=" ++ show vy ++ "m/s, Vz=" ++ show vz ++ "m/s, " ++
    "Wx=" ++ show wx ++ "mrad/s, Wy=" ++ show wy ++ "mrad/s, Wz=" ++ show wz ++ "mrad/s]"

||| Six degrees of freedom acceleration state for a lithography stage
||| Linear acceleration in m/s^2, angular acceleration in rad/s^2
public export
record Accel6DoF where
  constructor MkAccel6DoF
  axMpss : Double
  ayMpss : Double
  azMpss : Double
  alphaXRadPss : Double
  alphaYRadPss : Double
  alphaZRadPss : Double

public export
Show Accel6DoF where
  show (MkAccel6DoF ax ay az ax_r ay_r az_r) =
    "Accel[Ax=" ++ show ax ++ "m/s^2, Ay=" ++ show ay ++ "m/s^2, Az=" ++ show az ++ "m/s^2, " ++
    "AlphaX=" ++ show ax_r ++ ", AlphaY=" ++ show ay_r ++ ", AlphaZ=" ++ show az_r ++ "]"

||| Zero pose state (home position)
public export
zeroPose : Pose6DoF
zeroPose = MkPose6DoF 0.0 0.0 0.0 0.0 0.0 0.0

||| Zero velocity state (stationary)
public export
zeroVelocity : Velocity6DoF
zeroVelocity = MkVelocity6DoF 0.0 0.0 0.0 0.0 0.0 0.0

||| Zero acceleration state
public export
zeroAccel : Accel6DoF
zeroAccel = MkAccel6DoF 0.0 0.0 0.0 0.0 0.0 0.0

||| Add a delta translation and rotation to a 6-DoF pose
public export
addPose : Pose6DoF -> Pose6DoF -> Pose6DoF
addPose (MkPose6DoF x1 y1 z1 rx1 ry1 rz1) (MkPose6DoF x2 y2 z2 rx2 ry2 rz2) =
  MkPose6DoF (x1 + x2) (y1 + y2) (z1 + z2) (rx1 + rx2) (ry1 + ry2) (rz1 + rz2)

||| Transform point from chuck local coordinates (mm) to global tool coordinates (mm)
||| Point P_global = P_stage + R * P_local
||| For small angles (rx, ry, rz in urad), R is approximated by small-angle matrix
public export
transformLocalToGlobal : Pose6DoF -> Point3D -> Point3D
transformLocalToGlobal (MkPose6DoF sx sy sz rxUrad ryUrad rzUrad) (MkPoint3D lx ly lz) =
  let rx = rxUrad * 1.0e-6
      ry = ryUrad * 1.0e-6
      rz = rzUrad * 1.0e-6
      gx = sx + lx - rz * ly + ry * lz
      gy = sy + rz * lx + ly - rx * lz
      gz = sz - ry * lx + rx * ly + lz
  in MkPoint3D gx gy gz

||| Linear travel boundary limits for Chuck in the machine frame (in mm)
public export
record StageEnvelope where
  constructor MkStageEnvelope
  xMinMm : Double
  xMaxMm : Double
  yMinMm : Double
  yMaxMm : Double
  zMinMm : Double
  zMaxMm : Double

public export
standardEnvelope : StageEnvelope
standardEnvelope = MkStageEnvelope (-250.0) 250.0 (-250.0) 250.0 (-5.0) 5.0

||| Verify whether a 6-DoF pose lies strictly inside the physical travel envelope
public export
isPoseWithinEnvelope : StageEnvelope -> Pose6DoF -> Bool
isPoseWithinEnvelope env pose =
  pose.xMm >= env.xMinMm && pose.xMm <= env.xMaxMm &&
  pose.yMm >= env.yMinMm && pose.yMm <= env.yMaxMm &&
  pose.zMm >= env.zMinMm && pose.zMm <= env.zMaxMm
