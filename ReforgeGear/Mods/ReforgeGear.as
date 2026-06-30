// =============================================================================
//  Reforge Gear  —  reroll the random substats on starred gear (ImGui panel)
//
//  Gear with stars (Rare / Epic / Legendary) carries random "substats": the
//  bonuses listed BELOW the divider in the tooltip (e.g. +40% Crit Damage,
//  +30 Max Health, +15% Wand Damage). The game stores these as the item's
//  rarity "passive effects"; the count matches the star count
//  (Rare = 1, Epic = 2, Legendary = 3).
//
//  This mod adds a "Reforge Gear" panel to the in-game ImGui debug menu. It
//  lists every starred item in your bag and equipment, shows its current
//  substats, and gives each a [Reroll] button. Rerolling keeps the item's
//  rarity (its stars) and re-rolls ONLY the substats. The stats ABOVE the
//  divider (the item's fixed base stats) are never touched.
//
//  WHY A PANEL AND NOT A HOTKEY?  The game freezes gameplay input while the
//  inventory is open, so no script hotkey can fire while you'd be picking an
//  item there. The ImGui debug menu, by contrast, runs its own input layer and
//  is opened from the world -- so it can both target a specific item AND react
//  to clicks. The trade-off is that it lives behind the game's Developer Mode.
//
//  HOW TO OPEN IT:
//    - This mod auto-enables Developer Mode (Herc.Cheats.DeveloperMode) and
//      binds a world hotkey (default F8) that opens/closes the debug menu.
//    - Press F8 (in normal gameplay, not in a menu). The ImGui menu appears;
//      find "Cheats" -> "Reforge Gear".
//    - The game's own debug-menu key also works once Developer Mode is on.
//
//  HOW THE REROLL WORKS:
//    - UItemStack::GetRuntimeFragment_Rarity()         -> the rarity fragment.
//    - RarityFrag.SetRarity(RarityFrag.GetRarity())     -> empties RarityEffects
//      and re-rolls them from the same rarity pool (ItemRaritySettings.as,
//      RollPassiveEffects). Same stars, fresh substats.
//    - For EQUIPPED gear, the equipment instance is refreshed in place
//      (HandleUnequipped -> reroll -> HandleEquipped) so the new substats apply
//      to your live stats immediately, without moving the item.
//
//  NOTE: single-player / listen-server (host) only -- SetRarity is
//  server-authoritative. No save tampering; it only modifies a live item.
// =============================================================================


namespace ReforgeGearConfig
{
    // World hotkey that opens/closes the ImGui debug menu (press it in normal
    // gameplay, NOT while a menu is open). Set to any key, e.g. EKeys::F7,
    // EKeys::F6, EKeys::O ...
    const FKey ToggleMenuKey = EKeys::F7;

    // Auto-enable Developer Mode on startup so the debug menu (and this panel)
    // is available. Set false if you prefer to enable it yourself.
    const bool bAutoEnableDeveloperMode = true;

    // --- Reforge cost -------------------------------------------------------
    // Each reroll consumes a flat coin cost from your inventory, checked AND
    // spent host-side before the substats are re-rolled; you can't reroll what
    // you can't afford. Set RerollCost to 0 to make reforging free again.
    //
    // CostItemTag is the currency spent. Default Items_Coin -- the same coins
    // NPC vendors charge. Any valid item gameplay tag works (e.g. a material).
    const FGameplayTag CostItemTag = GameplayTags::Items_Coin;

    // Flat coin cost per reroll, the same for every rarity.
    const int RerollCost = 100;

    // --- Reforge Altar (no Developer Mode needed) ---------------------------
    // A world object you summon and interact with to reforge the item you have
    // SELECTED in your hotbar, so reforging works in normal gameplay without the
    // ImGui debug menu. See the AReforgeAltar comment for why we target the
    // selected hotbar slot (a script mod can't ship a clickable item picker
    // without Developer Mode).
    const bool bEnableReforgeAltar = true;

    // World hotkey that summons / dismisses the altar in front of you. Select the
    // gear in your hotbar, then press the game's normal Interact key to reforge.
    const FKey SummonAltarKey = EKeys::F9;

    // Hold-to-confirm: how long (seconds) you must HOLD the Interact key on the
    // altar before it reforges -- so an accidental tap does nothing. The game
    // shows a fill/progress indicator while you hold. Set 0 for instant (no
    // confirmation).
    const float AltarHoldSeconds = 0.75;

    // The altar shows the 3D model of the item you currently have SELECTED in your
    // hotbar -- i.e. the thing you're about to reforge -- floating and spinning
    // above it. (A script-only mod can't load arbitrary cooked meshes like a
    // workbench or ritual circle by path in the shipping build, so we reuse the
    // live item's own world mesh, which IS reachable from script.) No item
    // selected, or a mesh-less item -> just the floating text label.
    // Each item's model is auto-scaled so its LARGEST dimension is about this
    // many cm -- so a huge sword and a tiny trinket all show at a consistent
    // size on the altar (instead of using each item's raw, wildly-varying mesh).
    const float AltarItemTargetSize = 60.0;
    const float AltarSpinDegreesPerSec = 45.0;   // slow spin; 0 to disable

    // Vertical layout (cm above the altar base), so the spinning item and the
    // floating text don't overlap. Item sits lower; text floats above it.
    const float AltarMeshHeight  = 50.0;
    const float AltarLabelHeight = 165.0;
    const float AltarLabelSize   = 32.0;   // text WorldSize (smaller = less huge)

    // How far in front of you the altar is summoned (cm). Smaller = closer/lower
    // on sloped ground.
    const float AltarSummonDistance = 150.0;

    // --- Debug: grant coins -------------------------------------------------
    // A testing convenience: press DebugGoldKey to add DebugGoldAmount coins to
    // your inventory (works without Developer Mode). Set bEnableDebugGold = false
    // to remove the hotkey for "real" play.
    const bool bEnableDebugGold = true;
    const FKey DebugGoldKey = EKeys::F10;
    const int DebugGoldAmount = 1000;
}


// -----------------------------------------------------------------------------
//  Shared reforge core: cost lookup + the in-place reroll, used by BOTH the
//  ImGui panel and the Reforge Altar so the logic lives in one place.
// -----------------------------------------------------------------------------
namespace ReforgeCore
{
    // Flat coin cost for a reroll (same for every rarity). The Rarity param is
    // kept so callers don't change if per-rarity pricing is ever reintroduced.
    int GetRerollCost(EItemRarity Rarity)
    {
        return ReforgeGearConfig::RerollCost;
    }

    // One line per current substat (the item's rarity passive effects), each
    // prefixed with a newline so it can be appended to a message. Empty if none.
    FString DescribeSubstats(UItemRuntimeFragment_Rarity Frag)
    {
        FString Out;
        if (Frag == nullptr)
            return Out;
        for (const FPassiveEffect& Effect : Frag.RarityEffects)
            Out += "\n  " + Effect.GetLocalizedText().ToString();
        return Out;
    }

    // Is this a starred (rerollable) item? Anything with a rarity fragment above
    // Common -- gear AND familiars (both store substats as RarityEffects and roll
    // them the same way via SetRarity). Items with no substats (potions, mats)
    // have no rarity fragment, so they're excluded.
    bool IsRerollableGear(UItemStack Item)
    {
        if (Item == nullptr)
            return false;
        UItemRuntimeFragment_Rarity Frag = Item.GetRuntimeFragment_Rarity();
        if (Frag == nullptr)
            return false;
        return int(Frag.GetRarity()) > int(EItemRarity::Common);
    }

    // Charges the rarity-scaled coin cost (host-side) and rerolls the item's
    // substats in place, keeping its rarity. Pass the equipment Instance for
    // equipped gear (so live stats refresh); pass nullptr for bag gear. Returns
    // true only if the coins were paid and the reroll happened.
    bool TryReforge(APlayerCharacter Player, UItemStack Item, UItemRuntimeFragment_Rarity RarityFrag, EItemRarity Rarity, UHercEquipmentInstance Instance)
    {
        // SetRarity is server-authoritative; on host / single-player you are the
        // server. Re-check here so a stale UI can never reroll for free.
        if (!System::IsServer() || Player == nullptr || RarityFrag == nullptr)
            return false;

        const int Cost = GetRerollCost(Rarity);
        if (Cost > 0)
        {
            UInventoryComponent Inv = Player.InventoryComp;
            if (Inv == nullptr || !Inv.CanRemoveItemsByTag(ReforgeGearConfig::CostItemTag, Cost))
                return false;
            Inv.RemoveItemsByTag(ReforgeGearConfig::CostItemTag, Cost);
        }

        UEquipmentInstance EquipInst = (Instance != nullptr) ? Cast<UEquipmentInstance>(Instance) : nullptr;

        // Equipped: strip the live effects first so we can cleanly re-apply.
        if (EquipInst != nullptr)
            EquipInst.HandleUnequipped();

        // Same rarity in -> same stars, freshly rolled substats out.
        RarityFrag.SetRarity(Rarity);

        // Equipped: re-grant so the new substats hit your live stats now.
        if (EquipInst != nullptr)
            EquipInst.HandleEquipped();

        Log(n"ReforgeGear", f"Rerolled substats on '{Item.GetItemDefinition().DisplayName}' for {Cost} coins.");
        return true;
    }
}


// -----------------------------------------------------------------------------
//  Max-roll analysis.
//
//  A starred item's substats come from FIXED, discrete, weighted pools
//  (UItemRaritySettings), NOT a min/max range. Each possible substat is its own
//  pool entry with a baked-in magnitude -- so "+50% Spellblade Damage" and
//  "+25% Spellblade Damage" are two SEPARATE entries, not one stat that rolled
//  high vs low. That makes the BEST obtainable value for every stat fully
//  knowable: enumerate the entries this item can draw (filtered, per rarity
//  tier) and take the highest magnitude per stat.
//
//  A starred item draws ONE substat per star, each from a different tier pool:
//  Rare draws {Rare}; Epic draws {Epic, Rare}; Legendary draws {Legendary,
//  Epic, Rare}  (see ItemRaritySettings::RollPassiveEffects). So the ceiling for
//  a stat ON A GIVEN ITEM = the max magnitude across the tier pools it spans --
//  which is why a Legendary's Spellblade ceiling can exceed a Rare's.
//
//  ASSUMPTION: higher magnitude = better. Holds for every bonus stat (damage,
//  crit, attack speed, health...). We only consider POSITIVE effects for the
//  max, so a rare penalty roll is never mislabelled "best".
//
//  Familiars roll from a separate pool keyed on the familiar actor (a different
//  filter type), so max analysis is limited to GEAR; familiars still reroll.
// -----------------------------------------------------------------------------
// The best (highest-magnitude) obtainable roll for one stat on an item. Kept at
// global scope (not inside the namespace) so the panel can name the type plainly.
struct FReforgeStatBest
{
    FString AttrName;     // modified GameplayAttribute name (the group key)
    float MaxMagnitude;   // highest magnitude available for this stat
    FString BestText;     // its localized line, e.g. "+50% Spellblade Damage"
}

namespace ReforgeMax
{
    // Familiars use a different (familiar-actor) pool + filter; restrict the max
    // analysis to gear so we never compare a substat against the wrong pool.
    bool SupportsMaxAnalysis(UItemStack Item)
    {
        if (Item == nullptr)
            return false;
        const UItemDefinition Def = Item.GetItemDefinition();
        if (Def == nullptr)
            return false;
        return Def.GetFragment_Familiar() == nullptr;
    }

    // The modified attribute's name for a passive effect, or "" if it isn't a
    // single-attribute effect we can reason about. Mirrors how the game localizes
    // effects (one modifier per effect; see LocalizationGameplayEffects).
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

    // Records Effect as the best for its stat if it beats the current entry.
    void Accumulate(TArray<FReforgeStatBest>& Stats, const FString& Attr, const FPassiveEffect& Effect)
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
        FReforgeStatBest New;
        New.AttrName = Attr;
        New.MaxMagnitude = Effect.Magnitude;
        New.BestText = Effect.GetLocalizedText().ToString();
        Stats.Add(New);
    }

    // Builds the best-obtainable table for every stat this item can roll.
    void GatherBest(UItemStack Item, EItemRarity ItemRarity, TArray<FReforgeStatBest>& OutStats)
    {
        OutStats.Empty();
        if (!SupportsMaxAnalysis(Item))
            return;

        const UItemRaritySettings Settings = Game::GetGameInstance().ItemRaritySettings;
        if (Settings == nullptr)
            return;

        // Wands / spellblades / tools (player-action items) draw from the Item
        // pool; worn gear draws from the Equipment pool -- the same split the
        // roll uses (ItemRaritySettings::RollPassiveEffect).
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

    // Is this current substat already at the best value its stat can reach?
    bool IsMaxRoll(const TArray<FReforgeStatBest>& Stats, const FPassiveEffect& Effect)
    {
        const FString Attr = AttrNameOf(Effect);
        if (Attr == "")
            return false;
        for (const FReforgeStatBest& S : Stats)
        {
            if (S.AttrName == Attr)
                return Effect.Magnitude + 0.0001f >= S.MaxMagnitude;
        }
        return false;
    }

    // The localized "best obtainable" line for this substat's stat ("" if none).
    FString BestTextFor(const TArray<FReforgeStatBest>& Stats, const FPassiveEffect& Effect)
    {
        const FString Attr = AttrNameOf(Effect);
        if (Attr == "")
            return "";
        for (const FReforgeStatBest& S : Stats)
        {
            if (S.AttrName == Attr)
                return S.BestText;
        }
        return "";
    }

    // Current substats as text -- each maxed line tagged [MAX], plus an "N/M
    // maxed" summary -- for the altar label and the post-reforge message. Falls
    // back to plain lines for items we can't analyze (familiars).
    FString DescribeSubstatsAnnotated(UItemStack Item, UItemRuntimeFragment_Rarity Frag)
    {
        FString Out;
        if (Frag == nullptr)
            return Out;

        TArray<FReforgeStatBest> Best;
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
//  The ImGui window: lists starred gear (bag + equipped) with per-item reroll.
// -----------------------------------------------------------------------------
UCLASS()
class UReforgeGearWindow : UImGuiDebugMenuWindow
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

        // Current balance of the currency a reroll costs. Re-read each frame so
        // it updates the moment a reroll spends some.
        const int Coins = (Player.InventoryComp != nullptr)
            ? Player.InventoryComp.GetTotalItemCountByTag(ReforgeGearConfig::CostItemTag)
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
        TArray<FReforgeStatBest> Best;
        ReforgeMax::GatherBest(Item, Rarity, Best);
        const bool bAnalyze = ReforgeMax::SupportsMaxAnalysis(Item) && Best.Num() > 0;

        int Maxed = 0;
        int Analyzable = 0;
        for (const FPassiveEffect& Effect : RarityFrag.RarityEffects)
        {
            const FString Line = ImGuiSafe(Effect.GetLocalizedText().ToString());
            if (bAnalyze && ReforgeMax::AttrNameOf(Effect) != "")
            {
                Analyzable++;
                if (ReforgeMax::IsMaxRoll(Best, Effect))
                {
                    Maxed++;
                    ImGui::TextColored(FColor(90, 220, 120), f"- {Line}  [MAX]");
                }
                else
                {
                    ImGui::TextColored(FColor::Yellow, f"- {Line}");
                    const FString BestLine = ImGuiSafe(ReforgeMax::BestTextFor(Best, Effect));
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
            for (const FReforgeStatBest& S : Best)
            {
                const FString BestText = ImGuiSafe(S.BestText);
                ImGui::TextColored(FColor(90, 220, 120), f"- {BestText}");
            }
            ImGui::Unindent();
        }

        // Reforge cost for this rarity, gated against the player's balance.
        const int Cost = ReforgeCore::GetRerollCost(Rarity);
        const bool bCanAfford = Coins >= Cost;

        // Unique ImGui ID per row via "##<index>" so identical labels don't clash.
        if (!bCanAfford)
            ImGui::BeginDisabled();
        if (ImGui::Button(f"Reroll##{Index}"))
        {
            ReforgeCore::TryReforge(Player, Item, RarityFrag, Rarity, Instance);
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
//  (Mirrors UItemGranterDebugMenu.)
// -----------------------------------------------------------------------------
UCLASS()
class UReforgeGearMenuSubsystem : UImGuiPersistentMenuSubsystem
{
    default WindowName = n"Reforge Gear";
    default WindowClass = UReforgeGearWindow;
    default MenuPath = "Cheats|Reforge Gear";
}

// -----------------------------------------------------------------------------
//  REFORGE ALTAR (no Developer Mode)
//
//  A world object you summon with a hotkey and trigger with the game's normal
//  Interact key. Each interact rerolls the item you currently have SELECTED in
//  your hotbar -- so reforging works in plain gameplay without the ImGui debug
//  menu / Developer Mode.
//
//  HOW TO TARGET AN ITEM: put the gear you want to reforge in a hotbar slot and
//  select that slot (the item you'd "wield"). Interacting reforges exactly that
//  item, and nothing else. Spam interact to chase substats.
//
//  WHY "the selected hotbar item" (no free item picker)?  Picking an arbitrary
//  bag item needs a clickable on-screen list, and a script-only mod can't ship a
//  Widget Blueprint into the cooked build (nor is there a generic show-list UI
//  hook). The selected hotbar slot, by contrast, IS addressable from script
//  (UHotbarComponent::GetSelectedItemStack), so it's our picker-free "target".
//  The ImGui panel (Developer Mode) remains for full bag/equipped control.
// -----------------------------------------------------------------------------
UCLASS()
class UInteraction_ReforgeSelected : UInteraction
{
    // Mirrors UInteraction_VendorBuyItem: server-authoritative pay-then-reward.
    UFUNCTION(BlueprintOverride)
    void OnInteractServer(const FInteractionContext& Context)
    {
        APlayerCharacter Player = Cast<APlayerCharacter>(Context.Interactor.Owner);
        if (Player == nullptr || Player.HotbarComp == nullptr)
            return;

        // The item in the currently-selected hotbar slot is our target. (The
        // altar's own label shows live status; here we just do it + Print result.)
        UItemStack Item = Player.HotbarComp.GetSelectedItemStack();
        if (Item == nullptr || !ReforgeCore::IsRerollableGear(Item))
        {
            Print("Reforge: select a STARRED item or familiar in your hotbar.", 4.0, FLinearColor(1.0, 0.55, 0.2, 1.0));
            return;   // nothing charged
        }

        UItemRuntimeFragment_Rarity Frag = Item.GetRuntimeFragment_Rarity();
        const EItemRarity Rarity = Frag.GetRarity();
        const int Cost = ReforgeCore::GetRerollCost(Rarity);
        const FString ItemName = Item.GetItemDefinition().DisplayName.ToString();

        // For GEAR that's currently equipped (e.g. the wielded weapon), pass its
        // instance so live stats refresh. For FAMILIARS we don't touch the
        // equipment instance (their substats re-apply when the familiar is next
        // summoned) -- so just reroll the item in place.
        const bool bFamiliar = Item.GetItemDefinition().GetFragment_Familiar() != nullptr;
        UHercEquipmentInstance Inst = bFamiliar ? nullptr : FindEquippedInstance(Player, Item);

        if (ReforgeCore::TryReforge(Player, Item, Frag, Rarity, Inst))
        {
            // After the reroll, Frag.RarityEffects holds the freshly-rolled
            // substats -- show them so you can see what you got.
            const FString Subs = ReforgeMax::DescribeSubstatsAnnotated(Item, Frag);
            Print(f"Reforged '{ItemName}'  (-{Cost} coins){Subs}", 6.0, FLinearColor(0.45, 0.8, 1.0, 1.0));
        }
        else
        {
            const int Have = (Player.InventoryComp != nullptr)
                ? Player.InventoryComp.GetTotalItemCountByTag(ReforgeGearConfig::CostItemTag) : 0;
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
// UInteractableComponent (a capsule on the "Interactable" collision layer); the
// floating UTextRenderComponent label is the visible marker (works in Shipping,
// no UMG asset -- same approach as LingerChanceIndicator). The label billboards
// to the camera each frame so it's always readable.
UCLASS(NotPlaceable, HideCategories = "Replication")
class AReforgeAltar : AActor
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
        // Text floats high; item floats lower -- so they don't overlap. The text
        // itself is a live status set each frame in UpdateDisplay().
        LabelComp.SetRelativeLocation(FVector(0.0, 0.0, ReforgeGearConfig::AltarLabelHeight));
        LabelComp.WorldSize = ReforgeGearConfig::AltarLabelSize;
        LabelComp.SetText(FText::FromString("REFORGE"));

        // The mesh (selected item's model) and its per-item normalized scale are
        // set in Tick; just fix its height here so it floats below the text.
        MeshComp.SetRelativeLocation(FVector(0.0, 0.0, ReforgeGearConfig::AltarMeshHeight));

        // The interaction is server logic; on host / single-player you are the
        // server, which is also the only place reforging works.
        if (!HasAuthority())
            return;

        UInteraction_ReforgeSelected Inter = NewObject(this, UInteraction_ReforgeSelected);
        Inter.InteractionType = EInteractionType::OnActivated;
        // Hold-to-confirm: a sustained interaction (duration > 0) so a stray tap
        // does nothing -- the game shows a fill bar while you hold, and only a
        // completed hold fires the reroll.
        Inter.InteractionDuration = ReforgeGearConfig::AltarHoldSeconds;
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

        // Refresh label / model / interactivity a few times a second (the
        // substat readout reads localized text, so not worth doing every frame).
        DisplayTimer += DeltaTime;
        if (DisplayTimer >= 0.15)
        {
            DisplayTimer = 0.0;
            UpdateDisplay();
        }

        // Slowly spin the model for a "magical floating" look.
        if (ReforgeGearConfig::AltarSpinDegreesPerSec != 0.0)
            MeshComp.AddRelativeRotation(FRotator(0.0, ReforgeGearConfig::AltarSpinDegreesPerSec * DeltaTime, 0.0));
    }

    // Refreshes the floating text (current target + cost + your gold) and the
    // spinning model (shown only for rerollable items, so potions/mats don't
    // appear on the altar). Both only change when their content changes.
    private void UpdateDisplay()
    {
        APlayerCharacter Player = Game::GetLocalPlayer();
        UItemStack Item = (Player != nullptr && Player.HotbarComp != nullptr)
            ? Player.HotbarComp.GetSelectedItemStack() : nullptr;
        const bool bRerollable = ReforgeCore::IsRerollableGear(Item);
        const int Coins = (Player != nullptr && Player.InventoryComp != nullptr)
            ? Player.InventoryComp.GetTotalItemCountByTag(ReforgeGearConfig::CostItemTag) : 0;

        // Make the altar non-interactable (no [F] prompt, no hold) unless the
        // selected item can actually be reforged.
        if (HasAuthority() && bRerollable != bInteractable)
        {
            bInteractable = bRerollable;
            InteractableComp.SetIsInteractionEnabled(bRerollable);
        }

        // Model: only rerollable items get shown on the altar.
        UStaticMesh Desired = bRerollable ? MeshOfItem(Item) : nullptr;
        if (Desired != ShownMesh)
        {
            ShownMesh = Desired;
            MeshComp.SetStaticMesh(Desired);
            ApplyNormalizedScale(Desired);
        }

        // Status text -- for a rerollable pick it lists the item's CURRENT
        // substats, so you can read them and watch them change after each reforge.
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
                const FString Subs = ReforgeMax::DescribeSubstatsAnnotated(Item, Item.GetRuntimeFragment_Rarity());
                Status = f"REFORGE: {ItemName}{Subs}\nHOLD Interact ({ReforgeGearConfig::RerollCost} gold)  -  Gold: {Coins}";
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

    // Scale the model so its largest dimension is ~AltarItemTargetSize, so big
    // and small items all show at a consistent size (uses the mesh's native
    // bounds; see Building.as for the same Bounds.BoxExtent access).
    private void ApplyNormalizedScale(UStaticMesh Mesh)
    {
        if (Mesh == nullptr)
            return;

        const FVector Ext = Mesh.Bounds.BoxExtent;   // half-extents, unscaled
        const float NativeSize = 2.0 * Math::Max(Ext.X, Math::Max(Ext.Y, Ext.Z));
        const float Scale = (NativeSize > 1.0) ? (ReforgeGearConfig::AltarItemTargetSize / NativeSize) : 1.0;
        MeshComp.SetRelativeScale3D(FVector(Scale, Scale, Scale));
    }

    // World mesh of an item (or null). Familiars typically have no world mesh
    // (they spawn as actors), so they just show the text label.
    private UStaticMesh MeshOfItem(UItemStack Item)
    {
        if (Item == nullptr)
            return nullptr;

        // GetItemDefinition() returns a const handle -- hold it as const.
        const UItemDefinition Def = Item.GetItemDefinition();
        if (Def == nullptr || Def.ActorsToSpawn.IsEmpty())
            return nullptr;

        // Copy the struct to a non-const local before reading its mesh handle
        // (same as NPCVendor) so the const Def doesn't taint the return value.
        FItemActorToSpawn Spawn = Def.ActorsToSpawn[0];
        return Spawn.StaticMesh;
    }
}

// -----------------------------------------------------------------------------
//  World input receiver: opens/closes the ImGui debug menu with a hotkey.
//  (Mirrors the engine's DebugMenuToggleAbility, driven by a non-consuming
//  BindKey like the QuickDeposit mod -- this is pressed in the world, where
//  gameplay input is live.)
// -----------------------------------------------------------------------------
UCLASS(NotPlaceable, HideCategories = "Actor Tick Rendering Replication Collision Input")
class AReforgeGearInput : AActor
{
    default bReplicates = false;

    UPROPERTY(DefaultComponent, RootComponent)
    USceneComponent Root;

    UPROPERTY(DefaultComponent)
    UInputComponent InputComp;

    // The currently-summoned altar (if any), so the key toggles it.
    private AReforgeAltar SummonedAltar;

    UFUNCTION(BlueprintOverride)
    void BeginPlay()
    {
        APlayerController Controller = Game::GetLocalPlayerController();
        if (Controller == nullptr)
            return;

        Controller.PushInputComponent(InputComp);
        InputComp.BindKey(ReforgeGearConfig::ToggleMenuKey, EInputEvent::IE_Pressed, FInputActionHandlerDynamicSignature(this, n"OnToggleMenu"));

        if (ReforgeGearConfig::bEnableReforgeAltar)
            InputComp.BindKey(ReforgeGearConfig::SummonAltarKey, EInputEvent::IE_Pressed, FInputActionHandlerDynamicSignature(this, n"OnSummonAltar"));

        if (ReforgeGearConfig::bEnableDebugGold)
            InputComp.BindKey(ReforgeGearConfig::DebugGoldKey, EInputEvent::IE_Pressed, FInputActionHandlerDynamicSignature(this, n"OnDebugGold"));
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

        Player.InventoryComp.AddItemsByTag(ReforgeGearConfig::CostItemTag, ReforgeGearConfig::DebugGoldAmount);

        const int Have = Player.InventoryComp.GetTotalItemCountByTag(ReforgeGearConfig::CostItemTag);
        Print(f"Debug: +{ReforgeGearConfig::DebugGoldAmount} coins (now {Have}).", 3.0, FLinearColor(1.0, 0.85, 0.2, 1.0));
    }

    // Summons the Reforge Altar in front of the player, or dismisses it if one
    // is already out (toggle).
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
        const FVector Location = Player.GetActorLocation() + Player.GetActorForwardVector() * ReforgeGearConfig::AltarSummonDistance;
        const FRotator Rotation = (Player.GetActorLocation() - Location).Rotation();
        SummonedAltar = Cast<AReforgeAltar>(SpawnActor(AReforgeAltar, Location, Rotation));
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
//  Bootstrapper: auto-enables Developer Mode, spawns the input actor once the
//  local player controller exists, and shares keyboard input with the game
//  while the ImGui menu is open (so the toggle key can close it again).
// -----------------------------------------------------------------------------
class UReforgeGearController : UScriptWorldSubsystem
{
    private AReforgeGearInput InputActor;
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

        if (!bDevModeSet && ReforgeGearConfig::bAutoEnableDeveloperMode)
        {
            CVar::Cheats::DeveloperMode.SetBool(true);
            bDevModeSet = true;
        }

        if (InputActor != nullptr && IsValid(InputActor))
            return;

        InputActor = Cast<AReforgeGearInput>(SpawnActor(AReforgeGearInput));
    }
}
