module Pellicle.Core.Matrix

import Data.Vect

%default total

||| A statically-sized matrix of dimension r rows by c columns
public export
Matrix : (r : Nat) -> (c : Nat) -> Type
Matrix r c = Vect r (Vect c Double)

||| Inner dot product of two dimension-matched vectors
public export
dotProduct : {n : Nat} -> Vect n Double -> Vect n Double -> Double
dotProduct [] [] = 0.0
dotProduct (x :: xs) (y :: ys) = (x * y) + dotProduct xs ys

||| Vector addition
public export
addVec : {n : Nat} -> Vect n Double -> Vect n Double -> Vect n Double
addVec [] [] = []
addVec (x :: xs) (y :: ys) = (x + y) :: addVec xs ys

||| Vector subtraction
public export
subVec : {n : Nat} -> Vect n Double -> Vect n Double -> Vect n Double
subVec [] [] = []
subVec (x :: xs) (y :: ys) = (x - y) :: subVec xs ys

||| Scalar multiplication of a vector
public export
scaleVec : {n : Nat} -> Double -> Vect n Double -> Vect n Double
scaleVec _ [] = []
scaleVec s (x :: xs) = (s * x) :: scaleVec s xs

||| Euclidean L2 norm of a vector
public export
vecNorm : {n : Nat} -> Vect n Double -> Double
vecNorm v = sqrt (dotProduct v v)

||| Matrix transposition (converts r x c into c x r)
public export
transposeMat : {r, c : Nat} -> Matrix r c -> Matrix c r
transposeMat = transpose

||| Multiply a matrix (r x c) by a column vector (c) yielding a vector of length r
public export
multVec : {r, c : Nat} -> Matrix r c -> Vect c Double -> Vect r Double
multVec [] _ = []
multVec (row :: rows) v = dotProduct row v :: multVec rows v

||| Multiply two conformable matrices (r x m) and (m x c) yielding (r x c)
public export
multMat : {r, m, c : Nat} -> Matrix r m -> Matrix m c -> Matrix r c
multMat mat1 mat2 =
  let mat2T = transposeMat mat2
  in map (\row => map (dotProduct row) mat2T) mat1

||| Construct an identity matrix of dimension n x n
public export
eye : (n : Nat) -> Matrix n n
eye Z = []
eye (S k) =
  let rowZero = 1.0 :: replicate k 0.0
      subIdentity = eye k
      subRows = map (0.0 ::) subIdentity
  in rowZero :: subRows

||| Construct a zero matrix of dimension r x c
public export
zeroMat : (r : Nat) -> (c : Nat) -> Matrix r c
zeroMat r c = replicate r (replicate c 0.0)

||| Trace of a square matrix
public export
matTrace : {n : Nat} -> Matrix n n -> Double
matTrace {n = Z} [] = 0.0
matTrace {n = S k} ((x :: _) :: rows) = x + matTrace (map tail rows)
