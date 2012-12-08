{-# LANGUAGE DeriveDataTypeable #-}

module Language.Sexp.Parser (
        Sexp(..), sexpParser,
        ParseException(..), parse, parseExn
    ) where

import Control.Applicative ( (<$>), (<*), (*>), many )
import Control.Exception ( Exception )
import qualified Control.Exception as CE
import Data.Attoparsec.ByteString.Lazy ( Parser, Result(..) )
import Data.Attoparsec.ByteString.Char8 ( char, space, notInClass, (<?>) )
import qualified Data.Attoparsec.ByteString.Char8 as AC
import Data.Attoparsec.Combinator ( choice )
import qualified Data.Attoparsec.ByteString.Lazy as A
import Data.ByteString.Lazy as BS
import Data.Sexp ( Sexp(..) )
import Data.Typeable ( Typeable )

data ParseException = ParseException String ByteString
                    deriving ( Show, Typeable )

instance Exception ParseException

-- | Parse S-Expressions from a lazy 'ByteString'.  If the parse was
-- successful, @Right sexps@ is returned; otherwise, @Left (errorMsg,
-- leftover)@ is returned.
parse :: ByteString -> Either (String, ByteString) [Sexp]
parse = resultToEither . A.parse (many space *> many sexpParser)
  where
    resultToEither (Fail leftover _ctxs reason) =
        Left (reason, leftover)
    resultToEither (Done leftover sexps) =
        if BS.null leftover
        then Right sexps
        else Left ("garbage at end", leftover)

-- | A variant of 'parse' that throws a 'ParseException' if the parse
-- fails.
parseExn :: ByteString -> [Sexp]
parseExn text =
    case parse text of
        Left (reason, leftover) -> CE.throw (ParseException reason leftover)
        Right sexps             -> sexps

-- | A parser for S-Expressions.  Ignoring whitespace, we follow the
-- following EBNF:
--
-- SEXP ::= '(' ATOM* ')' | ATOM
-- ATOM ::= '"' [^"]* '"' | [^ \t\n()]+
--
sexpParser :: Parser Sexp
sexpParser =
    choice [ list <?> "list"
           , atom <?> "atom"
           ]
  where
    list = List <$> (char '(' *> many space *> many sexpParser <* char ')') <* many space
    atom = Atom <$> (choice [string, anything]) <* many space
    string = fromStrict <$> (char '"' *> AC.scan False escapedStringScanner <* char '"')
    anything = fromStrict <$> AC.takeWhile1 (notInClass " \t\n()")

    -- Scan an escaped string.
    escapedStringScanner :: Bool -> Char -> Maybe Bool
    escapedStringScanner True _     = Just False
    escapedStringScanner False '\\' = Just True
    escapedStringScanner False '"'  = Nothing
    escapedStringScanner False _    = Just False
