{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE StandaloneDeriving        #-}

-----------------------------------------------------------------------------
-- |
-- Module      :  Test.StateMachine.Logic
-- Copyright   :  (C) 2017, ATS Advanced Telematic Systems GmbH
-- License     :  BSD-style (see the file LICENSE)
--
-- Maintainer  :  Stevan Andjelkovic <stevan@advancedtelematic.com>
-- Stability   :  provisional
-- Portability :  non-portable (GHC extensions)
--
-- This module provides a propositional logic which gives counterexamples when
-- the proposition is false.
--
-----------------------------------------------------------------------------

module Test.StateMachine.Logic where

------------------------------------------------------------------------

infixr 1 :=>
infixr 2 :||
infixr 3 :&&

data Logic
  = Bot
  | Top
  | Logic :&& Logic
  | Logic :|| Logic
  | Logic :=> Logic
  | Not Logic
  | Predicate Predicate
  | Boolean Bool
  | Annotate String Logic
  deriving Show

data Predicate
  = forall a. (Eq  a, Show a) => a :== a
  | forall a. (Eq  a, Show a) => a :/= a
  | forall a. (Ord a, Show a) => a :<  a
  | forall a. (Ord a, Show a) => a :<= a
  | forall a. (Ord a, Show a) => a :>  a
  | forall a. (Ord a, Show a) => a :>= a
  | forall a. (Eq  a, Show a) => Elem    a [a]
  | forall a. (Eq  a, Show a) => NotElem a [a]

deriving instance Show Predicate

instance Eq Predicate where
  _ :==   _   == _ :==   _   = True
  _ :/=   _   == _ :/=   _   = True
  _ :<    _   == _ :<    _   = True
  _ :<=   _   == _ :<=   _   = True
  _ :>    _   == _ :>    _   = True
  _ :>=   _   == _ :>=   _   = True
  Elem    _ _ == Elem    _ _ = True
  NotElem _ _ == NotElem _ _ = True
  _           == _           = False

dual :: Predicate -> Predicate
dual p = case p of
  x :== y        -> x :/= y
  x :/= y        -> x :== y
  x :<  y        -> x :>= y
  x :<= y        -> x :>  y
  x :>  y        -> x :<= y
  x :>= y        -> x :<  y
  x `Elem`    xs -> x `NotElem` xs
  x `NotElem` xs -> x `Elem`    xs

-- See Yuri Gurevich's "Intuitionistic logic with strong negation" (1977).
strongNeg :: Logic -> Logic
strongNeg l0 = case l0 of
  Bot          -> Top
  Top          -> Bot
  l :&& r      -> strongNeg l :|| strongNeg r
  l :|| r      -> strongNeg l :&& strongNeg r
  l :=> r      ->           l :&& strongNeg r
  Not l        -> l
  Predicate p  -> Predicate (dual p)
  Boolean b    -> Boolean (not b)
  Annotate s l -> Annotate s (strongNeg l)

data Counterexample
  = BotC
  | Fst Counterexample
  | Snd Counterexample
  | EitherC Counterexample Counterexample
  | ImpliesC Counterexample
  | NotC Counterexample
  | PredicateC Predicate
  | BooleanC
  | AnnotateC String Counterexample
  deriving (Eq, Show)

data Value
  = VFalse Counterexample
  | VTrue
  deriving Show

boolean :: Logic -> Bool
boolean l = case logic l of
  VFalse _ -> False
  VTrue    -> True

logic :: Logic -> Value
logic Bot            = VFalse BotC
logic Top            = VTrue
logic (l :&& r)      = case logic l of
  VFalse ce -> VFalse (Fst ce)
  VTrue     -> case logic r of
    VFalse ce' -> VFalse (Snd ce')
    VTrue      -> VTrue
logic (l :|| r)      = case logic l of
  VTrue     -> VTrue
  VFalse ce -> case logic r of
    VTrue      -> VTrue
    VFalse ce' -> VFalse (EitherC ce ce')
logic (l :=> r)      = case logic l of
  VFalse _ -> VTrue
  VTrue    -> case logic r of
    VTrue     -> VTrue
    VFalse ce -> VFalse (ImpliesC ce)
logic (Not l)        = case logic (strongNeg l) of
  VTrue     -> VTrue
  VFalse ce -> VFalse (NotC ce)
logic (Predicate p)  = predicate p
logic (Boolean b)    = if b then VTrue else VFalse BooleanC
logic (Annotate s l) = case logic l of
  VTrue     -> VTrue
  VFalse ce -> VFalse (AnnotateC s ce)

predicate :: Predicate -> Value
predicate p0 = let b = go p0 in case p0 of
  x :== y        -> b (x == y)
  x :/= y        -> b (x /= y)
  x :<  y        -> b (x <  y)
  x :<= y        -> b (x <= y)
  x :>  y        -> b (x >  y)
  x :>= y        -> b (x >= y)
  x `Elem`    xs -> b (x `Prelude.elem`    xs)
  x `NotElem` xs -> b (x `Prelude.notElem` xs)
  where
    go :: Predicate -> Bool -> Value
    go _ True  = VTrue
    go p False = VFalse (PredicateC (dual p))

------------------------------------------------------------------------

infix 4 .==
infix 4 ./=
infix 4 .<
infix 4 .<=
infix 4 .>
infix 4 .>=
infix 4 `elem`
infix 4 `notElem`
infixl 4 .//

(.==) :: (Eq a, Show a) => a -> a -> Logic
x .== y = Predicate (x :== y)

(./=) :: (Eq a, Show a) => a -> a -> Logic
x ./= y = Predicate (x :/= y)

(.<) :: (Ord a, Show a) => a -> a -> Logic
x .< y = Predicate (x :< y)

(.<=) :: (Ord a, Show a) => a -> a -> Logic
x .<= y = Predicate (x :<= y)

(.>) :: (Ord a, Show a) => a -> a -> Logic
x .> y = Predicate (x :> y)

(.>=) :: (Ord a, Show a) => a -> a -> Logic
x .>= y = Predicate (x :>= y)

elem :: (Eq a, Show a) => a -> [a] -> Logic
elem x xs = Predicate (Elem x xs)

notElem :: (Eq a, Show a) => a -> [a] -> Logic
notElem x xs = Predicate (NotElem x xs)

(.//) :: Logic -> String -> Logic
l .// s = Annotate s l
