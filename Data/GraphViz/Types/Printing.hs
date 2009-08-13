{- |
   Module      : Data.GraphViz.Types.Printing
   Description : Helper functions for converting to Dot format.
   Copyright   : (c) Ivan Lazar Miljenovic
   License     : 3-Clause BSD-style
   Maintainer  : Ivan.Miljenovic@gmail.com

   This module defines simple helper functions for use with
   "Text.PrettyPrint".

   Note that the 'PrintDot' instances for 'Bool', etc. match those
   specified for use with GraphViz.

   You should not be using this module; rather, it is here for
   informative/documentative reasons.  If you want to print a
   @'Data.GraphViz.Types.DotGraph'@, you should use
   @'Data.GraphViz.Types.renderDotGraph'@ (which produces a
   'String' value) rather than its 'PrintDot' instance.

   The Dot language specification specifies that any identifier is in
   one of four forms:

       * Any string of alphabetic ([a-zA-Z\200-\377]) characters, underscores ('_') or digits ([0-9]), not beginning with a digit;

       * a number [-]?(.[0-9]+ | [0-9]+(.[0-9]*)? );

       * any double-quoted string (\"...\") possibly containing escaped quotes (\");

       * an HTML string (<...>).

   Due to these restrictions, you should only use 'text' when you are
   sure that the 'String' in question is static and quotes are
   definitely needed/unneeded; it is better to use the 'String'
   instance for 'PrintDot'.  For more information, see the
   specification page:
      <http://graphviz.org/doc/info/lang.html>
-}
module Data.GraphViz.Types.Printing
    ( module Text.PrettyPrint
    , DotCode
    , renderDot
    , PrintDot(..)
    , wrap
    , commaDel
    , printField
    ) where

import Data.GraphViz.Types.Internal

-- Only implicitly import and re-export combinators.
import Text.PrettyPrint hiding ( Style
                               , Mode
                               , TextDetails
                               , render
                               , style
                               , renderStyle
                               , fullRender
                               )
import qualified Text.PrettyPrint as PP

import Data.Char(isDigit)

-- -----------------------------------------------------------------------------

-- | A type alias to indicate what is being produced.
type DotCode = Doc

-- | Correctly render GraphViz output.
renderDot :: DotCode -> String
renderDot = PP.renderStyle style'
    where
      style' = PP.style { PP.mode = PP.LeftMode }

-- | A class used to correctly print parts of the GraphViz Dot language.
--   Minimal implementation is 'unqtDot'.
class PrintDot a where
    -- | The unquoted representation, for use when composing values to
    --   produce a larger printing value.
    unqtDot :: a -> DotCode

    -- | The actual quoted representation; this should be quoted if it
    --   contains characters not permitted a plain ID String, a number
    --   or it is not an HTML string.
    --   Defaults to 'unqtDot'.
    toDot :: a -> DotCode
    toDot = unqtDot

    -- | The correct way of representing a list of this value when
    --   printed; not all Dot values require this to be implemented.
    --   Defaults to Haskell-like list representation.
    unqtListToDot :: [a] -> DotCode
    unqtListToDot = brackets . hsep . punctuate comma
                    . map unqtDot

    -- | The quoted form of 'unqtListToDot'; defaults to wrapping
    --   double quotes around the result of 'unqtListToDot' (since the
    --   default implementation has characters that must be quoted).
    listToDot :: [a] -> DotCode
    listToDot = doubleQuotes . unqtListToDot

instance PrintDot Int where
    unqtDot = int

instance PrintDot Double where
    unqtDot = double

instance PrintDot Bool where
    unqtDot True  = text "true"
    unqtDot False = text "false"

instance PrintDot Char where
    unqtDot = char

    toDot = qtChar

    unqtListToDot = unqtString

    listToDot = qtString

-- | Check to see if this 'Char' needs to be quoted or not.
qtChar :: Char -> DotCode
qtChar c
    | frstIDString c = char c
    | isDigit c      = char c -- Could be a number
    | otherwise      = doubleQuotes $ char c

-- | Escape quotes in Strings that need them.
unqtString :: String -> DotCode
unqtString str
    | isIDString str = text str
    | otherwise      = text $ escapeQuotes str

-- | Escape quotes and quote Strings that need them.
qtString :: String -> DotCode
qtString str
    | isIDString str = text str
                       -- Don't use unqtString as it re-runs isIDString
    | otherwise      = doubleQuotes . text $ escapeQuotes str

instance (PrintDot a) => PrintDot [a] where
    unqtDot = unqtListToDot

    toDot = listToDot

wrap       :: DotCode -> DotCode -> DotCode -> DotCode
wrap b a d = b <> d <> a

commaDel     :: (PrintDot a, PrintDot b) => a -> b -> DotCode
commaDel a b = unqtDot a <> comma <> unqtDot b

printField     :: (PrintDot a) => String -> a -> DotCode
printField f v = text f <> equals <> toDot v