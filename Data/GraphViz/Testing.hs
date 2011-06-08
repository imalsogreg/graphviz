{- |
   Module      : Data.GraphViz.Testing
   Description : Test-suite for graphviz.
   Copyright   : (c) Ivan Lazar Miljenovic
   License     : 3-Clause BSD-style
   Maintainer  : Ivan.Miljenovic@gmail.com

   This defines a test-suite for the graphviz library.

   Limitations of the test suite are as follows:

   * For the most part, this library lets you use arbitrary numbers
     for String values.  However, this is not tested due to too many
     corner cases for special parsers that don't take arbitrary
     Strings.  As the Dot standard is ambiguous over whether you can
     or can't use numbers as Strings (more specifically, if they
     should be quoted or not), this is a user beware situation.

   * Same goes for empty Strings; sometimes they're allowed, sometimes
     they're not.  Thus, to simplify matters they're not generated.

   * The generated Strings are very simple, only composed of lower
     case letters, digits and some symbols.  This is because too many
     tests were \"failing\" due to some corner case; e.g. lower-case
     letters only because the parser parses Strings as lowercase, so
     if a particular String isn't valid (e.g. @\"all\"@ for 'LayerID',
     then the 'Arbitrary' instance has to ensure that all possible
     ways of capitalising that String isn't generated as a random
     'LRName'.

   * The generated 'DotGraph's are not guaranteed to be valid.

   * To avoid needless endless recursion, 'DotSubGraph's do not have
     sub-'DotSubGraph's (same with 'GDotSubGraph's).

   * This test suite isn't perfect: if you deliberately try to stuff
     something up, you probably can.
-}
module Data.GraphViz.Testing
       ( -- * Running the test suite.
         runChosenTests
       , runTests
       , runTest
         -- ** The tests themselves
       , Test(..)
       , defaultTests
       , test_printParseID_Attributes
       , test_generalisedSameDot
       , test_printParseID
       , test_preProcessingID
       , test_dotizeAugment
       , test_dotizeAugmentUniq
       , test_canonicalise
       , test_transitive
        -- * Re-exporting modules for manual testing.
       , module Data.GraphViz
       , module Data.GraphViz.Types.Generalised
       , module Data.GraphViz.Testing.Properties
         -- * Debugging printing
       , PrintDot(..)
       , printIt
       , renderDot
         -- * Debugging parsing
       , ParseDot(..)
       , parseIt
       , runParser
       , preProcess
       ) where

import Test.QuickCheck

import Data.GraphViz.Testing.Instances()
-- This module cannot be re-exported from Instances, as it causes
-- Overlapping Instances.
import Data.GraphViz.Testing.Instances.FGL()
import Data.GraphViz.Testing.Properties

import Data.GraphViz
import Data.GraphViz.Parsing(ParseDot(..), parseIt, runParser)
import Data.GraphViz.PreProcessing(preProcess)
import Data.GraphViz.Printing(PrintDot(..), printIt, renderDot)
import Data.GraphViz.Types.Generalised hiding ( GraphID(..)
                                              , GlobalAttributes(..)
                                              , DotNode(..)
                                              , DotEdge(..))
-- Can't use PatriciaTree because a Show instance is needed.
import Data.Graph.Inductive.Tree(Gr)

import System.Exit(ExitCode(..), exitWith)
import System.IO(hPutStrLn, stderr)

-- -----------------------------------------------------------------------------

runChosenTests       :: [Test] -> IO ()
runChosenTests tests = do putStrLn msg
                          blankLn
                          runTests tests
                          spacerLn
                          putStrLn successMsg
  where
    msg = "This is the test suite for the graphviz library.\n\
           \If any of these tests fail, please inform the maintainer,\n\
           \including full output of this test suite."

    successMsg = "All tests were successful!"


-- -----------------------------------------------------------------------------
-- Defining a Test structure and how to run tests.

-- | Defines the test structure being used.
data Test = Test { name       :: String
                 , lookupName :: String    -- ^ Should be lowercase
                 , desc       :: String
                 , test       :: IO Result -- ^ QuickCheck test.
                 }

-- | Run all of the provided tests.
runTests :: [Test] -> IO ()
runTests = mapM_ ((>>) spacerLn . runTest)

-- | Run the provided test.
runTest     :: Test -> IO ()
runTest tst = do putStrLn title
                 blankLn
                 putStrLn $ desc tst
                 blankLn
                 r <- test tst
                 blankLn
                 case r of
                   Success{} -> putStrLn successMsg
                   GaveUp{}  -> putStrLn gaveUpMsg
                   _         -> die failMsg
                 blankLn
  where
    nm = '"' : name tst ++ "\""
    title = "Running test: " ++ nm ++ "."
    successMsg = "All tests for " ++ nm ++ " were successful!"
    gaveUpMsg = "Too many sample inputs for " ++ nm ++ " were rejected;\n\
                 \tentatively marking this as successful."
    failMsg = "The tests for " ++ nm ++ " failed!\n\
               \Not attempting any further tests."

spacerLn :: IO ()
spacerLn = putStrLn (replicate 70 '=') >> blankLn

blankLn :: IO ()
blankLn = putStrLn ""

die     :: String -> IO a
die msg = do hPutStrLn stderr msg
             exitWith (ExitFailure 1)

-- -----------------------------------------------------------------------------
-- Defining the tests to use.

-- | The tests to run by default.
defaultTests :: [Test]
defaultTests = [ test_printParseID_Attributes
               , test_generalisedSameDot
               , test_printParseID
               , test_printParseGID
               , test_preProcessingID
               , test_dotizeAugment
               , test_dotizeAugmentUniq
               , test_findAllNodes
               , test_findAllNodesG
               , test_findAllNodesE
               , test_findAllNodesEG
               , test_findAllEdges
               , test_findAllEdgesG
               , test_noGraphInfo
               , test_noGraphInfoG
               , test_canonicalise
               , test_transitive
               ]

-- | Test that 'Attributes' can be printed and then parsed back.
test_printParseID_Attributes :: Test
test_printParseID_Attributes
  = Test { name       = "Printing and parsing of Attributes"
         , lookupName = "attributes"
         , desc       = dsc
         , test       = quickCheckWithResult args prop
         }
  where
    prop :: Attributes -> Property
    prop = prop_printParseListID

    args = stdArgs { maxSuccess = numGen }
    numGen = 10000
    defGen = maxSuccess stdArgs

    dsc = "The most common source of errors in printing and parsing are for\n\
          \Attributes.  As such, these are stress-tested before we run the\n\
          \rest of the tests, generating " ++ show numGen ++ " lists of\n\
          \Attributes rather than the default " ++ show defGen ++ " tests."

test_generalisedSameDot :: Test
test_generalisedSameDot
  = Test { name       = "Printing generalised Dot code"
         , lookupName = "makegeneralised"
         , desc       = dsc
         , test       = quickCheckResult prop
         }
    where
      prop :: DotGraph Int -> Bool
      prop = prop_generalisedSameDot

      dsc = "When generalising \"DotGraph\" values to \"GDotGraph\" values,\n\
             \the generated Dot code should be identical."

test_printParseID :: Test
test_printParseID
  = Test { name       = "Printing and Parsing DotGraphs"
         , lookupName = "printparseid"
         , desc       = dsc
         , test       = quickCheckResult prop
         }
  where
    prop :: DotGraph Int -> Bool
    prop = prop_printParseID

    dsc = "The graphviz library should be able to parse back in its own\n\
           \generated Dot code.  This test aims to determine the validity\n\
           \of this for the overall \"DotGraph Int\" values."

test_printParseGID :: Test
test_printParseGID
  = Test { name       = "Printing and Parsing Generalised DotGraphs"
         , lookupName = "printparseidg"
         , desc       = dsc
         , test       = quickCheckResult prop
         }
  where
    prop :: GDotGraph Int -> Bool
    prop = prop_printParseID

    dsc = "The graphviz library should be able to parse back in its own\n\
           \generated Dot code.  This test aims to determine the validity\n\
           \of this for the overall \"GDotGraph Int\" values."

test_preProcessingID :: Test
test_preProcessingID
  = Test { name       = "Pre-processing Dot code"
         , lookupName = "preprocessing"
         , desc       = dsc
         , test       = quickCheckResult prop
         }
  where
    prop :: DotGraph Int -> Bool
    prop = prop_preProcessingID

    dsc = "When parsing Dot code, some pre-processing is done to remove items\n\
           \such as comments and to join together multi-line strings.  This\n\
           \test verifies that this pre-processing doesn't affect actual\n\
           \Dot code by running the pre-processor on generated Dot code.\n\n\
           \This test is not run on generalised Dot graphs as if it works for\n\
           \normal dot graphs then it should also work for generalised ones."

test_dotizeAugment :: Test
test_dotizeAugment
  = Test { name       = "Augmenting FGL Graphs"
         , lookupName = "augment"
         , desc       = dsc
         , test       = quickCheckResult prop
         }
  where
    prop :: Gr Char Double -> Bool
    prop = prop_dotizeAugment

    dsc = "The various Graph to Graph functions in Data.GraphViz should\n\
           \only _augment_ the graph labels and not change the graphs\n\
           \themselves.  This test compares the original graphs to these\n\
           \augmented graphs and verifies that they are the same."

test_dotizeAugmentUniq :: Test
test_dotizeAugmentUniq
  = Test { name       = "Unique edges in augmented FGL Graphs"
         , lookupName = "augmentuniq"
         , desc       = dsc
         , test       = quickCheckResult prop
         }
  where
    prop :: Gr Char Double -> Bool
    prop = prop_dotizeAugmentUniq

    dsc = "When augmenting a graph with multiple edges, as long as no\n\
           \Attributes are provided that override the default settings,\n\
           \then each edge between two nodes should have a unique position\n\
           \Attribute, etc."

test_findAllNodes :: Test
test_findAllNodes
  = Test { name       = "Ensure all nodes are found in a DotGraph"
         , lookupName = "findnodes"
         , desc       = dsc
         , test       = quickCheckResult prop
         }
  where
    prop :: Gr () () -> Bool
    prop = prop_findAllNodes

    dsc = "nodeInformation should find all nodes in a DotGraph;\n\
           \this is tested by converting an FGL graph and comparing\n\
           \the nodes it should have to those that are found."

test_findAllNodesG :: Test
test_findAllNodesG
  = Test { name       = "Ensure all nodes are found in a GDotGraph"
         , lookupName = "findnodesg"
         , desc       = dsc
         , test       = quickCheckResult prop
         }
  where
    prop :: Gr () () -> Bool
    prop = prop_findAllNodesG

    dsc = "nodeInformation should find all nodes in a GDotGraph;\n\
           \this is tested by converting an FGL graph and comparing\n\
           \the nodes it should have to those that are found."

test_findAllNodesE :: Test
test_findAllNodesE
  = Test { name       = "Ensure all nodes are found in a node-less DotGraph"
         , lookupName = "findedgelessnodes"
         , desc       = dsc
         , test       = quickCheckResult prop
         }
  where
    prop :: Gr () () -> Bool
    prop = prop_findAllNodesE

    dsc = "nodeInformation should find all nodes in a DotGraph,\n\
           \even if there are no explicit nodes in that graph.\n\
           \This is tested by converting an FGL graph and comparing\n\
           \the nodes it should have to those that are found."

test_findAllNodesEG :: Test
test_findAllNodesEG
  = Test { name       = "Ensure all nodes are found in a node-less GDotGraph"
         , lookupName = "findedgelessnodesg"
         , desc       = dsc
         , test       = quickCheckResult prop
         }
  where
    prop :: Gr () () -> Bool
    prop = prop_findAllNodesEG

    dsc = "nodeInformation should find all nodes in a GDotGraph,\n\
           \even if there are no explicit nodes in that graph.\n\
           \This is tested by converting an FGL graph and comparing\n\
           \the nodes it should have to those that are found."

test_findAllEdges :: Test
test_findAllEdges
  = Test { name       = "Ensure all edges are found in a DotGraph"
         , lookupName = "findedges"
         , desc       = dsc
         , test       = quickCheckResult prop
         }
  where
    prop :: Gr () () -> Bool
    prop = prop_findAllEdges

    dsc = "nodeInformation should find all edges in a DotGraph;\n\
           \this is tested by converting an FGL graph and comparing\n\
           \the edges it should have to those that are found."

test_findAllEdgesG :: Test
test_findAllEdgesG
  = Test { name       = "Ensure all edges are found in a GDotGraph"
         , lookupName = "findedgesg"
         , desc       = dsc
         , test       = quickCheckResult prop
         }
  where
    prop :: Gr () () -> Bool
    prop = prop_findAllEdgesG

    dsc = "nodeInformation should find all edges in a GDotGraph;\n\
           \this is tested by converting an FGL graph and comparing\n\
           \the edges it should have to those that are found."

test_noGraphInfo :: Test
test_noGraphInfo
  = Test { name       = "Plain DotGraphs should have no structural information"
         , lookupName = "nographinfo"
         , desc       = dsc
         , test       = quickCheckResult prop
         }
  where
    prop :: Gr () () -> Bool
    prop = prop_noGraphInfo

    dsc = "When converting a Graph to a DotGraph, there should be no\n\
           \clusters or global attributes."

test_noGraphInfoG :: Test
test_noGraphInfoG
  = Test { name       = "Plain GDotGraphs should have no structural information"
         , lookupName = "nographinfog"
         , desc       = dsc
         , test       = quickCheckResult prop
         }
  where
    prop :: Gr () () -> Bool
    prop = prop_noGraphInfoG

    dsc = "When converting a Graph to a GDotGraph, there should be no\n\
           \clusters or global attributes."

test_canonicalise :: Test
test_canonicalise
  = Test { name = "Canonicalisation should be idempotent"
         , lookupName = "canonicalise"
         , desc = dsc
         , test = quickCheckResult prop
         }
  where
    prop :: GDotGraph Int -> Bool
    prop = prop_canonicalise

    dsc = "Repeated application of canonicalise shouldn't have any further affect."

test_transitive :: Test
test_transitive
  = Test { name = "Transitive reduction should be idempotent"
         , lookupName = "transitive"
         , desc = dsc
         , test = quickCheckResult prop
         }
  where
    prop :: GDotGraph Int -> Bool
    prop = prop_transitive

    dsc = "Repeated application of transitiveReduction shouldn't have any further affect."
