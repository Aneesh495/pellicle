module Pellicle.Core.Types

%default total

||| Length in nanometers (1 nm = 1e-9 m)
public export
NanoMeter : Type
NanoMeter = Double

||| Length in millimeters (1 mm = 1e-3 m)
public export
MilliMeter : Type
MilliMeter = Double

||| Angle in microradians (1 urad = 1e-6 rad)
public export
MicroRadian : Type
MicroRadian = Double

||| Velocity in meters per second
public export
MeterPerSecond : Type
MeterPerSecond = Double

||| Acceleration in meters per second squared
public export
MeterPerSecondSq : Type
MeterPerSecondSq = Double

||| Jerk in meters per second cubed
public export
MeterPerSecondCube : Type
MeterPerSecondCube = Double

||| Radiation dose energy density in mJ/cm^2
public export
MilliJoulePerSqCm : Type
MilliJoulePerSqCm = Double

||| Vacuum wavelength of HeNe metrology laser in nanometers
public export
HE_NE_WAVELENGTH_NM : Double
HE_NE_WAVELENGTH_NM = 632.816460

||| Immersion ArF excimer laser exposure wavelength in nanometers
public export
ARF_WAVELENGTH_NM : Double
ARF_WAVELENGTH_NM = 193.368000

||| Extreme Ultraviolet exposure wavelength in nanometers
public export
EUV_WAVELENGTH_NM : Double
EUV_WAVELENGTH_NM = 13.500000

||| Standard silicon wafer diameter in millimeters
public export
WAFER_DIAMETER_MM : Double
WAFER_DIAMETER_MM = 300.0

||| Projection reduction magnification factor (reticle to wafer)
public export
RETICLE_REDUCTION_RATIO : Double
RETICLE_REDUCTION_RATIO = 4.0

||| Maximum permissible stage scanning velocity in m/s
public export
MAX_STAGE_VELOCITY_MPS : Double
MAX_STAGE_VELOCITY_MPS = 5.0

||| Maximum permissible stage acceleration in m/s^2 (~12.2 g)
public export
MAX_STAGE_ACCEL_MPSS : Double
MAX_STAGE_ACCEL_MPSS = 120.0

||| Maximum permissible trajectory jerk in m/s^3 to avoid structural resonance
public export
MAX_STAGE_JERK_MPS3 : Double
MAX_STAGE_JERK_MPS3 = 20000.0

||| Maximum allowable dynamic moving average overlay error in nm
public export
MAX_OVERLAY_DMA_NM : Double
MAX_OVERLAY_DMA_NM = 1.20

||| Maximum allowable moving standard deviation overlay jitter in nm
public export
MAX_OVERLAY_MSD_NM : Double
MAX_OVERLAY_MSD_NM = 1.80

||| Minimum physical clearance distance between dual chucks in mm
public export
MIN_CHUCK_CLEARANCE_MM : Double
MIN_CHUCK_CLEARANCE_MM = 15.0

||| Two-dimensional Cartesian coordinate in millimeters
public export
record Point2D where
  constructor MkPoint2D
  xMm : Double
  yMm : Double

public export
Show Point2D where
  show (MkPoint2D x y) = "(" ++ show x ++ ", " ++ show y ++ ") mm"

||| Three-dimensional Cartesian coordinate in millimeters
public export
record Point3D where
  constructor MkPoint3D
  xMm : Double
  yMm : Double
  zMm : Double

public export
Show Point3D where
  show (MkPoint3D x y z) = "(" ++ show x ++ ", " ++ show y ++ ", " ++ show z ++ ") mm"

||| Physical photolithographic exposure light sources
public export
data LaserSource = ArFi | EUV | DUV_KrF

public export
Show LaserSource where
  show ArFi = "ArFi (193.368 nm)"
  show EUV = "EUV (13.500 nm)"
  show DUV_KrF = "DUV KrF (248.327 nm)"

||| Optical heterodyne interferometer metrology measurement axes
public export
data InterferometerAxis = AxisX1 | AxisX2 | AxisY1 | AxisY2 | AxisZ1 | AxisZ2 | AxisZ3

public export
Show InterferometerAxis where
  show AxisX1 = "Interferometer X1"
  show AxisX2 = "Interferometer X2"
  show AxisY1 = "Interferometer Y1"
  show AxisY2 = "Interferometer Y2"
  show AxisZ1 = "Interferometer Z1"
  show AxisZ2 = "Interferometer Z2"
  show AxisZ3 = "Interferometer Z3"

||| Identification for the dual twin-scan wafer chucks
public export
data ChuckId = Chuck1 | Chuck2

public export
Eq ChuckId where
  Chuck1 == Chuck1 = True
  Chuck2 == Chuck2 = True
  _ == _ = False

public export
Show ChuckId where
  show Chuck1 = "Chuck-1"
  show Chuck2 = "Chuck-2"

||| Operational state of a wafer stage chuck
public export
data ChuckState
  = ChuckIdle
  | ChuckLoading
  | ChuckMeasuring
  | ChuckSwapping
  | ChuckExposing
  | ChuckUnloading
  | ChuckFault

public export
Eq ChuckState where
  ChuckIdle == ChuckIdle = True
  ChuckLoading == ChuckLoading = True
  ChuckMeasuring == ChuckMeasuring = True
  ChuckSwapping == ChuckSwapping = True
  ChuckExposing == ChuckExposing = True
  ChuckUnloading == ChuckUnloading = True
  ChuckFault == ChuckFault = True
  _ == _ = False

public export
Show ChuckState where
  show ChuckIdle = "IDLE"
  show ChuckLoading = "LOADING"
  show ChuckMeasuring = "MEASURING"
  show ChuckSwapping = "SWAPPING"
  show ChuckExposing = "EXPOSING"
  show ChuckUnloading = "UNLOADING"
  show ChuckFault = "FAULT"

||| Physical state of the exposure laser optical shutter
public export
data ShutterState = ShutterClosed | ShutterOpen

public export
Eq ShutterState where
  ShutterClosed == ShutterClosed = True
  ShutterOpen == ShutterOpen = True
  _ == _ = False

public export
Show ShutterState where
  show ShutterClosed = "SHUTTER_CLOSED"
  show ShutterOpen = "SHUTTER_OPEN"

||| Convert nanometers to millimeters
public export
nmToMm : NanoMeter -> MilliMeter
nmToMm nm = nm / 1000000.0

||| Convert millimeters to nanometers
public export
mmToNm : MilliMeter -> NanoMeter
mmToNm mm = mm * 1000000.0

||| Compute 2D Euclidean distance between two points in millimeters
public export
distance2D : Point2D -> Point2D -> Double
distance2D (MkPoint2D x1 y1) (MkPoint2D x2 y2) =
  let dx = x2 - x1
      dy = y2 - y1
  in sqrt (dx * dx + dy * dy)
