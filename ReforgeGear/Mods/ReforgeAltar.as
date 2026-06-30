// =============================================================================
//  Reforge Altar  —  reroll starred-gear substats at a summoned altar
//  (no Developer Mode / no ImGui)
//
//  This is the ALTAR-ONLY edition of Reforge Gear. Press F9 to summon a floating
//  altar in front of you; put the gear (or familiar) you want to reforge in a
//  hotbar slot and SELECT it, then HOLD the game's normal Interact key on the
//  altar to re-roll its random substats. Stars (rarity) are kept; only the
//  substats below the tooltip divider change. Each reroll costs coins.
//
//  The altar label shows the selected item's current substats with the best
//  obtainable roll for each stat tagged [MAX], plus an "N/M maxed" score, so you
//  can tell at a glance whether a roll is worth keeping.
//
//  Companion editions (install only ONE at a time -- see scripts/):
//    - ReforgeCheatGui.as : an ImGui debug panel (full bag/equipped control).
//    - ReforgeGear.as     : the combined "full" edition (altar + panel).
//
//  NOTE: single-player / listen-server (host) only -- SetRarity is
//  server-authoritative. No save tampering; it only modifies a live item.
// =============================================================================


namespace ReforgeAltarConfig
{
    // --- Reforge cost -------------------------------------------------------
    // Each reroll consumes a flat coin cost, checked AND spent host-side before
    // the substats are re-rolled. Set RerollCost to 0 to make reforging free.
    // CostItemTag is the currency spent (default Items_Coin, the vendor coin).
    const FGameplayTag CostItemTag = GameplayTags::Items_Coin;
    const int RerollCost = 100;

    // World hotkey that summons / dismisses the altar in front of you.
    const FKey SummonAltarKey = EKeys::F9;

    // Hold-to-confirm: seconds you must HOLD Interact on the altar before it
    // reforges, so an accidental tap does nothing. 0 = instant (no confirm).
    const float AltarHoldSeconds = 0.75;

    // The altar shows the selected item's own world mesh, floating and spinning
    // above it, auto-scaled so its largest dimension is ~this many cm.
    const float AltarItemTargetSize = 60.0;
    const float AltarSpinDegreesPerSec = 45.0;   // slow spin; 0 to disable

    // Vertical layout (cm above the altar base): item sits lower, text floats up.
    const float AltarMeshHeight  = 50.0;
    const float AltarLabelHeight = 165.0;
    const float AltarLabelSize   = 32.0;

    // How far in front of you the altar is summoned (cm).
    const float AltarSummonDistance = 150.0;
}


// -----------------------------------------------------------------------------
//  Reforge core: cost lookup + the in-place reroll.
// -----------------------------------------------------------------------------
namespace ReforgeAltarCore
{
    int GetRerollCost(EItemRarity Rarity)
    {
        return ReforgeAltarConfig::RerollCost;
    }

    // Is this a starred (rerollable) item? Anything with a rarity fragment above
    // Common -- gear AND familiars. Items with no substats have no rarity frag.
    bool IsRerollableGear(UItemStack Item)
    {
        if (Item == nullptr)
            return false;
        UItemRuntimeFragment_Rarity Frag = Item.GetRuntimeFragment_Rarity();
        if (Frag == nullptr)
            return false;
        return int(Frag.GetRarity()) > int(EItemRarity::Common);
    }

    // Charges the coin cost (host-side) and rerolls the item's substats in place,
    // keeping its rarity. Pass the equipment Instance for equipped gear; nullptr
    // for bag gear. Returns true only if coins were paid and the reroll happened.
    bool TryReforge(APlayerCharacter Player, UItemStack Item, UItemRuntimeFragment_Rarity RarityFrag, EItemRarity Rarity, UHercEquipmentInstance Instance)
    {
        if (!System::IsServer() || Player == nullptr || RarityFrag == nullptr)
            return false;

        const int Cost = GetRerollCost(Rarity);
        if (Cost > 0)
        {
            UInventoryComponent Inv = Player.InventoryComp;
            if (Inv == nullptr || !Inv.CanRemoveItemsByTag(ReforgeAltarConfig::CostItemTag, Cost))
                return false;
            Inv.RemoveItemsByTag(ReforgeAltarConfig::CostItemTag, Cost);
        }

        UEquipmentInstance EquipInst = (Instance != nullptr) ? Cast<UEquipmentInstance>(Instance) : nullptr;
        if (EquipInst != nullptr)
            EquipInst.HandleUnequipped();

        RarityFrag.SetRarity(Rarity);

        if (EquipInst != nullptr)
            EquipInst.HandleEquipped();

        Log(n"ReforgeAltar", f"Rerolled substats on '{Item.GetItemDefinition().DisplayName}' for {Cost} coins.");
        return true;
    }
}


// -----------------------------------------------------------------------------
//  Max-roll analysis. Substats are drawn from FIXED, discrete weighted pools
//  (UItemRaritySettings), not a min/max range, so the best obtainable value per
//  stat is fully enumerable. See ReforgeGear.as for the detailed write-up.
//  Gear only (familiars roll from a separate pool); higher magnitude = better,
//  positive effects only.
// -----------------------------------------------------------------------------
struct FReforgeAltarStatBest
{
    FString AttrName;     // modified GameplayAttribute name (the group key)
    float MaxMagnitude;   // highest magnitude available for this stat
    FString BestText;     // localized line, e.g. "+50% Spellblade Damage"
}

namespace ReforgeAltarMax
{
    bool SupportsMaxAnalysis(UItemStack Item)
    {
        if (Item == nullptr)
            return false;
        const UItemDefinition Def = Item.GetItemDefinition();
        if (Def == nullptr)
            return false;
        return Def.GetFragment_Familiar() == nullptr;
    }

    FString AttrNameOf(const FPassiveEffect& Effect)
    {
        TSubclassOf<UGameplayEffect> Cls = Effect.GameplayEffectClass;
        if (!Cls.IsValid())
            return "";
        const UGameplayEffect Defaults = Cls.DefaultObject;
        if (Defaults == nullptr || Defaults.Modifiers.Num() != 1)
            return "";
        return Defaults.Modifiers[0].GetModifiedAttribute().AttributeName;
    }

    void Accumulate(TArray<FReforgeAltarStatBest>& Stats, const FString& Attr, const FPassiveEffect& Effect)
    {
        for (int i = 0; i < Stats.Num(); i++)
        {
            if (Stats[i].AttrName == Attr)
            {
                if (Effect.Magnitude > Stats[i].MaxMagnitude)
                {
                    Stats[i].MaxMagnitude = Effect.Magnitude;
                    Stats[i].BestText = Effect.GetLocalizedText().ToString();
                }
                return;
            }
        }
        FReforgeAltarStatBest New;
        New.AttrName = Attr;
        New.MaxMagnitude = Effect.Magnitude;
        New.BestText = Effect.GetLocalizedText().ToString();
        Stats.Add(New);
    }

    void GatherBest(UItemStack Item, EItemRarity ItemRarity, TArray<FReforgeAltarStatBest>& OutStats)
    {
        OutStats.Empty();
        if (!SupportsMaxAnalysis(Item))
            return;

        const UItemRaritySettings Settings = Game::GetGameInstance().ItemRaritySettings;
        if (Settings == nullptr)
            return;

        const bool bItemPool = (Item.GetRuntimeFragment_PlayerActions() != nullptr);

        for (int Tier = int(EItemRarity::Rare); Tier <= int(ItemRarity); Tier++)
        {
            const EItemRarity TierRarity = EItemRarity(Tier);

            TArray<FItemRarityPassive> Pool;
            if (bItemPool)
                Pool = Settings.GetItemPassivePool(TierRarity);
            else
                Pool = Settings.GetEquipmentPassivePool(TierRarity);

            for (const FItemRarityPassive& Passive : Pool)
            {
                if (!Passive.Filter.AppliesTo(Item))
                    continue;
                const FString Attr = AttrNameOf(Passive.Effect);
                if (Attr == "")
                    continue;
                if (!Passive.Effect.IsPositive())
                    continue;
                Accumulate(OutStats, Attr, Passive.Effect);
            }
        }
    }

    bool IsMaxRoll(const TArray<FReforgeAltarStatBest>& Stats, const FPassiveEffect& Effect)
    {
        const FString Attr = AttrNameOf(Effect);
        if (Attr == "")
            return false;
        for (const FReforgeAltarStatBest& S : Stats)
        {
            if (S.AttrName == Attr)
                return Effect.Magnitude + 0.0001f >= S.MaxMagnitude;
        }
        return false;
    }

    // Current substats as text -- each maxed line tagged [MAX], plus an "N/M
    // maxed" summary -- for the altar label and the post-reforge message.
    FString DescribeSubstatsAnnotated(UItemStack Item, UItemRuntimeFragment_Rarity Frag)
    {
        FString Out;
        if (Frag == nullptr)
            return Out;

        TArray<FReforgeAltarStatBest> Best;
        const bool bAnalyze = SupportsMaxAnalysis(Item);
        if (bAnalyze)
            GatherBest(Item, Frag.GetRarity(), Best);

        int Maxed = 0;
        int Analyzable = 0;
        for (const FPassiveEffect& Effect : Frag.RarityEffects)
        {
            const FString Line = Effect.GetLocalizedText().ToString();
            if (bAnalyze && Best.Num() > 0 && AttrNameOf(Effect) != "")
            {
                Analyzable++;
                if (IsMaxRoll(Best, Effect))
                {
                    Maxed++;
                    Out += "\n  " + Line + "  [MAX]";
                }
                else
                {
                    Out += "\n  " + Line;
                }
            }
            else
            {
                Out += "\n  " + Line;
            }
        }

        if (bAnalyze && Analyzable > 0)
            Out += f"\n  ({Maxed}/{Analyzable} maxed)";

        return Out;
    }
}


// -----------------------------------------------------------------------------
//  The altar interaction: rerolls the SELECTED hotbar item on a completed hold.
//  Mirrors UInteraction_VendorBuyItem: server-authoritative pay-then-reward.
// -----------------------------------------------------------------------------
UCLASS()
class UInteraction_ReforgeAltar : UInteraction
{
    UFUNCTION(BlueprintOverride)
    void OnInteractServer(const FInteractionContext& Context)
    {
        APlayerCharacter Player = Cast<APlayerCharacter>(Context.Interactor.Owner);
        if (Player == nullptr || Player.HotbarComp == nullptr)
            return;

        UItemStack Item = Player.HotbarComp.GetSelectedItemStack();
        if (Item == nullptr || !ReforgeAltarCore::IsRerollableGear(Item))
        {
            Print("Reforge: select a STARRED item or familiar in your hotbar.", 4.0, FLinearColor(1.0, 0.55, 0.2, 1.0));
            return;   // nothing charged
        }

        UItemRuntimeFragment_Rarity Frag = Item.GetRuntimeFragment_Rarity();
        const EItemRarity Rarity = Frag.GetRarity();
        const int Cost = ReforgeAltarCore::GetRerollCost(Rarity);
        const FString ItemName = Item.GetItemDefinition().DisplayName.ToString();

        const bool bFamiliar = Item.GetItemDefinition().GetFragment_Familiar() != nullptr;
        UHercEquipmentInstance Inst = bFamiliar ? nullptr : FindEquippedInstance(Player, Item);

        if (ReforgeAltarCore::TryReforge(Player, Item, Frag, Rarity, Inst))
        {
            const FString Subs = ReforgeAltarMax::DescribeSubstatsAnnotated(Item, Frag);
            Print(f"Reforged '{ItemName}'  (-{Cost} coins){Subs}", 6.0, FLinearColor(0.45, 0.8, 1.0, 1.0));
        }
        else
        {
            const int Have = (Player.InventoryComp != nullptr)
                ? Player.InventoryComp.GetTotalItemCountByTag(ReforgeAltarConfig::CostItemTag) : 0;
            Print(f"Can't reforge '{ItemName}': costs {Cost} coins, you have {Have}.", 4.0, FLinearColor(1.0, 0.4, 0.3, 1.0));
        }
    }

    // Matches the item against the player's live equipped instances, so a
    // wielded weapon refreshes after rerolling. Returns null for unequipped gear.
    private UHercEquipmentInstance FindEquippedInstance(APlayerCharacter Player, UItemStack Item)
    {
        if (Player.EquipmentComp == nullptr)
            return nullptr;
        for (UHercEquipmentInstance E : Player.EquipmentComp.GetAllEquippedItems())
        {
            if (E != nullptr && E.ItemStack == Item)
                return E;
        }
        return nullptr;
    }
}

// The summonable altar. Detection + the interact prompt come from the engine's
// UInteractableComponent; the floating UTextRenderComponent label is the visible
// marker (works in Shipping, no UMG asset). The label billboards to the camera.
UCLASS(NotPlaceable, HideCategories = "Replication")
class AReforgeAltarActor : AActor
{
    default bReplicates = true;

    UPROPERTY(DefaultComponent, RootComponent)
    USceneComponent Root;

    UPROPERTY(DefaultComponent)
    UInteractableComponent InteractableComp;

    // Visual model: the selected item's world mesh (see config comment / Tick).
    UPROPERTY(DefaultComponent, Attach = Root)
    UStaticMeshComponent MeshComp;
    default MeshComp.SetCollisionEnabled(ECollisionEnabled::NoCollision);

    // Last mesh / status text applied, so we only update when they change.
    private UStaticMesh ShownMesh;
    private FString LastStatus;
    private bool bInteractable = true;   // is the interaction currently enabled?
    private float DisplayTimer = 0.0;    // throttles the content refresh

    UPROPERTY(DefaultComponent)
    UTextRenderComponent LabelComp;
    default LabelComp.HorizontalAlignment = EHorizTextAligment::EHTA_Center;
    default LabelComp.VerticalAlignment = EVerticalTextAligment::EVRTA_TextCenter;
    default LabelComp.TextRenderColor = FColor(120, 200, 255);

    UFUNCTION(BlueprintOverride)
    void BeginPlay()
    {
        LabelComp.SetRelativeLocation(FVector(0.0, 0.0, ReforgeAltarConfig::AltarLabelHeight));
        LabelComp.WorldSize = ReforgeAltarConfig::AltarLabelSize;
        LabelComp.SetText(FText::FromString("REFORGE"));

        MeshComp.SetRelativeLocation(FVector(0.0, 0.0, ReforgeAltarConfig::AltarMeshHeight));

        // The interaction is server logic; on host / single-player you are the
        // server, which is also the only place reforging works.
        if (!HasAuthority())
            return;

        UInteraction_ReforgeAltar Inter = NewObject(this, UInteraction_ReforgeAltar);
        Inter.InteractionType = EInteractionType::OnActivated;
        // Hold-to-confirm: a sustained interaction so a stray tap does nothing.
        Inter.InteractionDuration = ReforgeAltarConfig::AltarHoldSeconds;
        InteractableComp.SetInteraction(Inter);
    }

    // Keep the label facing the camera so it stays readable from any angle.
    UFUNCTION(BlueprintOverride)
    void Tick(float DeltaTime)
    {
        APlayerController PC = Game::GetLocalPlayerController();
        if (PC == nullptr || PC.PlayerCameraManager == nullptr)
            return;

        const FVector CamLoc = PC.PlayerCameraManager.GetCameraLocation();
        const FVector LabelLoc = LabelComp.GetWorldLocation();

        // Yaw-only billboard: face the camera but stay upright (readable).
        FRotator Face = (CamLoc - LabelLoc).Rotation();
        Face.Pitch = 0.0;
        Face.Roll = 0.0;
        LabelComp.SetWorldRotation(Face);

        DisplayTimer += DeltaTime;
        if (DisplayTimer >= 0.15)
        {
            DisplayTimer = 0.0;
            UpdateDisplay();
        }

        if (ReforgeAltarConfig::AltarSpinDegreesPerSec != 0.0)
            MeshComp.AddRelativeRotation(FRotator(0.0, ReforgeAltarConfig::AltarSpinDegreesPerSec * DeltaTime, 0.0));
    }

    // Refreshes the floating text (current target + cost + your gold) and the
    // spinning model (shown only for rerollable items).
    private void UpdateDisplay()
    {
        APlayerCharacter Player = Game::GetLocalPlayer();
        UItemStack Item = (Player != nullptr && Player.HotbarComp != nullptr)
            ? Player.HotbarComp.GetSelectedItemStack() : nullptr;
        const bool bRerollable = ReforgeAltarCore::IsRerollableGear(Item);
        const int Coins = (Player != nullptr && Player.InventoryComp != nullptr)
            ? Player.InventoryComp.GetTotalItemCountByTag(ReforgeAltarConfig::CostItemTag) : 0;

        // No [F] prompt / hold unless the selected item can actually be reforged.
        if (HasAuthority() && bRerollable != bInteractable)
        {
            bInteractable = bRerollable;
            InteractableComp.SetIsInteractionEnabled(bRerollable);
        }

        UStaticMesh Desired = bRerollable ? MeshOfItem(Item) : nullptr;
        if (Desired != ShownMesh)
        {
            ShownMesh = Desired;
            MeshComp.SetStaticMesh(Desired);
            ApplyNormalizedScale(Desired);
        }

        FString Status;
        if (Item == nullptr)
        {
            Status = f"REFORGE\nselect gear or familiar in hotbar\nGold: {Coins}";
        }
        else
        {
            const FString ItemName = Item.GetItemDefinition().DisplayName.ToString();
            if (bRerollable)
            {
                const FString Subs = ReforgeAltarMax::DescribeSubstatsAnnotated(Item, Item.GetRuntimeFragment_Rarity());
                Status = f"REFORGE: {ItemName}{Subs}\nHOLD Interact ({ReforgeAltarConfig::RerollCost} gold)  -  Gold: {Coins}";
            }
            else
            {
                Status = f"{ItemName}\nno substats to reforge\nGold: {Coins}";
            }
        }

        if (Status != LastStatus)
        {
            LastStatus = Status;
            LabelComp.SetText(FText::FromString(Status));
        }
    }

    // Scale the model so its largest dimension is ~AltarItemTargetSize.
    private void ApplyNormalizedScale(UStaticMesh Mesh)
    {
        if (Mesh == nullptr)
            return;

        const FVector Ext = Mesh.Bounds.BoxExtent;   // half-extents, unscaled
        const float NativeSize = 2.0 * Math::Max(Ext.X, Math::Max(Ext.Y, Ext.Z));
        const float Scale = (NativeSize > 1.0) ? (ReforgeAltarConfig::AltarItemTargetSize / NativeSize) : 1.0;
        MeshComp.SetRelativeScale3D(FVector(Scale, Scale, Scale));
    }

    // World mesh of an item (or null). Familiars typically have no world mesh.
    private UStaticMesh MeshOfItem(UItemStack Item)
    {
        if (Item == nullptr)
            return nullptr;

        const UItemDefinition Def = Item.GetItemDefinition();
        if (Def == nullptr || Def.ActorsToSpawn.IsEmpty())
            return nullptr;

        FItemActorToSpawn Spawn = Def.ActorsToSpawn[0];
        return Spawn.StaticMesh;
    }
}

// -----------------------------------------------------------------------------
//  World input receiver: summons/dismisses the altar (F9). Pressed in the world,
//  where gameplay input is live.
// -----------------------------------------------------------------------------
UCLASS(NotPlaceable, HideCategories = "Actor Tick Rendering Replication Collision Input")
class AReforgeAltarInput : AActor
{
    default bReplicates = false;

    UPROPERTY(DefaultComponent, RootComponent)
    USceneComponent Root;

    UPROPERTY(DefaultComponent)
    UInputComponent InputComp;

    // The currently-summoned altar (if any), so the key toggles it.
    private AReforgeAltarActor SummonedAltar;

    UFUNCTION(BlueprintOverride)
    void BeginPlay()
    {
        APlayerController Controller = Game::GetLocalPlayerController();
        if (Controller == nullptr)
            return;

        Controller.PushInputComponent(InputComp);
        InputComp.BindKey(ReforgeAltarConfig::SummonAltarKey, EInputEvent::IE_Pressed, FInputActionHandlerDynamicSignature(this, n"OnSummonAltar"));
    }

    // Summons the Reforge Altar in front of the player, or dismisses it (toggle).
    UFUNCTION()
    private void OnSummonAltar(FKey Key)
    {
        if (SummonedAltar != nullptr && IsValid(SummonedAltar))
        {
            SummonedAltar.DestroyActor();
            SummonedAltar = nullptr;
            return;
        }

        APlayerCharacter Player = Game::GetLocalPlayer();
        if (Player == nullptr)
            return;

        // In front of the player, facing back toward them so the label reads
        // right-way-round.
        const FVector Location = Player.GetActorLocation() + Player.GetActorForwardVector() * ReforgeAltarConfig::AltarSummonDistance;
        const FRotator Rotation = (Player.GetActorLocation() - Location).Rotation();
        SummonedAltar = Cast<AReforgeAltarActor>(SpawnActor(AReforgeAltarActor, Location, Rotation));
    }
}

// -----------------------------------------------------------------------------
//  Bootstrapper: spawns the input actor once the local player controller exists.
//  (No Developer Mode / ImGui -- the altar works in plain gameplay.)
// -----------------------------------------------------------------------------
class UReforgeAltarController : UScriptWorldSubsystem
{
    private AReforgeAltarInput InputActor;

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
        if (Game::GetLocalPlayerController() == nullptr)
            return;

        if (InputActor != nullptr && IsValid(InputActor))
            return;

        InputActor = Cast<AReforgeAltarInput>(SpawnActor(AReforgeAltarInput));
    }
}
