{-# LANGUAGE OverloadedStrings, FlexibleContexts #-}
module Network.Api.Support.Core (
  runRequest
, runRequest'
) where

import Network.Api.Support.Request
import Network.Api.Support.Response

import Control.Monad

import Data.Text
import Data.Monoid

import Network.HTTP.Client
import Network.HTTP.Types

-- * Request runners

-- | Run a request using the specified settings, method, url and request transformer.
runRequest ::
  ManagerSettings
  -> StdMethod
  -> Text
  -> RequestTransformer
  -> Responder b
  -> IO b
runRequest settings stdmethod url transform  =
  runRequest' settings url (transform <> setMethod (renderStdMethod stdmethod))

-- | Run a request using the specified settings, url and request transformer. The method
-- | can be set using the setMethod transformer. This is only useful if you require a
-- | custom http method. Prefer runRequest where possible.
runRequest' ::
  ManagerSettings
  -> Text
  -> RequestTransformer
  -> Responder b
  -> IO b
runRequest' settings url transform responder =
  do url' <- parseUrl $ unpack url
     -- handle all response codes.
     let url'' = url' { checkResponse = \_ _ -> return () }
         req = appEndo transform url''
     liftM (responder req) . withManager settings . httpLbs $ req
