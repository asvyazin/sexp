{-# LANGUAGE OverloadedStrings #-}

module Main where

import Control.Applicative ( (<$>) )
import Data.ByteString.Lazy.Char8 hiding ( map, concat )
import Data.Monoid
import Data.Sexp
import Language.Sexp
import Test.Framework
import Test.Framework.Providers.HUnit
import Test.Framework.Providers.QuickCheck2
import Test.HUnit hiding ( Test )
-- import Test.QuickCheck

main :: IO ()
main = flip defaultMainWithOpts mempty
       (concat [parseTests, basicTypeTests, idTests])

--------------------------------
-- HUnit Tests
--------------------------------

parseTests :: [Test]
parseTests = map (\(n, s, t) -> testCase n (parseTest s t)) positiveSexps

parseTest :: ByteString -> [Sexp] -> Assertion
parseTest text sexp = assertEqual "" sexp (parseExn text)

positiveSexps :: [(String, ByteString, [Sexp])]
positiveSexps =
    [ ("empty", "", [])
    , ("empty-list", "()", [List []])
    , ("empty-lists", "() ()", [List [], List []])
    , ("nested-lists", "(() ())", [List [List [], List []]])
    , ("list-whitespace", "  ( ( )( ) ) ", [List [List [], List []]])
    , ("atom", "a", [Atom "a"])
    , ("singleton", "(ab)", [List [Atom "ab"]])
    , ("atom-list", "(a b c)", [List [Atom "a", Atom "b", Atom "c"]])
    , ("nested-atom-lists", "(a ((b c) (d)))", [List [ Atom "a"
                                                     , List [ List [ Atom "b"
                                                                   , Atom "c"]
                                                            , List [Atom "d"]] ] ])
    , ("atom-whitespace", "( a b  c ) (d)", [List [ Atom "a"
                                                   , Atom "b"
                                                   , Atom "c" ]
                                             , List [Atom "d"]])
    ]

basicTypeTests :: [Test]
basicTypeTests =
    [ testCase "int" (assertEqual "" (Just (42 :: Int)) (fromSexp (Atom "42")))
    , testCase "integer" (assertEqual "" (Just (42 :: Integer)) (fromSexp (Atom "42")))
    , testCase "double" (assertEqual "" (Just (42.2 :: Double)) (fromSexp (Atom "42.2")))
    , testCase "string" (assertEqual "" (Just ("ana" :: ByteString)) (fromSexp (Atom "ana")))
    ]

--------------------------------
-- QuickCheck Properties
--------------------------------

idTests :: [Test]
idTests =
    [ testProperty "idInt" (\x -> Just (x :: Int) == fromSexp (toSexp x))
    , testProperty "idInteger" (\x -> Just (x :: Integer) == fromSexp (toSexp x))
    , testProperty "idDouble" (\x -> Just (x :: Double) == fromSexp (toSexp x))
    , testProperty "idString" (\x -> Just (x :: String) == (unpack <$> fromSexp (toSexp (pack x))))
    ]