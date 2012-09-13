module Language.Haskell.Refact.Case(ifToCase) where

import qualified Data.Generics.Schemes as SYB
import qualified Data.Generics.Aliases as SYB
import qualified GHC.SYB.Utils         as SYB

import qualified GHC
import qualified DynFlags              as GHC
import qualified Outputable            as GHC
import qualified MonadUtils            as GHC
import qualified RdrName               as GHC
import qualified OccName               as GHC
 
import GHC.Paths ( libdir )
import Control.Monad
import Control.Monad.State
import Data.Data

import Language.Haskell.Refact.Utils 
import Language.Haskell.Refact.Utils.GhcUtils
import Language.Haskell.Refact.Utils.TypeSyn
import Language.Haskell.Refact.Utils.Monad

-- ---------------------------------------------------------------------

ifToCase :: [String] -> IO () -- For now
ifToCase args  
  = do let fileName = args!!0              
           beginPos = (read (args!!1), read (args!!2))::(Int,Int)
           endPos   = (read (args!!3), read (args!!4))::(Int,Int)
       -- putStrLn $ "ifToCase:" ++ (show args)  
       runRefac (comp fileName beginPos endPos)
       return ()

comp :: String -> (Int,Int) -> (Int,Int) -> RefactGhc ()
comp fileName beginPos endPos = do
       modInfo@((_, _, mod), toks) <- parseSourceFileGhc fileName 
       let exp = locToExp beginPos endPos toks mod
       case exp of
         (GHC.L _ (GHC.HsIf _ _ _ _))
                -> do refactoredMod <- liftIO $ applyRefac (ifToCase' exp) (Just modInfo ) fileName
                      liftIO $ writeRefactoredFiles False [refactoredMod]
         _      -> error "You haven't selected an if-then-else  expression!"
       return ()


ifToCase' ::
  GHC.GenLocated GHC.SrcSpan HsExpP 
  -> (t, [GHC.LIE GHC.RdrName], GHC.ParsedSource) -> Refact GHC.ParsedSource -- m GHC.ParsedSource
ifToCase' exp (_, _, mod) = 
   
   -- somewhereStaged SYB.Parser (SYB.mkM inExp) mod
   -- SYB.everywhereM (SYB.mkM inExp) mod
   everywhereMStaged SYB.Parser (SYB.mkM inExp) mod
       where
         inExp :: (GHC.Located HsExpP) -> Refact (GHC.Located HsExpP)        
         inExp exp1@(GHC.L _ (GHC.HsIf _ _ _ _))
           | sameOccurrence exp exp1       
           = let newExp = ifToCaseTransform exp1
             in update exp1 newExp exp1

         inExp e = return e
         -- inExp _ = mzero
         


ifToCaseTransform :: GHC.Located HsExpP -> GHC.Located HsExpP 
ifToCaseTransform (GHC.L l (GHC.HsIf _se e1 e2 e3))
  = GHC.L l (GHC.HsCase e1
             (GHC.MatchGroup
              [
                (GHC.noLoc $ GHC.Match
                 [
                   GHC.noLoc $ GHC.ConPatIn (GHC.noLoc $ GHC.mkRdrUnqual $ GHC.mkVarOcc "True") (GHC.PrefixCon [])
                 ]
                 Nothing
                 ((GHC.GRHSs
                   [
                     GHC.noLoc $ GHC.GRHS [] e2
                   ] GHC.EmptyLocalBinds))
                )
              , (GHC.noLoc $ GHC.Match
                 [
                   GHC.noLoc $ GHC.ConPatIn (GHC.noLoc $ GHC.mkRdrUnqual $ GHC.mkVarOcc "False") (GHC.PrefixCon [])
                 ]
                 Nothing
                 ((GHC.GRHSs
                   [
                     GHC.noLoc $ GHC.GRHS [] e3
                   ] GHC.EmptyLocalBinds))
                )
              ] undefined))
ifToCaseTransform x                          = x

                           



