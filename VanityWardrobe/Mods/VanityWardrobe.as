// =============================================================================
//  Vanity Wardrobe  —  transmog: change how your gear LOOKS, not what it DOES
//
//  Terraria-style vanity for Witchspire. Per visible equipment slot (Hat, Robe,
//  Broom, ...) you pick an APPEARANCE that renders on your character while your
//  real, equipped gear keeps giving 100% of its stats. The chosen look grants
//  nothing — it's purely cosmetic.
//
//  WHY THIS IS POSSIBLE:  the game's UEquipmentInstance already splits an item's
//  VISUALS from its STATS (see EquipmentInstance.as):
//    - looks  = SpawnEquipmentActors() (attached meshes) + EquipCharacterParts()
//               (body-mesh swaps via UCharacterVisualsComponent::AddPart)
//    - stats  = HandleEquipped() (abilities / gameplay effects / actions)
//  A vanity look just performs the VISUAL half for an item you choose, and never
//  the stat half. Your equipped gear's stat half is untouched.
//
//  TWO KINDS OF LOOK, handled automatically per item:
//    - Character-part items (the witch's Hat / Robe / outfit meshes): swapped on
//      the body with UCharacterVisualsComponent.RemovePart(slot)/AddPart(part),
//      exactly like the character-creation screen (PlayerCustomizationComponent).
//    - Attached-actor items (e.g. the broom): the real one is stowed with
//      EquipmentComp.RequestHideItem(slot) and a cosmetic AEquipmentActor is
//      spawned + attached to the same socket.
//
//  TWO WAYS TO CHOOSE A LOOK:
//    1. ImGui "Vanity Wardrobe" panel (press F7) — browse EVERY item in the game
//       per slot and apply its look. Auto-enables Developer Mode (like Reforge
//       Gear). Best for full cosmetic freedom.
//    2. World "Wardrobe" object (press F6 to summon) — no Developer Mode needed:
//       put the gear whose look you want into a hotbar slot, select it, and
//       Interact with the Wardrobe. Interacting again with the same item reverts
//       that slot. Limited to items you own.
//
//  SCOPE / LIMITS:
//    - Single-player / listen-server (host). Appearance is applied locally; no
//      save tampering. Selections persist for the play session (across map loads)
//      but reset when you fully quit the game — re-pick from the panel after a
//      restart. The weapon (Hand) slot is OFF by default (it is heavily driven by
//      combat/building animations); flip bIncludeWeaponSlot to try it.
// =============================================================================


namespace VanityWardrobeConfig
{
    // Opens / closes the ImGui Vanity Wardrobe panel (press in normal gameplay,
    // NOT while a game menu is open). Any EKeys::... value works.
    const FKey ToggleMenuKey = EKeys::F7;

    // Summons / dismisses the in-world Wardrobe object (the no-Developer-Mode
    // path). Select gear in your hotbar, then use the game's Interact key on it.
    const FKey SummonWardrobeKey = EKeys::F6;

    // Auto-enable Developer Mode on startup so the ImGui panel is reachable.
    // Set false if you only want the world Wardrobe object.
    const bool bAutoEnableDeveloperMode = true;

    // Include the weapon (Hand) slot in the wardrobe. OFF by default: the wielded
    // item is constantly shown/hidden/animated by combat, dodging and building,
    // so a static cosmetic weapon can look out of place or get briefly overridden.
    const bool bIncludeWeaponSlot = false;

    // Hide developer placeholder / retired items so they don't show as cosmetics.
    // The game retires gear two different ways and we catch both (see
    // Vanity::IsRetiredItem):
    //   - the display NAME is tagged, e.g. "Witch's Hat [not used]" or "Not Used"
    //     -> matched against UnusedNameMarker
    //   - the DESCRIPTION retires it, e.g. "...is old and should no longer be used."
    //     while the name itself looks clean -> matched against RetiredDescMarker
    // Both are matched case-insensitively (FString::Contains defaults to IgnoreCase).
    const bool bHideUnusedItems = true;
    const FString UnusedNameMarker = "not used";
    const FString RetiredDescMarker = "no longer be used";

    // How often (seconds) the look is re-asserted. Keeps the appearance correct
    // after you change gear, respawn, or the body mesh rebuilds. Cheap; change
    // tracking means it only acts when something actually differs.
    const float ReconcileInterval = 0.25;
}


// How a single slot's appearance is being driven.
enum EVanityMode
{
    Default,   // show the real equipped gear (no override)
    Hidden,    // hide the slot's look (base body / nothing)
    Vanity,    // show a chosen item's look instead of the real gear
}


// -----------------------------------------------------------------------------
//  Shared helpers: classify an item's visual and prettify slot tags.
// -----------------------------------------------------------------------------
namespace Vanity
{
    // True for developer placeholder / retired gear that should never appear as a
    // cosmetic. The game retires items two ways: by tagging the display name
    // ("Witch's Hat [not used]", or a bare "Not Used"), or by leaving the name
    // clean but writing a description that says it's old and should no longer be
    // used. We honor either. Contains() is case-insensitive by default, so the
    // markers match regardless of how the text is cased in the data.
    bool IsRetiredItem(const UItemDefinition Def)
    {
        if (!VanityWardrobeConfig::bHideUnusedItems || Def == nullptr)
            return false;

        if (Def.DisplayName.ToString().Contains(VanityWardrobeConfig::UnusedNameMarker))
            return true;
        if (Def.Description.ToString().Contains(VanityWardrobeConfig::RetiredDescMarker))
            return true;

        return false;
    }

    // True if the item can contribute a visible appearance to an equipment slot,
    // i.e. it's equippable AND has either a character-part mesh or an attached
    // actor mesh. Fills the slot tag and whether it's a character-part look.
    // Honors VanityWardrobeConfig::bIncludeWeaponSlot for the Hand slot.
    bool IsVisibleEquip(const UItemDefinition Def, FGameplayTag& OutSlot, bool& bOutCharacterPart)
    {
        bOutCharacterPart = false;
        if (Def == nullptr)
            return false;

        // Skip developer placeholder / retired items (name- or description-tagged).
        if (IsRetiredItem(Def))
            return false;

        const UItemFragment_Equipment Eq = Def.GetFragment_Equipment();
        if (Eq == nullptr || !Eq.EquipsToSlot.IsValid())
            return false;

        if (!VanityWardrobeConfig::bIncludeWeaponSlot && Eq.EquipsToSlot == GameplayTags::EquipmentSlot_Hand)
            return false;

        OutSlot = Eq.EquipsToSlot;

        // Character-part (body-mesh) look — the witch's hat/robe/outfit.
        const UItemFragment_CharacterPart Cp = Def.GetFragment_CharacterPart();
        if (Cp != nullptr && Cp.Part != nullptr)
        {
            bOutCharacterPart = true;
            return true;
        }

        // Attached-actor look — a mesh snapped to a skeleton socket (broom, etc.).
        for (FItemActorToSpawn SpawnInfo : Def.ActorsToSpawn)
        {
            if (!SpawnInfo.AttachmentSocket.IsNone())
                return true;
        }

        return false;   // equippable but invisible (rings, trinkets, ...)
    }

    // "EquipmentSlot.Hat" -> "Hat". Falls back to the raw tag if the prefix
    // differs. Purely for display.
    FString PrettySlotName(const FGameplayTag& SlotTag)
    {
        FString Name = SlotTag.ToString();
        Name.RemoveFromStart("EquipmentSlot.");
        return Name;
    }
}


// -----------------------------------------------------------------------------
//  Selection store (game-instance scope): which look each slot should show.
//  Lives on the GameInstance so choices survive map/level reloads within a play
//  session. Holds DATA only — no spawned actors (those are per-world, owned by
//  the controller). Accessed anywhere via UVanityStore::Get().
// -----------------------------------------------------------------------------
UCLASS()
class UVanityStore : UScriptGameInstanceSubsystem
{
    // equipSlot -> chosen vanity item tag.
    private TMap<FGameplayTag, FGameplayTag> VanityBySlot;
    // equipSlots explicitly set to "hidden".
    private TArray<FGameplayTag> HiddenSlots;
    // every slot the player has ever touched this session. The reconciler walks
    // this so that reverting a slot to Default still restores the real gear.
    private TArray<FGameplayTag> ManagedSlots;

    private bool bDirty = false;

    EVanityMode GetMode(const FGameplayTag& Slot) const
    {
        if (VanityBySlot.Contains(Slot))
            return EVanityMode::Vanity;
        if (HiddenSlots.Contains(Slot))
            return EVanityMode::Hidden;
        return EVanityMode::Default;
    }

    FGameplayTag GetVanityItem(const FGameplayTag& Slot) const
    {
        FGameplayTag Tag;
        VanityBySlot.Find(Slot, Tag);
        return Tag;
    }

    void SetVanity(const FGameplayTag& Slot, const FGameplayTag& ItemTag)
    {
        VanityBySlot.Add(Slot, ItemTag);
        HiddenSlots.Remove(Slot);
        Touch(Slot);
    }

    void SetHidden(const FGameplayTag& Slot)
    {
        VanityBySlot.Remove(Slot);
        HiddenSlots.AddUnique(Slot);
        Touch(Slot);
    }

    void SetDefault(const FGameplayTag& Slot)
    {
        VanityBySlot.Remove(Slot);
        HiddenSlots.Remove(Slot);
        Touch(Slot);   // kept in ManagedSlots so the reconciler restores real gear
    }

    // Clears every override (slots stay managed so the real gear is restored).
    void ClearAll()
    {
        VanityBySlot.Reset();
        HiddenSlots.Reset();
        bDirty = true;
    }

    const TArray<FGameplayTag>& GetManagedSlots() const
    {
        return ManagedSlots;
    }

    // Read-and-clear the "selection changed" flag for instant re-apply.
    bool ConsumeDirty()
    {
        const bool bWas = bDirty;
        bDirty = false;
        return bWas;
    }

    private void Touch(const FGameplayTag& Slot)
    {
        ManagedSlots.AddUnique(Slot);
        bDirty = true;
    }
}


// -----------------------------------------------------------------------------
//  Per-world controller: applies the selections to the LOCAL player every tick
//  interval, spawns the input actor, and (optionally) enables Developer Mode.
//  Owns the per-world runtime state (spawned cosmetic actors, hidden slots).
// -----------------------------------------------------------------------------
class UVanityController : UScriptWorldSubsystem
{
    private AVanityInput InputActor;
    private bool bDevModeSet = false;
    private float ReconcileAccum = 0.0;

    // Attached-actor runtime state.
    private TArray<FGameplayTag> SlotsWeHid;                     // real gear we stowed
    private TArray<AEquipmentActor> VanityActors;               // spawned cosmetic actors
    private TArray<FGameplayTag> VanityActorSlots;              // parallel: owning slot
    private TMap<FGameplayTag, FGameplayTag> SpawnedActorItemBySlot; // slot -> item shown

    // Character-part runtime state. Equipment slot -> the body (visual) slot its
    // look occupies, remembered so we can still revert when no item is equipped.
    private TMap<FGameplayTag, FGameplayTag> EquipToVisualSlot;
    // Body slots we've overridden, and the original part each held first (e.g. the
    // player's hairstyle), so reverting restores it instead of leaving it bald.
    private TArray<FGameplayTag> SavedVisualSlots;
    private TMap<FGameplayTag, const UCharacterPartData> SavedOriginalPart;

    UFUNCTION(BlueprintOverride)
    bool ShouldCreateSubsystem(UObject InOuter) const
    {
        UWorld OuterWorld = Cast<UWorld>(InOuter);
        if (OuterWorld == nullptr)
            return false;
        return OuterWorld.WorldType == EWorldType::Game || OuterWorld.WorldType == EWorldType::PIE;
    }

    UFUNCTION(BlueprintOverride)
    void Tick(float DeltaTime)
    {
        // Keep keyboard input flowing to the game while ImGui is open, except
        // when ImGui is actively capturing it (e.g. the search field).
        if (ImGuiModule::IsInputEnabled())
            ImGuiModule::SetKeyboardInputShared(!ImGui::IsKeyboardCaptured());

        if (Game::GetLocalPlayerController() == nullptr)
            return;

        if (!bDevModeSet && VanityWardrobeConfig::bAutoEnableDeveloperMode)
        {
            CVar::Cheats::DeveloperMode.SetBool(true);
            bDevModeSet = true;
        }

        if (InputActor == nullptr || !IsValid(InputActor))
            InputActor = Cast<AVanityInput>(SpawnActor(AVanityInput));

        APlayerCharacter Player = Game::GetLocalPlayer();
        if (Player == nullptr)
            return;

        ReconcileAccum += DeltaTime;
        const bool bDirty = UVanityStore::Get().ConsumeDirty();
        if (bDirty || ReconcileAccum >= VanityWardrobeConfig::ReconcileInterval)
        {
            ReconcileAccum = 0.0;
            ReconcileAll(Player);
        }
    }

    // Re-assert every managed slot's desired look. Idempotent: it only changes
    // what actually differs, so it's safe to call on a timer.
    private void ReconcileAll(APlayerCharacter Player)
    {
        UEquipmentComponent Equip = Player.EquipmentComp;
        if (Equip == nullptr)
            return;

        UCharacterVisualsComponent Visuals = UCharacterVisualsComponent::Get(Player);
        UVanityStore Store = UVanityStore::Get();

        for (FGameplayTag Slot : Store.GetManagedSlots())
            ReconcileSlot(Player, Store, Visuals, Equip, Slot);
    }

    private void ReconcileSlot(APlayerCharacter Player, UVanityStore Store, UCharacterVisualsComponent Visuals, UEquipmentComponent Equip, const FGameplayTag& Slot)
    {
        const EVanityMode Mode = Store.GetMode(Slot);

        // What's really equipped in this slot (for Default / type detection).
        UHercEquipmentInstance RealInst = Equip.GetEquipmentAtSlot(Slot);
        const UItemDefinition RealDef = (RealInst != nullptr && RealInst.ItemStack != nullptr)
            ? RealInst.ItemStack.GetItemDefinition() : nullptr;

        // The chosen vanity item, if any.
        const UItemDefinition VanityDef = (Mode == EVanityMode::Vanity)
            ? UItemSubsystem::GetItemDefinition(Store.GetVanityItem(Slot)) : nullptr;

        // The character-part each definition contributes (null if it's not a
        // body-mesh item).
        const UCharacterPartData RealPart = (RealDef != nullptr && RealDef.GetFragment_CharacterPart() != nullptr)
            ? RealDef.GetFragment_CharacterPart().Part : nullptr;
        const UCharacterPartData VanityPart = (VanityDef != nullptr && VanityDef.GetFragment_CharacterPart() != nullptr)
            ? VanityDef.GetFragment_CharacterPart().Part : nullptr;

        // Resolve the body (visual) slot this equipment slot drives. Prefer a live
        // part, then fall back to the mapping we remembered the first time we saw
        // one — so we can still revert correctly when nothing is equipped here.
        FGameplayTag VisualSlot;
        bool bCharacterPart = false;
        if (VanityPart != nullptr)       { bCharacterPart = true; VisualSlot = VanityPart.Slot; }
        else if (RealPart != nullptr)    { bCharacterPart = true; VisualSlot = RealPart.Slot; }
        else if (EquipToVisualSlot.Contains(Slot)) { bCharacterPart = true; EquipToVisualSlot.Find(Slot, VisualSlot); }

        if (bCharacterPart)
        {
            EquipToVisualSlot.Add(Slot, VisualSlot);   // remember for future reverts
            ReconcileCharacterPart(Visuals, VisualSlot, Mode, RealPart, VanityPart);
        }
        else
        {
            ReconcileAttachedActor(Player, Equip, Slot, Mode, VanityDef);
        }
    }

    // Body-mesh look (hat / robe / outfit). Mirrors PlayerCustomizationComponent:
    // RemovePart(slot) then AddPart(target). Before overriding a body slot we save
    // whatever was there (e.g. the player's hairstyle, since hats live in the hair
    // slot) so reverting to Default restores it instead of leaving the slot empty.
    private void ReconcileCharacterPart(UCharacterVisualsComponent Visuals, const FGameplayTag& VisualSlot, EVanityMode Mode, const UCharacterPartData RealPart, const UCharacterPartData VanityPart)
    {
        if (Visuals == nullptr || !VisualSlot.IsValid())
            return;

        // Capture the original occupant once, before we ever touch this slot.
        if (!SavedVisualSlots.Contains(VisualSlot))
        {
            SavedVisualSlots.AddUnique(VisualSlot);
            const UCharacterPartData Original = Visuals.GetPart(VisualSlot, false);
            if (Original != nullptr)
                SavedOriginalPart.Add(VisualSlot, Original);
        }

        // Default restores the real gear's part if equipped, else the saved original.
        UCharacterPartData FoundOriginal;
        SavedOriginalPart.Find(VisualSlot, FoundOriginal);
        const UCharacterPartData SavedOriginal = FoundOriginal;
        const UCharacterPartData DefaultPart = (RealPart != nullptr) ? RealPart : SavedOriginal;

        const UCharacterPartData TargetPart = (Mode == EVanityMode::Hidden)
            ? nullptr
            : ((Mode == EVanityMode::Vanity) ? VanityPart : DefaultPart);

        const UCharacterPartData Current = Visuals.GetPart(VisualSlot, false);
        if (Current == TargetPart)
            return;

        if (Current != nullptr)
            Visuals.RemovePart(VisualSlot);
        if (TargetPart != nullptr)
            Visuals.AddPart(TargetPart);
    }

    // Attached-actor look (broom, etc.). Stow the real actor for the slot and
    // spawn a cosmetic AEquipmentActor from the chosen item. Change-tracked so
    // we hide/show and respawn only on transitions.
    private void ReconcileAttachedActor(APlayerCharacter Player, UEquipmentComponent Equip, const FGameplayTag& Slot, EVanityMode Mode, const UItemDefinition VanityDef)
    {
        const bool bDesiredHideReal = (Mode == EVanityMode::Hidden || Mode == EVanityMode::Vanity);
        const bool bHidByUs = SlotsWeHid.Contains(Slot);
        if (bDesiredHideReal && !bHidByUs)
        {
            Equip.RequestHideItem(Slot);
            SlotsWeHid.AddUnique(Slot);
        }
        else if (!bDesiredHideReal && bHidByUs)
        {
            Equip.RequestShowItem(Slot);
            SlotsWeHid.Remove(Slot);
        }

        FGameplayTag DesiredItem;
        if (Mode == EVanityMode::Vanity && VanityDef != nullptr)
            DesiredItem = VanityDef.ItemTag;

        FGameplayTag CurrentItem;
        SpawnedActorItemBySlot.Find(Slot, CurrentItem);

        const bool bChanged = (DesiredItem != CurrentItem);
        const bool bWentMissing = (DesiredItem.IsValid() && !HasLiveActorsForSlot(Slot));
        if (bChanged || bWentMissing)
        {
            DestroyActorsForSlot(Slot);
            if (DesiredItem.IsValid() && VanityDef != nullptr)
                SpawnVanityActors(Player, Slot, VanityDef);
        }
    }

    private void SpawnVanityActors(APlayerCharacter Player, const FGameplayTag& Slot, const UItemDefinition Def)
    {
        USceneComponent AttachTarget = USkeletalMeshComponent::Get(Player);
        if (AttachTarget == nullptr)
            AttachTarget = Player.RootComponent;

        for (FItemActorToSpawn SpawnInfo : Def.ActorsToSpawn)
        {
            if (SpawnInfo.AttachmentSocket.IsNone())
                continue;

            AEquipmentActor Actor = Cast<AEquipmentActor>(SpawnActor(AEquipmentActor));
            if (Actor == nullptr)
                continue;

            Actor.Init(SpawnInfo);
            Actor.AttachToComponent(AttachTarget, SpawnInfo.AttachmentSocket, EAttachmentRule::KeepRelative, EAttachmentRule::KeepRelative, EAttachmentRule::SnapToTarget, false);

            VanityActors.Add(Actor);
            VanityActorSlots.Add(Slot);
        }

        SpawnedActorItemBySlot.Add(Slot, Def.ItemTag);
    }

    private void DestroyActorsForSlot(const FGameplayTag& Slot)
    {
        for (int i = VanityActors.Num() - 1; i >= 0; i--)
        {
            if (VanityActorSlots[i] != Slot)
                continue;
            if (VanityActors[i] != nullptr)
                VanityActors[i].DestroyActor();
            VanityActors.RemoveAt(i);
            VanityActorSlots.RemoveAt(i);
        }
        SpawnedActorItemBySlot.Remove(Slot);
    }

    private bool HasLiveActorsForSlot(const FGameplayTag& Slot) const
    {
        for (int i = 0; i < VanityActors.Num(); i++)
        {
            if (VanityActorSlots[i] == Slot && VanityActors[i] != nullptr && IsValid(VanityActors[i]))
                return true;
        }
        return false;
    }
}


// -----------------------------------------------------------------------------
//  Input receiver: toggles the ImGui panel and summons the world Wardrobe.
//  Uses a non-consuming BindKey (mirrors the other mods) so it coexists with the
//  game's own controls.
// -----------------------------------------------------------------------------
UCLASS(NotPlaceable, HideCategories = "Actor Tick Rendering Replication Collision Input")
class AVanityInput : AActor
{
    default bReplicates = false;

    UPROPERTY(DefaultComponent, RootComponent)
    USceneComponent Root;

    UPROPERTY(DefaultComponent)
    UInputComponent InputComp;

    private AVanityWardrobe SummonedWardrobe;

    UFUNCTION(BlueprintOverride)
    void BeginPlay()
    {
        APlayerController Controller = Game::GetLocalPlayerController();
        if (Controller == nullptr)
            return;

        Controller.PushInputComponent(InputComp);
        InputComp.BindKey(VanityWardrobeConfig::ToggleMenuKey, EInputEvent::IE_Pressed, FInputActionHandlerDynamicSignature(this, n"OnToggleMenu"));
        InputComp.BindKey(VanityWardrobeConfig::SummonWardrobeKey, EInputEvent::IE_Pressed, FInputActionHandlerDynamicSignature(this, n"OnSummonWardrobe"));
    }

    UFUNCTION()
    private void OnToggleMenu(FKey Key)
    {
        APlayerController Controller = Game::GetLocalPlayerController();
        if (Controller == nullptr)
            return;

        ULocalPlayer LocalPlayer = Controller.LocalPlayer;
        if (LocalPlayer == nullptr)
            return;

        const bool bOpen = !UImGuiDebugMenuSubsystem::IsVisible(LocalPlayer) || !ImGuiModule::IsInputEnabled();
        if (bOpen)
        {
            UImGuiDebugMenuSubsystem::Show(LocalPlayer);
            ImGuiModule::SetInputEnabled(true);
        }
        else
        {
            UImGuiDebugMenuSubsystem::Hide(LocalPlayer);
            ImGuiModule::SetInputEnabled(false);
        }
    }

    UFUNCTION()
    private void OnSummonWardrobe(FKey Key)
    {
        if (SummonedWardrobe != nullptr && IsValid(SummonedWardrobe))
        {
            SummonedWardrobe.DestroyActor();
            SummonedWardrobe = nullptr;
            return;
        }

        APlayerCharacter Player = Game::GetLocalPlayer();
        if (Player == nullptr)
            return;

        // A couple of metres ahead, facing back toward the player so the label reads right.
        const FVector Location = Player.GetActorLocation() + Player.GetActorForwardVector() * 200.0;
        const FRotator Rotation = (Player.GetActorLocation() - Location).Rotation();
        SummonedWardrobe = Cast<AVanityWardrobe>(SpawnActor(AVanityWardrobe, Location, Rotation));
    }
}


// -----------------------------------------------------------------------------
//  ImGui "Vanity Wardrobe" panel: per-slot, searchable picker over EVERY item.
// -----------------------------------------------------------------------------

// One catalog slot's worth of selectable items (built once from UItemSubsystem).
struct FVanityCatalogSlot
{
    FGameplayTag EquipSlot;
    FString DisplayName;
    bool bCharacterPart = false;
    TArray<FGameplayTag> ItemTags;
    TArray<FString> ItemNames;
}

UCLASS()
class UVanityWardrobeWindow : UImGuiDebugMenuWindow
{
    private bool bBuilt = false;
    private TArray<FVanityCatalogSlot> Catalog;
    private FString SearchText;

    UFUNCTION(BlueprintOverride)
    bool Initialize(UObject UserData)
    {
        return true;
    }

    UFUNCTION(BlueprintOverride)
    void DrawContents(float DeltaTime)
    {
        APlayerCharacter Player = Game::GetLocalPlayer();
        if (Player == nullptr)
        {
            ImGui::Text("No local player.");
            return;
        }

        if (!bBuilt)
            BuildCatalog();

        if (Catalog.IsEmpty())
        {
            ImGui::Text("Item database not ready yet — reopen this panel in a moment.");
            return;
        }

        UVanityStore Store = UVanityStore::Get();

        ImGui::Text("Change how your gear LOOKS — your real gear keeps all its stats.");
        ImGui::TextDisabled("'Default' = your equipped gear. 'Hidden' = base look. Or pick any item below.");
        ImGui::InputText("Search", SearchText);
        ImGui::SameLine();
        if (ImGui::Button("Reset all"))
            Store.ClearAll();
        ImGui::Separator();

        for (int s = 0; s < Catalog.Num(); s++)
        {
            const FVanityCatalogSlot Slot = Catalog[s];
            const EVanityMode Mode = Store.GetMode(Slot.EquipSlot);
            const FString Current = CurrentLabel(Store, Slot, Mode);

            // Stable header id (###) so the live label can change without losing state.
            if (!ImGui::CollapsingHeader(f"{Slot.DisplayName}:  {Current}###slot{s}"))
                continue;

            ImGui::Indent();

            bool bSelDefault = (Mode == EVanityMode::Default);
            if (ImGui::Selectable(f"Default (your real gear)##def{s}", bSelDefault))
                Store.SetDefault(Slot.EquipSlot);

            bool bSelHidden = (Mode == EVanityMode::Hidden);
            if (ImGui::Selectable(f"Hidden (base look)##hid{s}", bSelHidden))
                Store.SetHidden(Slot.EquipSlot);

            const FGameplayTag ActiveItem = Store.GetVanityItem(Slot.EquipSlot);
            int Shown = 0;
            for (int i = 0; i < Slot.ItemTags.Num(); i++)
            {
                if (!PassesFilter(Slot.ItemNames[i]))
                    continue;

                bool bSel = (Mode == EVanityMode::Vanity && ActiveItem == Slot.ItemTags[i]);
                if (ImGui::Selectable(f"{Slot.ItemNames[i]}##it{s}_{i}", bSel))
                    Store.SetVanity(Slot.EquipSlot, Slot.ItemTags[i]);
                Shown++;
            }
            if (Shown == 0)
                ImGui::TextDisabled("(no items match the search)");

            ImGui::Unindent();
            ImGui::Separator();
        }
    }

    private FString CurrentLabel(UVanityStore Store, const FVanityCatalogSlot& Slot, EVanityMode Mode) const
    {
        if (Mode == EVanityMode::Hidden)
            return "Hidden";
        if (Mode == EVanityMode::Vanity)
        {
            const UItemDefinition Def = UItemSubsystem::GetItemDefinition(Store.GetVanityItem(Slot.EquipSlot));
            return (Def != nullptr) ? Def.DisplayName.ToString() : "Vanity";
        }
        return "Default";
    }

    private bool PassesFilter(const FString& Candidate) const
    {
        return SearchText.IsEmpty() || Candidate.Contains(SearchText);
    }

    // Build the per-slot item catalog from every loaded item definition.
    private void BuildCatalog()
    {
        UItemSubsystem ItemSub = UItemSubsystem::Get();
        if (ItemSub == nullptr || ItemSub.Items.Num() == 0)
            return;   // not loaded yet; try again next open

        Catalog.Reset();
        for (const auto& Entry : ItemSub.Items)
        {
            const UItemDefinition Def = Entry.Value;
            FGameplayTag Slot;
            bool bCharPart = false;
            if (!Vanity::IsVisibleEquip(Def, Slot, bCharPart))
                continue;

            const int Index = FindOrAddSlot(Slot, bCharPart);
            Catalog[Index].ItemTags.Add(Def.ItemTag);
            Catalog[Index].ItemNames.Add(Def.DisplayName.ToString());
        }

        bBuilt = true;
    }

    private int FindOrAddSlot(const FGameplayTag& Slot, bool bCharPart)
    {
        for (int i = 0; i < Catalog.Num(); i++)
        {
            if (Catalog[i].EquipSlot == Slot)
                return i;
        }

        FVanityCatalogSlot New;
        New.EquipSlot = Slot;
        New.DisplayName = Vanity::PrettySlotName(Slot);
        New.bCharacterPart = bCharPart;
        Catalog.Add(New);
        return Catalog.Num() - 1;
    }
}

// Registers the panel under Cheats in the ImGui debug menu (mirrors Reforge Gear).
UCLASS()
class UVanityWardrobeMenu : UImGuiPersistentMenuSubsystem
{
    default WindowName = n"Vanity Wardrobe";
    default WindowClass = UVanityWardrobeWindow;
    default MenuPath = "Cheats|Vanity Wardrobe";
}


// -----------------------------------------------------------------------------
//  World "Wardrobe" object (no Developer Mode): apply the look of the gear you
//  have SELECTED in your hotbar to its slot. Interact again with the same item
//  to revert that slot. Same picker-free pattern as the Reforge Altar.
// -----------------------------------------------------------------------------
UCLASS()
class UInteraction_ApplyVanity : UInteraction
{
    UFUNCTION(BlueprintOverride)
    void OnInteractServer(const FInteractionContext& Context)
    {
        APlayerCharacter Player = Cast<APlayerCharacter>(Context.Interactor.Owner);
        if (Player == nullptr || Player.HotbarComp == nullptr)
            return;

        AVanityWardrobe Wardrobe = Cast<AVanityWardrobe>(Context.Interactable.Owner);

        UItemStack Item = Player.HotbarComp.GetSelectedItemStack();
        if (Item == nullptr)
        {
            Notify(Wardrobe, "Select gear in your\nhotbar first", FLinearColor(1.0, 0.55, 0.2, 1.0));
            return;
        }

        const UItemDefinition Def = Item.GetItemDefinition();
        FGameplayTag Slot;
        bool bCharPart = false;
        if (!Vanity::IsVisibleEquip(Def, Slot, bCharPart))
        {
            Notify(Wardrobe, "That item has no\nwearable look", FLinearColor(1.0, 0.55, 0.2, 1.0));
            return;
        }

        UVanityStore Store = UVanityStore::Get();
        const FString ItemName = Def.DisplayName.ToString();

        // Toggle: if this exact look is already applied to its slot, revert it.
        if (Store.GetMode(Slot) == EVanityMode::Vanity && Store.GetVanityItem(Slot) == Def.ItemTag)
        {
            Store.SetDefault(Slot);
            Notify(Wardrobe, f"Reverted {Vanity::PrettySlotName(Slot)}", FLinearColor(0.45, 0.8, 1.0, 1.0));
        }
        else
        {
            Store.SetVanity(Slot, Def.ItemTag);
            Notify(Wardrobe, f"Now wearing the look of\n{ItemName}", FLinearColor(0.45, 0.8, 1.0, 1.0));
        }
    }

    private void Notify(AVanityWardrobe Wardrobe, const FString& Message, const FLinearColor& Color)
    {
        Print(Message, 4.0, Color);
        if (Wardrobe != nullptr)
            Wardrobe.ShowMessage(Message);
    }
}

// The summonable Wardrobe. Detection + prompt come from UInteractableComponent;
// the UTextRenderComponent label is the visible marker (works in Shipping, no
// UMG asset). The label yaw-billboards to the camera each frame.
UCLASS(NotPlaceable, HideCategories = "Replication")
class AVanityWardrobe : AActor
{
    default bReplicates = true;

    UPROPERTY(DefaultComponent, RootComponent)
    USceneComponent Root;

    UPROPERTY(DefaultComponent)
    UInteractableComponent InteractableComp;

    UPROPERTY(DefaultComponent)
    UTextRenderComponent LabelComp;
    default LabelComp.HorizontalAlignment = EHorizTextAligment::EHTA_Center;
    default LabelComp.VerticalAlignment = EVerticalTextAligment::EVRTA_TextCenter;
    default LabelComp.WorldSize = 50.0;
    default LabelComp.TextRenderColor = FColor(200, 150, 255);

    UFUNCTION(BlueprintOverride)
    void BeginPlay()
    {
        LabelComp.SetRelativeLocation(FVector(0.0, 0.0, 120.0));
        LabelComp.SetText(FText::FromString("Wardrobe\n(select gear in hotbar, then Interact)"));

        // The interaction is server logic; on host / single-player you are the server.
        if (!HasAuthority())
            return;

        UInteraction_ApplyVanity Inter = NewObject(this, UInteraction_ApplyVanity);
        Inter.InteractionType = EInteractionType::OnActivated;
        InteractableComp.SetInteraction(Inter);
    }

    // Keep the label upright and facing the camera so it stays readable.
    UFUNCTION(BlueprintOverride)
    void Tick(float DeltaTime)
    {
        APlayerController PC = Game::GetLocalPlayerController();
        if (PC == nullptr || PC.PlayerCameraManager == nullptr)
            return;

        const FVector CamLoc = PC.PlayerCameraManager.GetCameraLocation();
        const FVector LabelLoc = LabelComp.GetWorldLocation();

        FRotator Face = (CamLoc - LabelLoc).Rotation();
        Face.Pitch = 0.0;
        Face.Roll = 0.0;
        LabelComp.SetWorldRotation(Face);
    }

    void ShowMessage(const FString& Message)
    {
        LabelComp.SetText(FText::FromString(Message));
    }
}
