{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE ConstraintKinds #-}
-- | Warning: This module should be considered highly experimental.
module Data.Sequences where

import Data.Monoid
import Data.MonoTraversable
import Data.Int (Int64, Int)
import qualified Data.List as List
import qualified Control.Monad (filterM, replicateM)
import Prelude (Bool (..), Monad (..), Maybe (..), Ordering (..), Ord (..), Eq (..), Functor (..), fromIntegral, otherwise, (-), not, fst, snd, Integral)
import Data.Char (Char)
import Data.Word (Word8)
import qualified Data.ByteString as S
import qualified Data.ByteString.Lazy as L
import qualified Data.Text as T
import qualified Data.Text.Lazy as TL
import Control.Category
import Control.Arrow ((***), second)
import Control.Monad (liftM)
import qualified Data.Sequence as Seq
import qualified Data.Vector as V
import qualified Data.Vector.Unboxed as U
import qualified Data.Vector.Storable as VS
import qualified Data.Text.Encoding as T
import qualified Data.Text.Lazy.Encoding as TL
import Data.Text.Encoding.Error (lenientDecode)
import GHC.Exts (Constraint)
import qualified Data.Set as Set
import qualified Data.HashSet as HashSet
import Data.Hashable (Hashable)

-- | Laws:
--
-- > fromList . toList = id
-- > fromList (x <> y) = fromList x <> fromList y
-- > otoList (fromList x <> fromList y) = x <> y
class (Monoid seq, MonoTraversable seq, Integral (Index seq)) => IsSequence seq where
    type Index seq
    singleton :: Element seq -> seq

    fromList :: [Element seq] -> seq
    fromList = mconcat . fmap singleton

    replicate :: Index seq -> Element seq -> seq
    replicate i = fromList . List.genericReplicate i

    replicateM :: Monad m => Index seq -> m (Element seq) -> m seq
    replicateM i = liftM fromList . Control.Monad.replicateM (fromIntegral i)

    filter :: (Element seq -> Bool) -> seq -> seq
    filter f = fromList . List.filter f . otoList

    filterM :: Monad m => (Element seq -> m Bool) -> seq -> m seq
    filterM f = Control.Monad.liftM fromList . filterM f . otoList

    intersperse :: Element seq -> seq -> seq
    intersperse e = fromList . List.intersperse e . otoList

    break :: (Element seq -> Bool) -> seq -> (seq, seq)
    break f = (fromList *** fromList) . List.break f . otoList

    span :: (Element seq -> Bool) -> seq -> (seq, seq)
    span f = (fromList *** fromList) . List.span f . otoList

    dropWhile :: (Element seq -> Bool) -> seq -> seq
    dropWhile f = fromList . List.dropWhile f . otoList
    
    takeWhile :: (Element seq -> Bool) -> seq -> seq
    takeWhile f = fromList . List.takeWhile f . otoList

    splitAt :: Index seq -> seq -> (seq, seq)
    splitAt i = (fromList *** fromList) . List.genericSplitAt i . otoList

    take :: Index seq -> seq -> seq
    take i = fst . splitAt i

    drop :: Index seq -> seq -> seq
    drop i = snd . splitAt i

    -- FIXME split :: (Element seq -> Bool) -> seq -> [seq]

    reverse :: seq -> seq
    reverse = fromList . List.reverse . otoList

    find :: (Element seq -> Bool) -> seq -> Maybe (Element seq)
    find f = List.find f . otoList
    
    partition :: (Element seq -> Bool) -> seq -> (seq, seq)
    partition f = (fromList *** fromList) . List.partition f . otoList
    
    sortBy :: (Element seq -> Element seq -> Ordering) -> seq -> seq
    sortBy f = fromList . List.sortBy f . otoList
    
    cons :: Element seq -> seq -> seq
    cons e = fromList . (e:) . otoList

    uncons :: seq -> Maybe (Element seq, seq)
    uncons = fmap (second fromList) . uncons . otoList

    groupBy :: (Element seq -> Element seq -> Bool) -> seq -> [seq]
    groupBy f = fmap fromList . List.groupBy f . otoList

    -- | Similar to standard 'groupBy', but operates on the whole collection, 
    -- not just the consecutive items.
    groupAllOn :: Eq b => (Element seq -> b) -> seq -> [seq]
    groupAllOn f = fmap fromList . groupAllOn f . otoList

    subsequences :: seq -> [seq]
    subsequences = List.map fromList . List.subsequences . otoList

    permutations :: seq -> [seq]
    permutations = List.map fromList . List.permutations . otoList

instance IsSequence [a] where
    type Index [a] = Int
    singleton = return
    fromList = id
    {-# INLINE fromList #-}
    replicate = List.replicate
    replicateM = Control.Monad.replicateM
    filter = List.filter
    filterM = Control.Monad.filterM
    intersperse = List.intersperse
    break = List.break
    span = List.span
    dropWhile = List.dropWhile
    takeWhile = List.takeWhile
    splitAt = List.splitAt
    take = List.take
    drop = List.drop
    reverse = List.reverse
    find = List.find
    partition = List.partition
    sortBy = List.sortBy
    cons = (:)
    uncons [] = Nothing
    uncons (x:xs) = Just (x, xs)
    groupBy = List.groupBy
    groupAllOn f (head : tail) =
        (head : matches) : groupAllOn f nonMatches
      where
        (matches, nonMatches) = partition ((== f head) . f) tail
    groupAllOn _ [] = []

instance IsSequence S.ByteString where
    type Index S.ByteString = Int
    singleton = S.singleton
    fromList = S.pack
    replicate = S.replicate
    filter = S.filter
    intersperse = S.intersperse
    break = S.break
    span = S.span
    dropWhile = S.dropWhile
    takeWhile = S.takeWhile
    splitAt = S.splitAt
    take = S.take
    drop = S.drop
    reverse = S.reverse
    find = S.find
    partition = S.partition
    cons = S.cons
    uncons = S.uncons
    groupBy = S.groupBy
    -- sortBy

instance IsSequence T.Text where
    type Index T.Text = Int
    singleton = T.singleton
    fromList = T.pack
    replicate i c = T.replicate i (T.singleton c)
    filter = T.filter
    intersperse = T.intersperse
    break = T.break
    span = T.span
    dropWhile = T.dropWhile
    takeWhile = T.takeWhile
    splitAt = T.splitAt
    take = T.take
    drop = T.drop
    reverse = T.reverse
    find = T.find
    partition = T.partition
    cons = T.cons
    uncons = T.uncons
    groupBy = T.groupBy
    -- sortBy

instance IsSequence L.ByteString where
    type Index L.ByteString = Int64
    singleton = L.singleton
    fromList = L.pack
    replicate = L.replicate
    filter = L.filter
    intersperse = L.intersperse
    break = L.break
    span = L.span
    dropWhile = L.dropWhile
    takeWhile = L.takeWhile
    splitAt = L.splitAt
    take = L.take
    drop = L.drop
    reverse = L.reverse
    find = L.find
    partition = L.partition
    cons = L.cons
    uncons = L.uncons
    groupBy = L.groupBy
    -- sortBy

instance IsSequence TL.Text where
    type Index TL.Text = Int64
    singleton = TL.singleton
    fromList = TL.pack
    replicate i c = TL.replicate i (TL.singleton c)
    filter = TL.filter
    intersperse = TL.intersperse
    break = TL.break
    span = TL.span
    dropWhile = TL.dropWhile
    takeWhile = TL.takeWhile
    splitAt = TL.splitAt
    take = TL.take
    drop = TL.drop
    reverse = TL.reverse
    find = TL.find
    partition = TL.partition
    cons = TL.cons
    uncons = TL.uncons
    groupBy = TL.groupBy
    -- sortBy


instance IsSequence (Seq.Seq a) where
    type Index (Seq.Seq a) = Int
    singleton = Seq.singleton
    fromList = Seq.fromList
    replicate = Seq.replicate
    replicateM = Seq.replicateM
    filter = Seq.filter
    --filterM = Seq.filterM
    --intersperse = Seq.intersperse
    break = Seq.breakl
    span = Seq.spanl
    dropWhile = Seq.dropWhileL
    takeWhile = Seq.takeWhileL
    splitAt = Seq.splitAt
    take = Seq.take
    drop = Seq.drop
    reverse = Seq.reverse
    --find = Seq.find
    partition = Seq.partition
    sortBy = Seq.sortBy
    cons = (Seq.<|)
    uncons s =
        case Seq.viewl s of
            Seq.EmptyL -> Nothing
            x Seq.:< xs -> Just (x, xs)
    --groupBy = Seq.groupBy

instance IsSequence (V.Vector a) where
    type Index (V.Vector a) = Int
    singleton = V.singleton
    fromList = V.fromList
    replicate = V.replicate
    replicateM = V.replicateM
    filter = V.filter
    filterM = V.filterM
    --intersperse = V.intersperse
    break = V.break
    span = V.span
    dropWhile = V.dropWhile
    takeWhile = V.takeWhile
    splitAt = V.splitAt
    take = V.take
    drop = V.drop
    reverse = V.reverse
    find = V.find
    partition = V.partition
    --sortBy = V.sortBy
    cons = V.cons
    uncons v
        | V.null v = Nothing
        | otherwise = Just (V.head v, V.tail v)
    --groupBy = V.groupBy

instance U.Unbox a => IsSequence (U.Vector a) where
    type Index (U.Vector a) = Int
    singleton = U.singleton
    fromList = U.fromList
    replicate = U.replicate
    replicateM = U.replicateM
    filter = U.filter
    filterM = U.filterM
    --intersperse = U.intersperse
    break = U.break
    span = U.span
    dropWhile = U.dropWhile
    takeWhile = U.takeWhile
    splitAt = U.splitAt
    take = U.take
    drop = U.drop
    reverse = U.reverse
    find = U.find
    partition = U.partition
    --sortBy = U.sortBy
    cons = U.cons
    uncons v
        | U.null v = Nothing
        | otherwise = Just (U.head v, U.tail v)
    --groupBy = U.groupBy

instance VS.Storable a => IsSequence (VS.Vector a) where
    type Index (VS.Vector a) = Int
    singleton = VS.singleton
    fromList = VS.fromList
    replicate = VS.replicate
    replicateM = VS.replicateM
    filter = VS.filter
    filterM = VS.filterM
    --intersperse = U.intersperse
    break = VS.break
    span = VS.span
    dropWhile = VS.dropWhile
    takeWhile = VS.takeWhile
    splitAt = VS.splitAt
    take = VS.take
    drop = VS.drop
    reverse = VS.reverse
    find = VS.find
    partition = VS.partition
    --sortBy = U.sortBy
    cons = VS.cons
    uncons v
        | VS.null v = Nothing
        | otherwise = Just (VS.head v, VS.tail v)
    --groupBy = U.groupBy

class (IsSequence seq, Eq (Element seq)) => EqSequence seq where
    stripPrefix :: seq -> seq -> Maybe seq
    stripPrefix x y = fmap fromList (otoList x `stripPrefix` otoList y)
    
    isPrefixOf :: seq -> seq -> Bool
    isPrefixOf x y = otoList x `isPrefixOf` otoList y
    
    stripSuffix :: seq -> seq -> Maybe seq
    stripSuffix x y = fmap fromList (otoList x `stripSuffix` otoList y)

    isSuffixOf :: seq -> seq -> Bool
    isSuffixOf x y = otoList x `isSuffixOf` otoList y

    isInfixOf :: seq -> seq -> Bool
    isInfixOf x y = otoList x `isInfixOf` otoList y

    group :: seq -> [seq]
    group = groupBy (==)
    
    -- | Similar to standard 'group', but operates on the whole collection, 
    -- not just the consecutive items.
    groupAll :: seq -> [seq]
    groupAll = groupAllOn id

    elem :: Element seq -> seq -> Bool
    elem e = List.elem e . otoList

    notElem :: Element seq -> seq -> Bool
    notElem e = List.notElem e . otoList

instance Eq a => EqSequence [a] where
    stripPrefix = List.stripPrefix
    isPrefixOf = List.isPrefixOf
    stripSuffix x y = fmap reverse (List.stripPrefix (reverse x) (reverse y))
    isSuffixOf x y = List.isPrefixOf (reverse x) (reverse y)
    isInfixOf = List.isInfixOf
    group = List.group
    elem = List.elem
    notElem = List.notElem

instance EqSequence S.ByteString where
    stripPrefix x y
        | x `S.isPrefixOf` y = Just (S.drop (S.length x) y)
        | otherwise = Nothing
    isPrefixOf = S.isPrefixOf
    stripSuffix x y
        | x `S.isSuffixOf` y = Just (S.take (S.length y - S.length x) y)
        | otherwise = Nothing
    isSuffixOf = S.isSuffixOf
    isInfixOf = S.isInfixOf
    group = S.group
    elem = S.elem
    notElem = S.notElem

instance EqSequence L.ByteString where
    stripPrefix x y
        | x `L.isPrefixOf` y = Just (L.drop (L.length x) y)
        | otherwise = Nothing
    isPrefixOf = L.isPrefixOf
    stripSuffix x y
        | x `L.isSuffixOf` y = Just (L.take (L.length y - L.length x) y)
        | otherwise = Nothing
    isSuffixOf = L.isSuffixOf
    isInfixOf x y = L.unpack x `List.isInfixOf` L.unpack y
    group = L.group
    elem = L.elem
    notElem = L.notElem

instance EqSequence T.Text where
    stripPrefix = T.stripPrefix
    isPrefixOf = T.isPrefixOf
    stripSuffix = T.stripSuffix
    isSuffixOf = T.isSuffixOf
    isInfixOf = T.isInfixOf
    group = T.group

instance EqSequence TL.Text where
    stripPrefix = TL.stripPrefix
    isPrefixOf = TL.isPrefixOf
    stripSuffix = TL.stripSuffix
    isSuffixOf = TL.isSuffixOf
    isInfixOf = TL.isInfixOf
    group = TL.group

instance Eq a => EqSequence (Seq.Seq a)
instance Eq a => EqSequence (V.Vector a)
instance (Eq a, U.Unbox a) => EqSequence (U.Vector a)
instance (Eq a, VS.Storable a) => EqSequence (VS.Vector a)

class (EqSequence seq, Ord (Element seq)) => OrdSequence seq where
    sort :: seq -> seq
    sort = fromList . List.sort . otoList

instance Ord a => OrdSequence [a] where
    sort = List.sort

instance OrdSequence S.ByteString where
    sort = S.sort

instance OrdSequence L.ByteString
instance OrdSequence T.Text
instance OrdSequence TL.Text
instance Ord a => OrdSequence (Seq.Seq a)
instance Ord a => OrdSequence (V.Vector a)
instance (Ord a, U.Unbox a) => OrdSequence (U.Vector a)
instance (Ord a, VS.Storable a) => OrdSequence (VS.Vector a)

class (IsSequence l, IsSequence s) => LazySequence l s | l -> s, s -> l where
    toChunks :: l -> [s]
    fromChunks :: [s] -> l
    toStrict :: l -> s
    fromStrict :: s -> l

instance LazySequence L.ByteString S.ByteString where
    toChunks = L.toChunks
    fromChunks = L.fromChunks
    toStrict = mconcat . L.toChunks
    fromStrict = L.fromChunks . return

instance LazySequence TL.Text T.Text where
    toChunks = TL.toChunks
    fromChunks = TL.fromChunks
    toStrict = TL.toStrict
    fromStrict = TL.fromStrict

class (IsSequence t, IsSequence b) => Textual t b | t -> b, b -> t where
    words :: t -> [t]
    unwords :: [t] -> t
    lines :: t -> [t]
    unlines :: [t] -> t
    encodeUtf8 :: t -> b
    decodeUtf8 :: b -> t
    toLower :: t -> t
    toUpper :: t -> t
    toCaseFold :: t -> t

instance (c ~ Char, w ~ Word8) => Textual [c] [w] where
    words = List.words
    unwords = List.unwords
    lines = List.lines
    unlines = List.unlines
    encodeUtf8 = L.unpack . TL.encodeUtf8 . TL.pack
    decodeUtf8 = TL.unpack . TL.decodeUtf8With lenientDecode . L.pack
    toLower = TL.unpack . TL.toLower . TL.pack
    toUpper = TL.unpack . TL.toUpper . TL.pack
    toCaseFold = TL.unpack . TL.toCaseFold . TL.pack

instance Textual T.Text S.ByteString where
    words = T.words
    unwords = T.unwords
    lines = T.lines
    unlines = T.unlines
    encodeUtf8 = T.encodeUtf8
    decodeUtf8 = T.decodeUtf8With lenientDecode
    toLower = T.toLower
    toUpper = T.toUpper
    toCaseFold = T.toCaseFold

instance Textual TL.Text L.ByteString where
    words = TL.words
    unwords = TL.unwords
    lines = TL.lines
    unlines = TL.unlines
    encodeUtf8 = TL.encodeUtf8
    decodeUtf8 = TL.decodeUtf8With lenientDecode
    toLower = TL.toLower
    toUpper = TL.toUpper
    toCaseFold = TL.toCaseFold

-- | A @map@-like function which doesn't obey the @Functor@ laws,
-- and/or requires extra constraints on the contained values.
class LooseMap t where
    type LooseMapConstraint t e :: Constraint
    looseMap :: (LooseMapConstraint t e1, LooseMapConstraint t e2) => (e1 -> e2) -> t e1 -> t e2
instance LooseMap Set.Set where
    type LooseMapConstraint Set.Set a = Ord a
    looseMap = Set.map
instance LooseMap HashSet.HashSet where
    type LooseMapConstraint HashSet.HashSet a = (Eq a, Hashable a)
    looseMap = HashSet.map
instance LooseMap U.Vector where
    type LooseMapConstraint U.Vector a = U.Unbox a
    looseMap = U.map
instance LooseMap VS.Vector where
    type LooseMapConstraint VS.Vector a = VS.Storable a
    looseMap = VS.map
