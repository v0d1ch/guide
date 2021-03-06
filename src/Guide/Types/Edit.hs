{-# LANGUAGE TypeFamilies #-}


{- |
Types for edits.

Every content edit is associated with an 'Edit', which is stored in the
database and can be undone. In addition, each edit has a corresponding
'EditDetails' (which stores IP, date, and ID of an edit).
-}
module Guide.Types.Edit
(
  Edit(..),
  isVacuousEdit,
  EditDetails(..),
)
where


import Imports

-- Containers
import qualified Data.Set as S
-- Network
import Data.IP
-- acid-state
import Data.SafeCopy hiding (kind)

import Guide.Utils
import Guide.SafeCopy
import Guide.Types.Core


-- | Edits made by users. It should always be possible to undo an edit.
data Edit
  -- Add
  = Edit'AddCategory {
      editCategoryUid   :: Uid Category,
      editCategoryTitle :: Text }
  | Edit'AddItem {
      editCategoryUid   :: Uid Category,
      editItemUid       :: Uid Item,
      editItemName      :: Text }
  | Edit'AddPro {
      editItemUid       :: Uid Item,
      editTraitId       :: Uid Trait,
      editTraitContent  :: Text }
  | Edit'AddCon {
      editItemUid       :: Uid Item,
      editTraitId       :: Uid Trait,
      editTraitContent  :: Text }

  -- Change category properties
  | Edit'SetCategoryTitle {
      editCategoryUid       :: Uid Category,
      editCategoryTitle     :: Text,
      editCategoryNewTitle  :: Text }
  | Edit'SetCategoryGroup {
      editCategoryUid       :: Uid Category,
      editCategoryGroup     :: Text,
      editCategoryNewGroup  :: Text }
  | Edit'SetCategoryNotes {
      editCategoryUid       :: Uid Category,
      editCategoryNotes     :: Text,
      editCategoryNewNotes  :: Text }
  | Edit'SetCategoryStatus {
      editCategoryUid       :: Uid Category,
      editCategoryStatus    :: CategoryStatus,
      editCategoryNewStatus :: CategoryStatus }
  | Edit'ChangeCategoryEnabledSections {
      editCategoryUid             :: Uid Category,
      editCategoryEnableSections  :: Set ItemSection,
      editCategoryDisableSections :: Set ItemSection }

  -- Change item properties
  | Edit'SetItemName {
      editItemUid            :: Uid Item,
      editItemName           :: Text,
      editItemNewName        :: Text }
  | Edit'SetItemLink {
      editItemUid            :: Uid Item,
      editItemLink           :: Maybe Url,
      editItemNewLink        :: Maybe Url }
  | Edit'SetItemGroup {
      editItemUid            :: Uid Item,
      editItemGroup          :: Maybe Text,
      editItemNewGroup       :: Maybe Text }
  | Edit'SetItemKind {
      editItemUid            :: Uid Item,
      editItemKind           :: ItemKind,
      editItemNewKind        :: ItemKind }

  | Edit'SetItemDescription {
      editItemUid            :: Uid Item,
      editItemDescription    :: Text,
      editItemNewDescription :: Text }
  | Edit'SetItemNotes {
      editItemUid            :: Uid Item,
      editItemNotes          :: Text,
      editItemNewNotes       :: Text }
  | Edit'SetItemEcosystem {
      editItemUid            :: Uid Item,
      editItemEcosystem      :: Text,
      editItemNewEcosystem   :: Text }

  -- Change trait properties
  | Edit'SetTraitContent {
      editItemUid         :: Uid Item,
      editTraitUid        :: Uid Trait,
      editTraitContent    :: Text,
      editTraitNewContent :: Text }

  -- Delete
  | Edit'DeleteCategory {
      editCategoryUid       :: Uid Category,
      editCategoryPosition  :: Int }
  | Edit'DeleteItem {
      editItemUid           :: Uid Item,
      editItemPosition      :: Int }
  | Edit'DeleteTrait {
      editItemUid           :: Uid Item,
      editTraitUid          :: Uid Trait,
      editTraitPosition     :: Int }

  -- Other
  | Edit'MoveItem {
      editItemUid   :: Uid Item,
      editDirection :: Bool }
  | Edit'MoveTrait {
      editItemUid   :: Uid Item,
      editTraitUid  :: Uid Trait,
      editDirection :: Bool }

  deriving (Eq, Show)

deriveSafeCopySimple 7 'extension ''Edit

genVer ''Edit 6 [
  -- Add
  Copy 'Edit'AddCategory,
  Copy 'Edit'AddItem,
  Copy 'Edit'AddPro,
  Copy 'Edit'AddCon,
  -- Change category properties
  Copy 'Edit'SetCategoryTitle,
  Copy 'Edit'SetCategoryGroup,
  Copy 'Edit'SetCategoryNotes,
  Copy 'Edit'SetCategoryStatus,
  Custom "Edit'SetCategoryProsConsEnabled" [
      ("editCategoryUid"                , [t|Uid Category|]),
      ("_editCategoryProsConsEnabled"   , [t|Bool|]),
      ("editCategoryNewProsConsEnabled" , [t|Bool|]) ],
  Custom "Edit'SetCategoryEcosystemEnabled" [
      ("editCategoryUid"                , [t|Uid Category|]),
      ("_editCategoryEcosystemEnabled"  , [t|Bool|]),
      ("editCategoryNewEcosystemEnabled", [t|Bool|]) ],
  Custom "Edit'SetCategoryNotesEnabled" [
      ("editCategoryUid"                , [t|Uid Category|]),
      ("_editCategoryNotesEnabled"      , [t|Bool|]),
      ("editCategoryNewNotesEnabled"    , [t|Bool|]) ],
  -- Change item properties
  Copy 'Edit'SetItemName,
  Copy 'Edit'SetItemLink,
  Copy 'Edit'SetItemGroup,
  Copy 'Edit'SetItemKind,
  Copy 'Edit'SetItemDescription,
  Copy 'Edit'SetItemNotes,
  Copy 'Edit'SetItemEcosystem,
  -- Change trait properties
  Copy 'Edit'SetTraitContent,
  -- Delete
  Copy 'Edit'DeleteCategory,
  Copy 'Edit'DeleteItem,
  Copy 'Edit'DeleteTrait,
  -- Other
  Copy 'Edit'MoveItem,
  Copy 'Edit'MoveTrait ]

deriveSafeCopySimple 6 'base ''Edit_v6

instance Migrate Edit where
  type MigrateFrom Edit = Edit_v6
  migrate = $(migrateVer ''Edit 6 [
    CopyM 'Edit'AddCategory,
    CopyM 'Edit'AddItem,
    CopyM 'Edit'AddPro,
    CopyM 'Edit'AddCon,
    -- Change category properties
    CopyM 'Edit'SetCategoryTitle,
    CopyM 'Edit'SetCategoryGroup,
    CopyM 'Edit'SetCategoryNotes,
    CopyM 'Edit'SetCategoryStatus,
    CustomM "Edit'SetCategoryProsConsEnabled" [|\x ->
        if editCategoryNewProsConsEnabled_v6 x
          then Edit'ChangeCategoryEnabledSections (editCategoryUid_v6 x)
                 (S.singleton ItemProsConsSection) mempty
          else Edit'ChangeCategoryEnabledSections (editCategoryUid_v6 x)
                 mempty (S.singleton ItemProsConsSection) |],
    CustomM "Edit'SetCategoryEcosystemEnabled" [|\x ->
        if editCategoryNewEcosystemEnabled_v6 x
          then Edit'ChangeCategoryEnabledSections (editCategoryUid_v6 x)
                 (S.singleton ItemEcosystemSection) mempty
          else Edit'ChangeCategoryEnabledSections (editCategoryUid_v6 x)
                 mempty (S.singleton ItemEcosystemSection) |],
    CustomM "Edit'SetCategoryNotesEnabled" [|\x ->
        if editCategoryNewNotesEnabled_v6 x
          then Edit'ChangeCategoryEnabledSections (editCategoryUid_v6 x)
                 (S.singleton ItemNotesSection) mempty
          else Edit'ChangeCategoryEnabledSections (editCategoryUid_v6 x)
                 mempty (S.singleton ItemNotesSection) |],
    -- Change item properties
    CopyM 'Edit'SetItemName,
    CopyM 'Edit'SetItemLink,
    CopyM 'Edit'SetItemGroup,
    CopyM 'Edit'SetItemKind,
    CopyM 'Edit'SetItemDescription,
    CopyM 'Edit'SetItemNotes,
    CopyM 'Edit'SetItemEcosystem,
    -- Change trait properties
    CopyM 'Edit'SetTraitContent,
    -- Delete
    CopyM 'Edit'DeleteCategory,
    CopyM 'Edit'DeleteItem,
    CopyM 'Edit'DeleteTrait,
    -- Other
    CopyM 'Edit'MoveItem,
    CopyM 'Edit'MoveTrait
    ])

-- | Determine whether the edit doesn't actually change anything and so isn't
-- worth recording in the list of pending edits.
isVacuousEdit :: Edit -> Bool
isVacuousEdit Edit'SetCategoryTitle{..} =
  editCategoryTitle == editCategoryNewTitle
isVacuousEdit Edit'SetCategoryGroup{..} =
  editCategoryGroup == editCategoryNewGroup
isVacuousEdit Edit'SetCategoryNotes{..} =
  editCategoryNotes == editCategoryNewNotes
isVacuousEdit Edit'SetCategoryStatus{..} =
  editCategoryStatus == editCategoryNewStatus
isVacuousEdit Edit'ChangeCategoryEnabledSections {..} =
  null editCategoryEnableSections &&
  null editCategoryDisableSections
isVacuousEdit Edit'SetItemName{..} =
  editItemName == editItemNewName
isVacuousEdit Edit'SetItemLink{..} =
  editItemLink == editItemNewLink
isVacuousEdit Edit'SetItemGroup{..} =
  editItemGroup == editItemNewGroup
isVacuousEdit Edit'SetItemKind{..} =
  editItemKind == editItemNewKind
isVacuousEdit Edit'SetItemDescription{..} =
  editItemDescription == editItemNewDescription
isVacuousEdit Edit'SetItemNotes{..} =
  editItemNotes == editItemNewNotes
isVacuousEdit Edit'SetItemEcosystem{..} =
  editItemEcosystem == editItemNewEcosystem
isVacuousEdit Edit'SetTraitContent{..} =
  editTraitContent == editTraitNewContent
isVacuousEdit Edit'AddCategory{}    = False
isVacuousEdit Edit'AddItem{}        = False
isVacuousEdit Edit'AddPro{}         = False
isVacuousEdit Edit'AddCon{}         = False
isVacuousEdit Edit'DeleteCategory{} = False
isVacuousEdit Edit'DeleteItem{}     = False
isVacuousEdit Edit'DeleteTrait{}    = False
isVacuousEdit Edit'MoveItem{}       = False
isVacuousEdit Edit'MoveTrait{}      = False

data EditDetails = EditDetails {
  editIP   :: Maybe IP,
  editDate :: UTCTime,
  editId   :: Int }
  deriving (Eq, Show)

deriveSafeCopySorted 4 'extension ''EditDetails

changelog ''EditDetails (Current 4, Past 3) []
deriveSafeCopySorted 3 'base ''EditDetails_v3
