{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE GADTs #-}

module MyGIS.Data.Store.Types (
    IsStore (..)
  , Store (..)
  , Context (..)
  , ContextID
  , Registry (..)
  , StoreRegistry
  , ContextRegistry
  , StoreID
  , Generation (..)
  , GenError (..)
  , GenEnv (..)
  , GenState (..)

  , fromStore
) where

import           Control.Monad.Reader (ReaderT, MonadReader)
import           Control.Monad.State (StateT, MonadState)
import           Control.Monad.Error (ErrorT, MonadError, Error(..))
import           Data.Map (Map)
import           Data.Text (Text)
import           Data.Time.Clock (UTCTime)
import           Data.Typeable (Typeable, cast)
import           MyGIS.Data.Dimension (IsDimension(..), DimIx)
import           MyGIS.Data.Units (Unit)
import           MyGIS.Data.GeoReference (GeoReference)

type ContextID = Text

data Context = Context
  { contextId        :: ContextID
  , geoRef           :: GeoReference
} deriving (Eq, Show, Typeable)


newtype StoreID = StoreID Text deriving (Eq,Ord,Show,Typeable)

class ( IsDimension d
      , Eq (st d u t)
      , Show (st d u t)
      , Typeable (st d u t)
      ) =>  IsStore st d u t
  where
    type Src st d u t :: *

    storeId    :: st d u t -> StoreID
    getSource  :: st d u t -> Context -> DimIx d -> Src st d u t
    getSources :: st d u t -> Context -> DimIx d -> DimIx d -> [Src st d u t]
    dimension  :: st d u t -> d
    units      :: st d u t -> Unit u t
    toStore    :: st d u t -> Store

    toStore s = Store (storeId s) s

    getSources s ctx from to =
        map (getSource s ctx) (enumFromToIx (dimension s) from to)

fromStore :: IsStore st d u t => Store -> Maybe (st d u t)
fromStore (Store _ s) = cast s


data Store where
  Store :: IsStore st d u t => StoreID -> st d u t -> Store

deriving instance Show Store
instance Eq Store where
  (Store a _) == (Store b _) = a == b
instance Ord Store where
  (Store a _) `compare` (Store b _) = a `compare` b


newtype Generation a = Generation
    ( ReaderT GenEnv (ErrorT GenError (StateT GenState IO)) a )
  deriving
    ( MonadError GenError, MonadState GenState, MonadReader GenEnv
    , Monad, Functor )

data GenError = OtherError String deriving (Show, Eq)

instance Error GenError where
  noMsg  = OtherError "Unspecified generation error"
  strMsg = OtherError


data GenState = GenState

data GenEnv = GenEnv {
    currentTime :: UTCTime
  , registry    :: Registry
}

data Registry = Registry {
    stores   :: StoreRegistry
  , contexts :: ContextRegistry
}

type StoreRegistry = Map StoreID Store
type ContextRegistry = Map ContextID Context
