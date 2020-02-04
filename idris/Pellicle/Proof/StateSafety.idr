module Pellicle.Proof.StateSafety

import Decidable.Equality
import Pellicle.Core.Types

%default total

||| Inductive definition of permissible operational state transitions for a wafer stage chuck
public export
data ValidTransition : ChuckState -> ChuckState -> Type where
  IdleToLoading       : ValidTransition ChuckIdle ChuckLoading
  LoadingToMeasuring  : ValidTransition ChuckLoading ChuckMeasuring
  MeasuringToSwapping : ValidTransition ChuckMeasuring ChuckSwapping
  SwappingToExposing  : ValidTransition ChuckSwapping ChuckExposing
  ExposingToUnloading : ValidTransition ChuckExposing ChuckUnloading
  UnloadingToIdle     : ValidTransition ChuckUnloading ChuckIdle
  AnyToFault          : ValidTransition s ChuckFault
  FaultToIdle         : ValidTransition ChuckFault ChuckIdle

||| Formally proved theorem: It is impossible to transition directly from ChuckIdle to ChuckExposing
public export
noDirectIdleToExposing : ValidTransition ChuckIdle ChuckExposing -> Void
noDirectIdleToExposing IdleToLoading impossible
noDirectIdleToExposing LoadingToMeasuring impossible
noDirectIdleToExposing MeasuringToSwapping impossible
noDirectIdleToExposing SwappingToExposing impossible
noDirectIdleToExposing ExposingToUnloading impossible
noDirectIdleToExposing UnloadingToIdle impossible
noDirectIdleToExposing AnyToFault impossible
noDirectIdleToExposing FaultToIdle impossible

||| Formally proved theorem: It is impossible to transition directly from ChuckMeasuring to ChuckExposing without a swap
public export
noDirectMeasuringToExposing : ValidTransition ChuckMeasuring ChuckExposing -> Void
noDirectMeasuringToExposing IdleToLoading impossible
noDirectMeasuringToExposing LoadingToMeasuring impossible
noDirectMeasuringToExposing MeasuringToSwapping impossible
noDirectMeasuringToExposing SwappingToExposing impossible
noDirectMeasuringToExposing ExposingToUnloading impossible
noDirectMeasuringToExposing UnloadingToIdle impossible
noDirectMeasuringToExposing AnyToFault impossible
noDirectMeasuringToExposing FaultToIdle impossible

||| Decidable verification for any proposed state transition
public export
checkTransition : (from : ChuckState) -> (to : ChuckState) -> Dec (ValidTransition from to)
checkTransition ChuckIdle ChuckLoading = Yes IdleToLoading
checkTransition ChuckLoading ChuckMeasuring = Yes LoadingToMeasuring
checkTransition ChuckMeasuring ChuckSwapping = Yes MeasuringToSwapping
checkTransition ChuckSwapping ChuckExposing = Yes SwappingToExposing
checkTransition ChuckExposing ChuckUnloading = Yes ExposingToUnloading
checkTransition ChuckUnloading ChuckIdle = Yes UnloadingToIdle
checkTransition ChuckFault ChuckIdle = Yes FaultToIdle
checkTransition s ChuckFault = Yes AnyToFault
-- Negative cases for ChuckIdle
checkTransition ChuckIdle ChuckIdle = No (\case AnyToFault impossible)
checkTransition ChuckIdle ChuckMeasuring = No (\case AnyToFault impossible)
checkTransition ChuckIdle ChuckSwapping = No (\case AnyToFault impossible)
checkTransition ChuckIdle ChuckExposing = No noDirectIdleToExposing
checkTransition ChuckIdle ChuckUnloading = No (\case AnyToFault impossible)
-- Negative cases for ChuckLoading
checkTransition ChuckLoading ChuckIdle = No (\case AnyToFault impossible)
checkTransition ChuckLoading ChuckLoading = No (\case AnyToFault impossible)
checkTransition ChuckLoading ChuckSwapping = No (\case AnyToFault impossible)
checkTransition ChuckLoading ChuckExposing = No (\case AnyToFault impossible)
checkTransition ChuckLoading ChuckUnloading = No (\case AnyToFault impossible)
-- Negative cases for ChuckMeasuring
checkTransition ChuckMeasuring ChuckIdle = No (\case AnyToFault impossible)
checkTransition ChuckMeasuring ChuckLoading = No (\case AnyToFault impossible)
checkTransition ChuckMeasuring ChuckMeasuring = No (\case AnyToFault impossible)
checkTransition ChuckMeasuring ChuckExposing = No noDirectMeasuringToExposing
checkTransition ChuckMeasuring ChuckUnloading = No (\case AnyToFault impossible)
-- Negative cases for ChuckSwapping
checkTransition ChuckSwapping ChuckIdle = No (\case AnyToFault impossible)
checkTransition ChuckSwapping ChuckLoading = No (\case AnyToFault impossible)
checkTransition ChuckSwapping ChuckMeasuring = No (\case AnyToFault impossible)
checkTransition ChuckSwapping ChuckSwapping = No (\case AnyToFault impossible)
checkTransition ChuckSwapping ChuckUnloading = No (\case AnyToFault impossible)
-- Negative cases for ChuckExposing
checkTransition ChuckExposing ChuckIdle = No (\case AnyToFault impossible)
checkTransition ChuckExposing ChuckLoading = No (\case AnyToFault impossible)
checkTransition ChuckExposing ChuckMeasuring = No (\case AnyToFault impossible)
checkTransition ChuckExposing ChuckSwapping = No (\case AnyToFault impossible)
checkTransition ChuckExposing ChuckExposing = No (\case AnyToFault impossible)
-- Negative cases for ChuckUnloading
checkTransition ChuckUnloading ChuckLoading = No (\case AnyToFault impossible)
checkTransition ChuckUnloading ChuckMeasuring = No (\case AnyToFault impossible)
checkTransition ChuckUnloading ChuckSwapping = No (\case AnyToFault impossible)
checkTransition ChuckUnloading ChuckExposing = No (\case AnyToFault impossible)
checkTransition ChuckUnloading ChuckUnloading = No (\case AnyToFault impossible)
-- Negative cases for ChuckFault
checkTransition ChuckFault ChuckLoading = No (\case AnyToFault impossible)
checkTransition ChuckFault ChuckMeasuring = No (\case AnyToFault impossible)
checkTransition ChuckFault ChuckSwapping = No (\case AnyToFault impossible)
checkTransition ChuckFault ChuckExposing = No (\case AnyToFault impossible)
checkTransition ChuckFault ChuckUnloading = No (\case AnyToFault impossible)
