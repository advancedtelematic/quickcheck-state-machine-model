{-# LANGUAGE DerivingStrategies         #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}

-----------------------------------------------------------------------------
-- |
-- Module      :  Test.StateMachine.Types.GenSym
-- Copyright   :  (C) 2018, HERE Europe B.V.
-- License     :  BSD-style (see the file LICENSE)
--
-- Maintainer  :  Stevan Andjelkovic <stevan.andjelkovic@strath.ac.uk>
-- Stability   :  provisional
-- Portability :  non-portable (GHC extensions)
--
-----------------------------------------------------------------------------

module Test.StateMachine.Types.GenSym
  ( GenSym
  , runGenSym
  , genSym
  , Counter
  , newCounter
  )
  where

import           Control.Monad.State
                   (State, get, put, runState)
import           Data.Typeable
                   (Typeable)
import           Prelude

import           Test.StateMachine.Types.References

------------------------------------------------------------------------

newtype GenSym a = GenSym (State Counter a)
  deriving newtype (Functor, Applicative, Monad)

runGenSym :: GenSym a -> Counter -> (a, Counter)
runGenSym (GenSym m) = runState m

genSym :: Typeable a => GenSym (Reference a Symbolic)
genSym  = GenSym $ do
  Counter i <- get
  put (Counter (i + 1))
  return (Reference (Symbolic (Var i)))

newtype Counter = Counter Int
  deriving stock Show

newCounter :: Counter
newCounter = Counter 0
