{-# LANGUAGE
OverloadedStrings,
TemplateHaskell,
RecordWildCards,
RankNTypes,
NoImplicitPrelude
  #-}


module Main (main) where


-- General
import BasePrelude hiding (Category)
-- Monads and monad transformers
import Control.Monad.State
-- Lenses
import Lens.Micro.Platform
-- Text
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Lazy as TL
import Data.Text.Format hiding (format)
import qualified Data.Text.Format as Format
import Data.Text.Format.Params (Params)
-- Web
import Lucid hiding (for_)
import Web.Spock hiding (get)
import qualified Web.Spock as Spock
import Network.Wai.Middleware.Static


-- | Unique id, used for categories and items.
type UID = Int

data ItemKind = HackageLibrary | Library | Unknown

data Item = Item {
  _itemId :: UID,
  _name   :: Text,
  _pros   :: [Text],
  _cons   :: [Text],
  _link   :: Maybe Text,
  _kind   :: ItemKind }

makeLenses ''Item

data Category = Category {
  _catId :: UID,
  _title :: Text,
  _items :: [Item] }

makeLenses ''Category

data S = S {
  _nextId :: UID,
  _categories :: [Category] }

makeLenses ''S

categoryById :: UID -> Lens' S Category
categoryById uid = singular $
  categories.each . filtered ((== uid) . view catId)

itemById :: UID -> Lens' S Item
itemById uid = singular $
  categories.each . items.each . filtered ((== uid) . view itemId)

newId :: IORef S -> IO UID
newId s = do
  uid <- view nextId <$> readIORef s
  modifyIORef s (nextId %~ succ)
  return uid

emptyState :: S
emptyState = S {
  _nextId = 0,
  _categories = [] }

sampleState :: S
sampleState = S {
  _nextId = 3,
  _categories = [
    Category {
      _catId = 0,
      _title = "lenses",
      _items = [
        Item {
          _itemId = 1,
          _name   = "lens",
          _pros   = ["the standard lenses library", "batteries included"],
          _cons   = ["huge"],
          _link   = Nothing,
          _kind   = HackageLibrary },
        Item {
          _itemId = 2,
          _name   = "microlens",
          _pros   = ["very small", "good for libraries"],
          _cons   = ["doesn't have advanced features"],
          _link   = Nothing,
          _kind   = HackageLibrary }
      ] }
  ] }

main :: IO ()
main = runSpock 8080 $ spockT id $ do
  middleware (staticPolicy (addBase "static"))
  stateVar <- liftIO $ newIORef sampleState
  let withS f = liftIO $ atomicModifyIORef' stateVar (swap . runState f)

  Spock.get root $ do
    s <- liftIO $ readIORef stateVar
    lucid $ renderRoot s

  -- The “/add” methods return rendered parts of the structure (added
  -- categories, changed items, etc) so that the Javascript part could take
  -- them and inject into the page. We don't want to duplicate rendering on
  -- server side and on client side.

  -- TODO: rename methods to “category/add” etc
  -- TODO: move Javascript here
  Spock.post "/add/category" $ do
    title' <- param' "title"
    id' <- liftIO (newId stateVar)
    let newCategory = Category {
          _catId = id',
          _title = title',
          _items = [] }
    withS $
      categories %= (++ [newCategory])
    lucid $ renderCategory newCategory

  Spock.post ("/add/item/library" <//> var) $ \catId' -> do
    name' <- param' "name"
    id' <- liftIO (newId stateVar)
    let newItem = Item {
          _itemId = id',
          _name   = name',
          _pros   = [],
          _cons   = [],
          _link   = Nothing,
          _kind   = HackageLibrary }
    -- TODO: maybe do something if the category doesn't exist (e.g. has been
    -- already deleted)
    withS $
      categoryById catId' . items %= (++ [newItem])
    lucid $ renderItem newItem

  Spock.post ("/add/pros" <//> var) $ \itemId' -> do
    content <- param' "content"    
    changedItem <- withS $ do
      itemById itemId' . pros %= (++ [content])
      use (itemById itemId')
    lucid $ renderItem changedItem

  Spock.post ("/add/cons" <//> var) $ \itemId' -> do
    content <- param' "content"    
    changedItem <- withS $ do
      itemById itemId' . cons %= (++ [content])
      use (itemById itemId')
    lucid $ renderItem changedItem

  Spock.post ("/edit/category" <//> var <//> "title") $ \catId' -> do
    title' <- param' "title"
    changedCategory <- withS $ do
      categoryById catId' . title .= title'
      use (categoryById catId')
    lucid $ renderCategoryHeading changedCategory

  Spock.get ("/edit/category" <//> var <//> "title/edit") $ \catId' -> do
    category <- withS $ use (categoryById catId')
    lucid $ renderCategoryHeadingEdit category

  Spock.get ("/edit/category" <//> var <//> "title/cancel") $ \catId' -> do
    category <- withS $ use (categoryById catId')
    lucid $ renderCategoryHeading category

renderRoot :: S -> Html ()
renderRoot s = do
  includeJS "https://ajax.googleapis.com/ajax/libs/jquery/2.2.0/jquery.min.js"
  includeJS "/js.js"
  includeCSS "/css.css"
  div_ [id_ "categories"] $ do
    mapM_ renderCategory (s ^. categories)
  let handler = "addCategory(this.value);"
  input_ [type_ "text", placeholder_ "new category", submitFunc handler]

renderCategoryHeading :: Category -> Html ()
renderCategoryHeading category =
  h2_ $ do
    -- TODO: make category headings anchor links
    toHtml (category^.title)
    " "
    textButton "edit" $ format "startCategoryHeadingEditing({});"
                               [category^.catId]

renderCategoryHeadingEdit :: Category -> Html ()
renderCategoryHeadingEdit category =
  h2_ $ do
    let handler = format "finishCategoryHeadingEditing({}, this.value);"
                         [category^.catId]
    input_ [type_ "text", value_ (category^.title), submitFunc handler]
    " "
    textButton "cancel" $ format "cancelCategoryHeadingEditing({});"
                                 [category^.catId]

renderCategory :: Category -> Html ()
renderCategory category =
  div_ [id_ (format "cat{}" [category^.catId])] $ do
    renderCategoryHeading category
    -- Note: if you change anything here, look at js.js/addLibrary to see
    -- whether it has to be updated.
    div_ [class_ "items"] $
      mapM_ renderItem (category^.items)
    let handler = format "addLibrary({}, this.value);" [category^.catId]
    input_ [type_ "text", placeholder_ "new item", submitFunc handler]

-- TODO: when the link for a HackageLibrary isn't empty, show it separately
-- (as “site”), don't replace the Hackage link
renderItem :: Item -> Html ()
renderItem item =
  div_ [class_ "item", id_ (format "item{}" [item^.itemId])] $ do
    h3_ itemHeader
    div_ [class_ "pros-cons"] $ do
      div_ [class_ "pros"] $ do
        p_ "Pros:"
        ul_ $ mapM_ (li_ . toHtml) (item^.pros)
        let handler = format "addPros({}, this.value);" [item^.itemId]
        input_ [type_ "text", placeholder_ "add pros", submitFunc handler]
      div_ [class_ "cons"] $ do
        p_ "Cons:"
        ul_ $ mapM_ (li_ . toHtml) (item^.cons)
        let handler = format "addCons({}, this.value);" [item^.itemId]
        input_ [type_ "text", placeholder_ "add cons", submitFunc handler]
  where
    hackageLink = format "https://hackage.haskell.org/package/{}"
                         [item^.name]
    itemHeader = case (item^.link, item^.kind) of
      (Just l, _) ->
        a_ [href_ l] (toHtml (item^.name))
      (Nothing, HackageLibrary) ->
        a_ [href_ hackageLink] (toHtml (item^.name))
      _otherwise -> toHtml (item^.name)

-- Utils

includeJS :: Text -> Html ()
includeJS url = with (script_ "") [src_ url]

includeCSS :: Text -> Html ()
includeCSS url = link_ [rel_ "stylesheet", type_ "text/css", href_ url]

submitFunc :: Text -> Attribute
submitFunc f = onkeyup_ $ format
  "if (event.keyCode == 13) {\
  \  {}\
  \  this.value = ''; }"
  [f]

-- A text button looks like “[cancel]”
textButton
  :: Text    -- ^ Button text
  -> Text    -- ^ Onclick handler
  -> Html ()
textButton caption handler = span_ $ do
  "["
  a_ [href_ "javascript:void(0)", onclick_ handler] (toHtml caption)
  "]"

lucid :: Html a -> ActionT IO a
lucid = html . TL.toStrict . renderText

-- | Format a string (a bit 'Text.Printf.printf' but with different syntax).
format :: Params ps => Format -> ps -> Text
format f ps = TL.toStrict (Format.format f ps)
