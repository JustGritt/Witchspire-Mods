// =============================================================================
//  Reforge Cheat GUI  —  reroll starred-gear substats from an ImGui debug panel
//
//  This is the PANEL-ONLY edition of Reforge Gear. It auto-enables Developer
//  Mode and binds F7 to open/close the ImGui debug menu; inside, find
//  "Cheats" -> "Reforge Gear". The panel lists every starred item in your bag
//  and equipment with its current substats and a [Reroll] button. Stars
//  (rarity) are kept; only the substats below the tooltip divider change. Each
//  reroll costs coins (F10 grants test coins).
//
//  Each current substat is tagged [MAX] (green) when it's the best possible roll
//  for that stat on that item, otherwise shown with a "(max: ...)" hint. Each
//  item also gets a collapsible "Best obtainable substats" list (its loot
//  ceiling) and a "Roll quality: N/M maxed" score.
//
//  Companion editions (install only ONE at a time -- see scripts/):
//    - ReforgeAltar.as : a summoned altar you trigger with Interact (no Dev Mode).
//    - ReforgeGear.as  : the combined "full" edition (altar + panel).
//
//  NOTE: single-player / listen-server (host) only -- SetRarity is
//  server-authoritative. No save tampering; it only modifies a live item.
// =============================================================================


namespace ReforgeGuiConfig
{
    // World hotkey that opens/closes the ImGui debug menu (press it in normal
    // gameplay, NOT while a menu is open).
    const FKey ToggleMenuKey = EKeys::F7;

    // Auto-enable Developer Mode on startup so the debug menu (and this panel)
    // is available. Set false if you prefer to enable it yourself.
    const bool bAutoEnableDeveloperMode = true;

    // --- Reforge cost -------------------------------------------------------
    // Each reroll consumes a flat coin cost, checked AND spent host-side before
    // the substats are re-rolled. RerollCost 0 = free (no coins spent, no gating).
    const FGameplayTag CostItemTag = GameplayTags::Items_Coin;
    const int RerollCost = 0;

    // --- Debug: grant coins -------------------------------------------------
    // Press DebugGoldKey to add DebugGoldAmount coins (for testing reforge cost).
    const bool bEnableDebugGold = true;
    const FKey DebugGoldKey = EKeys::F10;
    const int DebugGoldAmount = 1000;
}


// -----------------------------------------------------------------------------
//  Reforge core: cost lookup + the in-place reroll.
// -----------------------------------------------------------------------------
namespace ReforgeGuiCore
{
    int GetRerollCost(EItemRarity Rarity)
    {
        return ReforgeGuiConfig::RerollCost;
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
            if (Inv == nullptr || !Inv.CanRemoveItemsByTag(ReforgeGuiConfig::CostItemTag, Cost))
                return false;
            Inv.RemoveItemsByTag(ReforgeGuiConfig::CostItemTag, Cost);
        }

        UEquipmentInstance EquipInst = (Instance != nullptr) ? Cast<UEquipmentInstance>(Instance) : nullptr;
        if (EquipInst != nullptr)
            EquipInst.HandleUnequipped();

        RarityFrag.SetRarity(Rarity);

        if (EquipInst != nullptr)
            EquipInst.HandleEquipped();

        Log(n"ReforgeCheatGui", f"Rerolled substats on '{Item.GetItemDefinition().DisplayName}' for {Cost} coins.");
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
struct FReforgeGuiStatBest
{
    FString AttrName;     // modified GameplayAttribute name (the group key)
    float MaxMagnitude;   // highest magnitude available for this stat
    FString BestText;     // localized line, e.g. "+50% Spellblade Damage"
}

namespace ReforgeGuiMax
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

    void Accumulate(TArray<FReforgeGuiStatBest>& Stats, const FString& Attr, const FPassiveEffect& Effect)
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
        FReforgeGuiStatBest New;
        New.AttrName = Attr;
        New.MaxMagnitude = Effect.Magnitude;
        New.BestText = Effect.GetLocalizedText().ToString();
        Stats.Add(New);
    }

    void GatherBest(UItemStack Item, EItemRarity ItemRarity, TArray<FReforgeGuiStatBest>& OutStats)
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

    bool IsMaxRoll(const TArray<FReforgeGuiStatBest>& Stats, const FPassiveEffect& Effect)
    {
        const FString Attr = AttrNameOf(Effect);
        if (Attr == "")
            return false;
        for (const FReforgeGuiStatBest& S : Stats)
        {
            if (S.AttrName == Attr)
                return Effect.Magnitude + 0.0001f >= S.MaxMagnitude;
        }
        return false;
    }

    FString BestTextFor(const TArray<FReforgeGuiStatBest>& Stats, const FPassiveEffect& Effect)
    {
        const FString Attr = AttrNameOf(Effect);
        if (Attr == "")
            return "";
        for (const FReforgeGuiStatBest& S : Stats)
        {
            if (S.AttrName == Attr)
                return S.BestText;
        }
        return "";
    }
}


// -----------------------------------------------------------------------------
//  The ImGui window: lists starred gear (bag + equipped) with per-item reroll
//  and the max-roll readouts.
// -----------------------------------------------------------------------------
UCLASS()
class UReforgeGuiWindow : UImGuiDebugMenuWindow
{
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

        if (!System::IsServer())
        {
            ImGui::TextColored(FColor::Red, "Reforging only works on the host / single-player.");
            return;
        }

        ImGui::Text("Reroll the random substats on starred gear.");
        ImGui::TextDisabled("Stars (rarity) are kept; only the substats change.");

        const int Coins = (Player.InventoryComp != nullptr)
            ? Player.InventoryComp.GetTotalItemCountByTag(ReforgeGuiConfig::CostItemTag)
            : 0;
        ImGui::Text(f"Coins: {Coins}");
        ImGui::Separator();

        int Index = 0;
        int Found = 0;

        // --- Equipped gear ---
        if (Player.EquipmentComp != nullptr)
        {
            for (UHercEquipmentInstance Instance : Player.EquipmentComp.GetAllEquippedItems())
            {
                if (Instance == nullptr || Instance.ItemStack == nullptr)
                    continue;
                if (DrawItem(Player, Coins, Instance.ItemStack, Instance, true, Index))
                    Found++;
                Index++;
            }
        }

        // --- Bag gear ---
        if (Player.InventoryComp != nullptr)
        {
            for (UItemStack Item : Player.InventoryComp.AllItemStacks)
            {
                if (Item == nullptr)
                    continue;
                if (DrawItem(Player, Coins, Item, nullptr, false, Index))
                    Found++;
                Index++;
            }
        }

        if (Found == 0)
            ImGui::TextDisabled("No starred gear found (bag or equipped).");
    }

    // ImGui parses its text as a printf format, so a literal '%' -- which EVERY
    // percent substat carries (e.g. "+50% Spellblade Damage") -- is read as a
    // bogus format specifier and HARD-CRASHES the CRT. Double each '%' so the
    // text renders literally. Use for ALL dynamic text passed to ImGui::Text*.
    private FString ImGuiSafe(FString In)
    {
        return In.Replace("%", "%%");
    }

    // Draws one item row; rerolls it if its button is clicked this frame.
    // Returns true if the item was a starred (rerollable) piece of gear.
    private bool DrawItem(APlayerCharacter Player, int Coins, UItemStack Item, UHercEquipmentInstance Instance, bool bEquipped, int Index)
    {
        UItemRuntimeFragment_Rarity RarityFrag = Item.GetRuntimeFragment_Rarity();
        if (RarityFrag == nullptr)
            return false;

        const EItemRarity Rarity = RarityFrag.GetRarity();
        const int Stars = int(Rarity);
        if (Stars <= int(EItemRarity::Common))
            return false;

        FString StarStr;
        for (int i = 0; i < Stars; i++)
            StarStr += "*";

        const FString ItemName = ImGuiSafe(Item.GetItemDefinition().DisplayName.ToString());
        const FString Where = bEquipped ? "(equipped)" : "(bag)";
        ImGui::Text(f"{ItemName}  [{StarStr}]  {Where}");

        ImGui::Indent();

        // Max-roll analysis (gear only; familiars roll from a different pool).
        TArray<FReforgeGuiStatBest> Best;
        ReforgeGuiMax::GatherBest(Item, Rarity, Best);
        const bool bAnalyze = ReforgeGuiMax::SupportsMaxAnalysis(Item) && Best.Num() > 0;

        int Maxed = 0;
        int Analyzable = 0;
        for (const FPassiveEffect& Effect : RarityFrag.RarityEffects)
        {
            const FString Line = ImGuiSafe(Effect.GetLocalizedText().ToString());
            if (bAnalyze && ReforgeGuiMax::AttrNameOf(Effect) != "")
            {
                Analyzable++;
                if (ReforgeGuiMax::IsMaxRoll(Best, Effect))
                {
                    Maxed++;
                    ImGui::TextColored(FColor(90, 220, 120), f"- {Line}  [MAX]");
                }
                else
                {
                    ImGui::TextColored(FColor::Yellow, f"- {Line}");
                    const FString BestLine = ImGuiSafe(ReforgeGuiMax::BestTextFor(Best, Effect));
                    if (BestLine != "")
                    {
                        ImGui::SameLine();
                        ImGui::TextDisabled(f"(max: {BestLine})");
                    }
                }
            }
            else
            {
                ImGui::TextColored(FColor::Yellow, f"- {Line}");
            }
        }

        // God-roll score: how many substats are already at their best value.
        if (bAnalyze && Analyzable > 0)
        {
            const bool bPerfect = (Maxed == Analyzable);
            const FColor ScoreColor = bPerfect ? FColor(90, 220, 120) : FColor(255, 180, 60);
            const FString Tail = bPerfect ? "  *** PERFECT ***" : "";
            ImGui::TextColored(ScoreColor, f"Roll quality: {Maxed}/{Analyzable} maxed{Tail}");
        }

        // Best obtainable substats for THIS item (the loot ceiling), collapsible.
        if (bAnalyze && ImGui::CollapsingHeader(f"Best obtainable substats ({Best.Num()})###best{Index}"))
        {
            ImGui::Indent();
            for (const FReforgeGuiStatBest& S : Best)
            {
                const FString BestText = ImGuiSafe(S.BestText);
                ImGui::TextColored(FColor(90, 220, 120), f"- {BestText}");
            }
            ImGui::Unindent();
        }

        // Reforge cost for this rarity, gated against the player's balance.
        const int Cost = ReforgeGuiCore::GetRerollCost(Rarity);
        const bool bCanAfford = Coins >= Cost;

        // Unique ImGui ID per row via "##<index>" so identical labels don't clash.
        if (!bCanAfford)
            ImGui::BeginDisabled();
        if (ImGui::Button(f"Reroll##{Index}"))
        {
            ReforgeGuiCore::TryReforge(Player, Item, RarityFrag, Rarity, Instance);
        }
        if (!bCanAfford)
            ImGui::EndDisabled();

        // Price tag next to the button: dimmed when affordable, red otherwise.
        ImGui::SameLine();
        if (bCanAfford)
            ImGui::TextDisabled(f"Cost: {Cost} coins");
        else
            ImGui::TextColored(FColor::Red, f"Cost: {Cost} coins (need {Cost - Coins} more)");
        ImGui::Unindent();
        ImGui::Separator();
        return true;
    }
}

// -----------------------------------------------------------------------------
//  Registers the "Reforge Gear" window under Cheats in the ImGui debug menu.
// -----------------------------------------------------------------------------
UCLASS()
class UReforgeGuiMenuSubsystem : UImGuiPersistentMenuSubsystem
{
    default WindowName = n"Reforge Gear";
    default WindowClass = UReforgeGuiWindow;
    default MenuPath = "Cheats|Reforge Gear";
}

// -----------------------------------------------------------------------------
//  World input receiver: opens/closes the ImGui debug menu (F7) and grants debug
//  gold (F10). Pressed in the world, where gameplay input is live.
// -----------------------------------------------------------------------------
UCLASS(NotPlaceable, HideCategories = "Actor Tick Rendering Replication Collision Input")
class AReforgeGuiInput : AActor
{
    default bReplicates = false;

    UPROPERTY(DefaultComponent, RootComponent)
    USceneComponent Root;

    UPROPERTY(DefaultComponent)
    UInputComponent InputComp;

    UFUNCTION(BlueprintOverride)
    void BeginPlay()
    {
        APlayerController Controller = Game::GetLocalPlayerController();
        if (Controller == nullptr)
            return;

        Controller.PushInputComponent(InputComp);
        InputComp.BindKey(ReforgeGuiConfig::ToggleMenuKey, EInputEvent::IE_Pressed, FInputActionHandlerDynamicSignature(this, n"OnToggleMenu"));

        if (ReforgeGuiConfig::bEnableDebugGold)
            InputComp.BindKey(ReforgeGuiConfig::DebugGoldKey, EInputEvent::IE_Pressed, FInputActionHandlerDynamicSignature(this, n"OnDebugGold"));
    }

    // Debug: drop a chunk of coins into the inventory for testing reforge costs.
    UFUNCTION()
    private void OnDebugGold(FKey Key)
    {
        if (!System::IsServer())
            return;

        APlayerCharacter Player = Game::GetLocalPlayer();
        if (Player == nullptr || Player.InventoryComp == nullptr)
            return;

        Player.InventoryComp.AddItemsByTag(ReforgeGuiConfig::CostItemTag, ReforgeGuiConfig::DebugGoldAmount);

        const int Have = Player.InventoryComp.GetTotalItemCountByTag(ReforgeGuiConfig::CostItemTag);
        Print(f"Debug: +{ReforgeGuiConfig::DebugGoldAmount} coins (now {Have}).", 3.0, FLinearColor(1.0, 0.85, 0.2, 1.0));
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
}

// -----------------------------------------------------------------------------
//  Bootstrapper: auto-enables Developer Mode, spawns the input actor, and shares
//  keyboard input with the game while the ImGui menu is open (so the toggle key
//  can close it again).
// -----------------------------------------------------------------------------
class UReforgeGuiController : UScriptWorldSubsystem
{
    private AReforgeGuiInput InputActor;
    private bool bDevModeSet = false;

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
        // Keep keyboard input flowing to the game (so our toggle key works)
        // except when ImGui is actively capturing it (e.g. a text field).
        if (ImGuiModule::IsInputEnabled())
            ImGuiModule::SetKeyboardInputShared(!ImGui::IsKeyboardCaptured());

        if (Game::GetLocalPlayerController() == nullptr)
            return;

        if (!bDevModeSet && ReforgeGuiConfig::bAutoEnableDeveloperMode)
        {
            CVar::Cheats::DeveloperMode.SetBool(true);
            bDevModeSet = true;
        }

        if (InputActor != nullptr && IsValid(InputActor))
            return;

        InputActor = Cast<AReforgeGuiInput>(SpawnActor(AReforgeGuiInput));
    }
}
