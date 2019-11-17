module Pellicle.Core.Units

%default total

||| Physical dimension tags for compile-time dimensional analysis
public export
data Dimension
  = DimLength
  | DimTime
  | DimAngle
  | DimMass
  | DimForce
  | DimEnergy
  | DimVelocity
  | DimAcceleration

public export
Eq Dimension where
  DimLength == DimLength = True
  DimTime == DimTime = True
  DimAngle == DimAngle = True
  DimMass == DimMass = True
  DimForce == DimForce = True
  DimEnergy == DimEnergy = True
  DimVelocity == DimVelocity = True
  DimAcceleration == DimAcceleration = True
  _ == _ = False

public export
Show Dimension where
  show DimLength = "Length [m]"
  show DimTime = "Time [s]"
  show DimAngle = "Angle [rad]"
  show DimMass = "Mass [kg]"
  show DimForce = "Force [N]"
  show DimEnergy = "Energy [J]"
  show DimVelocity = "Velocity [m/s]"
  show DimAcceleration = "Acceleration [m/s^2]"

||| A physical quantity tagged with its physical dimension
public export
data Quantity : Dimension -> Type where
  MkQuantity : Double -> Quantity dim

public export
getVal : Quantity dim -> Double
getVal (MkQuantity v) = v

public export
Eq (Quantity dim) where
  (MkQuantity v1) == (MkQuantity v2) = v1 == v2

public export
Show (Quantity dim) where
  show (MkQuantity v) = show v

||| Add two physical quantities of identical dimension
public export
addQ : Quantity dim -> Quantity dim -> Quantity dim
addQ (MkQuantity a) (MkQuantity b) = MkQuantity (a + b)

||| Subtract two physical quantities of identical dimension
public export
subQ : Quantity dim -> Quantity dim -> Quantity dim
subQ (MkQuantity a) (MkQuantity b) = MkQuantity (a - b)

||| Scale a physical quantity by a dimensionless scalar
public export
scaleQ : Double -> Quantity dim -> Quantity dim
scaleQ s (MkQuantity a) = MkQuantity (s * a)

||| Negate a physical quantity
public export
negQ : Quantity dim -> Quantity dim
negQ (MkQuantity a) = MkQuantity (-a)

||| Construct length in nanometers (internal representation in meters)
public export
nanoMeters : Double -> Quantity DimLength
nanoMeters nm = MkQuantity (nm * 1.0e-9)

||| Construct length in millimeters (internal representation in meters)
public export
milliMeters : Double -> Quantity DimLength
milliMeters mm = MkQuantity (mm * 1.0e-3)

||| Extract nanometers from a length quantity
public export
toNanoMeters : Quantity DimLength -> Double
toNanoMeters (MkQuantity m) = m * 1.0e9

||| Extract millimeters from a length quantity
public export
toMilliMeters : Quantity DimLength -> Double
toMilliMeters (MkQuantity m) = m * 1.0e3

||| Construct angle in microradians (internal representation in radians)
public export
microRadians : Double -> Quantity DimAngle
microRadians urad = MkQuantity (urad * 1.0e-6)

||| Extract microradians from an angle quantity
public export
toMicroRadians : Quantity DimAngle -> Double
toMicroRadians (MkQuantity rad) = rad * 1.0e6

||| Construct velocity in meters per second
public export
metersPerSec : Double -> Quantity DimVelocity
metersPerSec v = MkQuantity v

||| Construct acceleration in meters per second squared
public export
metersPerSecSq : Double -> Quantity DimAcceleration
metersPerSecSq a = MkQuantity a
