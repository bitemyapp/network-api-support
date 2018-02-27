{-# LANGUAGE OverloadedStrings, FlexibleContexts, CPP #-}

module Network.Api.Support.Core (
  runRequest
, runRequest'
, runRequestWith
, runRequestWith'
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

-- | Run a request using the specified settings, method, url and request transformer.
--
--   Prefer this to runRequest as recreating the manager every time is very inefficient.
--
runRequestWith ::
  Manager
  -> StdMethod
  -> Text
  -> RequestTransformer
  -> Responder b
  -> IO b
runRequestWith manager stdmethod url transform  =
  runRequestWith' manager url (transform <> setMethod (renderStdMethod stdmethod))

-- | Run a request using the specified settings, url and request transformer. The method
-- | can be set using the setMethod transformer. This is only useful if you require a
-- | custom http method. Prefer runRequest where possible.
runRequest' ::
  ManagerSettings
  -> Text
  -> RequestTransformer
  -> Responder b
  -> IO b
runRequest' settings url transform responder = do
  manager <- newManager settings
  runRequestWith' manager url transform responder

-- | Run a request using the specified manager, url and request transformer. The method
--   can be set using the setMethod transformer. This is only useful if you require a
--   custom http method. Prefer runRequest where possible.
--
--   Prefer this to runRequest' as recreating the manager every time is very inefficient.
--
runRequestWith' ::
  Manager
  -> Text
  -> RequestTransformer
  -> Responder b
  -> IO b
runRequestWith' manager url transform responder =
-- To achieve backwards compatibility for http-client<0.4.30
-- parseURL needs to be used and the default `checkStatus` handler
-- overridden to disable the trapping of non-2xx HTTP response codes.
-- Thereafter `parseRequest` can be used which does not trap any
-- reponse codes (the required behaviour).
#if MIN_VERSION_http_client(0,4,30)
  do url'' <- parseRequest $ unpack url
#else
  do url'  <- parseUrl     $ unpack url
     let url'' = url' { checkStatus = const . const . const $ Nothing } -- handle all response codes.
#endif
     let req = appEndo transform url''
     liftM (responder req) $ httpLbs req manager
