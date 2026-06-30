// =============================================================================
//  God Forge  —  grant any gear OR familiar with the EXACT substats you choose
//
//  The game's native "Cheats -> Item Granter" can spawn any item at any rarity,
//  but the substats are still rolled RANDOMLY -- so you can ask for a Legendary
//  ring, but not a Legendary ring *with attack speed*. God Forge closes that gap,
//  for weapons, armor, accessories AND familiars.
//
//  Press F8 in normal gameplay to open the ImGui debug menu, then find
//  "Cheats" -> "God Forge". The panel walks three steps:
//    1. Search and pick a piece of gear or a familiar.
//    2. Choose its rarity (Rare / Epic / Legendary = 1 / 2 / 3 substats) and
//       click "Grant base item" -- one is added to your bag.
//    3. Pick each substat from a dropdown of THIS item's obtainable stats
//       (and, for equipment, its item level) and click "Apply chosen stats".
//
//  Each stat is granted at its MAXIMUM obtainable magnitude (the loot ceiling for
//  that stat on that item), drawn straight from the game's UItemRaritySettings
//  pools -- so the result is a legitimate, in-pool god-roll, just hand-picked
//  instead of random. The deterministic setter is the engine's own
//  UItemRuntimeFragment_Rarity::SetRarity(Rarity, PassiveEffects) overload.
//  Familiars share that same rarity fragment; they just draw from the separate
//  FamiliarPassivePool_* (filtered against the familiar's actor), and a live
//  summoned familiar is refreshed via UFamiliarComponent::OnSpawnedFromItem.
//
//  Companion editions (see scripts/):
//    - ReforgeCheatGui.as : reroll substats on gear you already own (F7 panel).
//    - ReforgeAltar.as    : a summoned altar that rerolls the selected item (F9).
//    - ReforgeGear.as     : the combined reforge edition (altar + reroll panel).
//  God Forge uses F8 so it can sit alongside any of them.
//
//  NOTE: single-player / listen-server (host) only -- granting and SetRarity are
//  server-authoritative. It only modifies live items, never the save on disk.
// =============================================================================


namespace GodForgeConfig
{
    // World hotkey that opens/closes the ImGui debug menu (press it in normal
    // gameplay, NOT while a menu is open). F8 matches the "cheat menu" key the
    // CelestialBoost / InfiniteEndurance mods already use, and avoids the reforge
    // editions' F7 (panel) / F9 (altar) / F10 (debug gold).
    const FKey ToggleMenuKey = EKeys::F8;

    // Bind ToggleMenuKey ourselves. The ImGui debug menu is SHARED: if another
    // installed mod (CelestialBoost, InfiniteEndurance, a reforge panel, ...)
    // already opens it, you can set this false and reach "Cheats -> God Forge"
    // via that mod's key instead -- no need for a redundant binding. Leave true
    // to work stand-alone. (Mirrors InfiniteEndurance's bBindOwnMenuKey.)
    const bool bBindOwnMenuKey = true;

    // Auto-enable Developer Mode on startup so the debug menu (and this panel)
    // is available. Set false if you prefer to enable it yourself.
    const bool bAutoEnableDeveloperMode = true;
}


// -----------------------------------------------------------------------------
//  One obtainable substat for an item: the modified attribute (group key), its
//  best obtainable magnitude, the localized line, and the actual effect to apply.
//  Substats come from FIXED, discrete weighted pools (UItemRaritySettings), not a
//  min/max range, so the best value per stat is fully enumerable -- we keep the
//  highest-magnitude entry per attribute.
// -----------------------------------------------------------------------------
struct FGodForgeStat
{
    FString AttrName;       // modified GameplayAttribute name (the group key)
    float MaxMagnitude;     // highest magnitude available for this stat
    FString Text;           // localized line, e.g. "+50% Spellblade Damage"
    FPassiveEffect Effect;  // the winning effect, applied verbatim on forge
}

namespace GodForge
{
    // Anything carrying a rarity fragment can hold substats -- equipment, "item"
    // gear, AND familiars (they share UItemRuntimeFragment_Rarity, just rolling
    // from a different pool). That's the only requirement.
    bool SupportsForge(const UItemDefinition Def)
    {
        if (Def == nullptr)
            return false;
        return Def.HasRuntimeFragment(UItemRuntimeFragment_Rarity);
    }

    bool IsFamiliar(const UItemDefinition Def)
    {
        return Def != nullptr && Def.GetFragment_Familiar() != nullptr;
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

    void Accumulate(TArray<FGodForgeStat>& Stats, const FString& Attr, const FPassiveEffect& Effect)
    {
        for (int i = 0; i < Stats.Num(); i++)
        {
            if (Stats[i].AttrName == Attr)
            {
                if (Effect.Magnitude > Stats[i].MaxMagnitude)
                {
                    Stats[i].MaxMagnitude = Effect.Magnitude;
                    Stats[i].Text = Effect.GetLocalizedText().ToString();
                    Stats[i].Effect = Effect;
                }
                return;
            }
        }
        FGodForgeStat New;
        New.AttrName = Attr;
        New.MaxMagnitude = Effect.Magnitude;
        New.Text = Effect.GetLocalizedText().ToString();
        New.Effect = Effect;
        Stats.Add(New);
    }

    // The familiar pool for a rarity tier (no engine getter exists for these, so
    // we read the public fields directly -- same selection the engine's own
    // RollPassiveEffectFamiliar makes).
    TArray<FFamiliarRarityPassive> FamiliarPoolFor(const UItemRaritySettings Settings, EItemRarity R)
    {
        if (R == EItemRarity::Rare)
            return Settings.FamiliarPassivePool_Rare;
        if (R == EItemRarity::Epic)
            return Settings.FamiliarPassivePool_Epic;
        return Settings.FamiliarPassivePool_Legendary;
    }

    // Every positive substat this item can obtain up to the given rarity, deduped
    // to the best magnitude per attribute.
    //   - Familiars: filtered against the familiar's actor (its class default
    //     object), exactly like the engine rolls them.
    //   - Everything else: needs a LIVE stack because the item/equipment pool
    //     filters (FItemStackFilter::AppliesTo) test the stack, not the definition.
    void GatherStats(UItemStack Item, EItemRarity ItemRarity, TArray<FGodForgeStat>& OutStats)
    {
        OutStats.Empty();
        if (Item == nullptr)
            return;
        const UItemDefinition Def = Item.GetItemDefinition();
        if (!SupportsForge(Def))
            return;

        const UItemRaritySettings Settings = Game::GetGameInstance().ItemRaritySettings;
        if (Settings == nullptr)
            return;

        // --- Familiar branch -------------------------------------------------
        const UItemFragment_Familiar FamFrag = Def.GetFragment_Familiar();
        if (FamFrag != nullptr)
        {
            const ANPCBase FamiliarCDO = FamFrag.FamiliarParams.ActorClass.DefaultObject;
            if (FamiliarCDO == nullptr)
                return;

            for (int Tier = int(EItemRarity::Rare); Tier <= int(ItemRarity); Tier++)
            {
                const EItemRarity TierRarity = EItemRarity(Tier);
                TArray<FFamiliarRarityPassive> Pool = FamiliarPoolFor(Settings, TierRarity);
                for (const FFamiliarRarityPassive& Passive : Pool)
                {
                    if (!Passive.Filter.AppliesTo(FamiliarCDO))
                        continue;
                    if (!Passive.Effect.IsPositive())
                        continue;
                    const FString Attr = AttrNameOf(Passive.Effect);
                    if (Attr == "")
                        continue;
                    Accumulate(OutStats, Attr, Passive.Effect);
                }
            }
            return;
        }

        // --- Equipment / item branch ----------------------------------------
        // Equipment uses the equipment pool; "item" gear (with player actions)
        // uses the item pool -- same branch the roller takes.
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
                if (!Passive.Effect.IsPositive())
                    continue;
                const FString Attr = AttrNameOf(Passive.Effect);
                if (Attr == "")
                    continue;
                Accumulate(OutStats, Attr, Passive.Effect);
            }
        }
    }
}


// -----------------------------------------------------------------------------
//  The ImGui window: search gear/familiars, grant one, then hand-pick its stats.
// -----------------------------------------------------------------------------
UCLASS()
class UGodForgeWindow : UImGuiDebugMenuWindow
{
    private FString SearchText;
    private TMap<FGameplayTag, const UItemDefinition> Items;

    // Selected catalog item (the definition) and rarity for the NEXT grant.
    private const UItemDefinition InspectedItem;
    private TArray<FString> RarityNames;
    private TArray<EItemRarity> RarityValues;
    private int RarityIndex = 2;        // default Legendary (3 substats)

    // The live item we granted and are now forging, plus the rarity it was
    // granted at and the per-slot substat picks (indices into the obtainable
    // stat list, which is recomputed on demand -- it's deterministic).
    private UItemStack ForgeTarget;
    private EItemRarity ForgeRarity;
    private int ForgeLevel = 1;          // item level to stamp (drives base power)
    private TArray<int> SlotSel;

    UFUNCTION(BlueprintOverride)
    bool Initialize(UObject UserData)
    {
        InspectedItem = nullptr;
        ForgeTarget = nullptr;

        // The forgeable rarities (Common has no substats, so it's omitted).
        RarityNames.Empty();
        RarityValues.Empty();
        RarityNames.Add("Rare (1 substat)");      RarityValues.Add(EItemRarity::Rare);
        RarityNames.Add("Epic (2 substats)");     RarityValues.Add(EItemRarity::Epic);
        RarityNames.Add("Legendary (3 substats)"); RarityValues.Add(EItemRarity::Legendary);

        const UItemSubsystem ItemSubsystem = UItemSubsystem::Get();
        if (ItemSubsystem != nullptr)
            Items = ItemSubsystem.Items;

        return true;
    }

    // ImGui parses its text as a printf format, so a literal '%' -- which EVERY
    // percent substat carries (e.g. "+50% Spellblade Damage") -- is read as a
    // bogus format specifier and HARD-CRASHES the CRT. Double each '%' so the
    // text renders literally. Use for ALL dynamic text passed to ImGui::Text*.
    private FString ImGuiSafe(FString In)
    {
        return In.Replace("%", "%%");
    }

    // A faint "(?)" on the same line that reveals a tooltip on hover.
    private void HelpMarker(FString Tip)
    {
        ImGui::SameLine();
        ImGui::TextDisabled("(?)");
        if (ImGui::IsItemHovered())
            ImGui::SetTooltip(Tip);
    }

    // Last segment of a gameplay tag, e.g. "Items.Coin" -> "Coin".
    private FString TagLeaf(FGameplayTag Tag)
    {
        FString Leaf;
        FString Discard;
        Tag.TagName.PlainNameString.Split(".", Discard, Leaf);
        return Leaf == "" ? Tag.TagName.PlainNameString : Leaf;
    }

    // Short "kind" badge for the search list: Familiar / equip slot / Item.
    private FString ItemKindLabel(const UItemDefinition Def)
    {
        if (GodForge::IsFamiliar(Def))
            return "Familiar";
        auto EquipFrag = Def.GetFragment_Equipment();
        if (EquipFrag != nullptr && EquipFrag.EquipsToSlot.TagName != n"None")
            return TagLeaf(EquipFrag.EquipsToSlot);
        return "Item";
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
            ImGui::TextColored(FColor::Red, "God Forge only works on the host / single-player.");
            return;
        }

        ImGui::TextColored(FColor::Cyan, "Grant gear or familiars with the exact substats you choose.");
        ImGui::TextDisabled("Each picked stat is granted at its maximum obtainable value.");

        if (ImGui::CollapsingHeader("Step 1  -  Choose what to forge", EImGuiTreeNodeFlags::DefaultOpen))
            DrawSearch();

        if (InspectedItem != nullptr)
        {
            if (ImGui::CollapsingHeader("Step 2  -  Grant a base item", EImGuiTreeNodeFlags::DefaultOpen))
                DrawSelected(Player);
        }

        if (ForgeTarget != nullptr && IsValid(ForgeTarget))
        {
            if (ImGui::CollapsingHeader("Step 3  -  Hand-pick its stats", EImGuiTreeNodeFlags::DefaultOpen))
                DrawForge(Player);
        }
    }

    // Search box + a tidy, striped table of forgeable gear/familiars. Picking a
    // row selects it as the next grant target.
    private void DrawSearch()
    {
        ImGui::InputText("Search", SearchText);
        if (SearchText == "")
        {
            ImGui::TextDisabled("Type part of a gear or familiar name to search.");
            return;
        }

        if (!ImGui::BeginTable("gfresults", 2, EImGuiTableFlags::RowBg | EImGuiTableFlags::Borders | EImGuiTableFlags::SizingStretchProp))
            return;

        ImGui::TableSetupColumn("Name");
        ImGui::TableSetupColumn("Type");
        ImGui::TableHeadersRow();

        int Shown = 0;
        for (auto It : Items)
        {
            const UItemDefinition Def = It.Value;
            if (!GodForge::SupportsForge(Def))
                continue;

            const FString Leaf = TagLeaf(It.Key);
            const FString Disp = Def.DisplayName.ToString();
            if (!Leaf.Contains(SearchText) && !Disp.Contains(SearchText))
                continue;

            if (Shown >= 14)
            {
                ImGui::TableNextRow();
                ImGui::TableNextColumn();
                ImGui::TextDisabled("...more matches, refine your search...");
                break;
            }

            ImGui::TableNextRow();
            ImGui::TableNextColumn();
            bool bSelected = (InspectedItem == Def);
            if (ImGui::Selectable(ImGuiSafe(f"{Disp}###gfitem{Shown}"), bSelected))
            {
                InspectedItem = Def;
                RarityIndex = DefaultRarityIndex(Def);
                ResetForge();
            }
            if (ImGui::IsItemHovered())
                ImGui::SetTooltip(ImGuiSafe(f"Tag: {Leaf}"));

            ImGui::TableNextColumn();
            ImGui::TextDisabled(ImGuiSafe(ItemKindLabel(Def)));
            Shown++;
        }

        ImGui::EndTable();

        if (Shown == 0)
            ImGui::TextDisabled("No forgeable gear or familiars match.");
    }

    // The selected catalog item: name, kind/slot, rarity choice, grant button.
    private void DrawSelected(APlayerCharacter Player)
    {
        const FString Leaf = TagLeaf(InspectedItem.ItemTag);
        const bool bFamiliar = GodForge::IsFamiliar(InspectedItem);

        ImGui::Text(ImGuiSafe(f"Selected: {InspectedItem.DisplayName.ToString()}"));
        ImGui::SameLine();
        ImGui::TextDisabled(ImGuiSafe(f"[{Leaf}]"));

        if (bFamiliar)
        {
            ImGui::TextDisabled("Familiar -- substats apply to the summoned familiar.");
        }
        else
        {
            auto EquipFrag = InspectedItem.GetFragment_Equipment();
            if (EquipFrag != nullptr && EquipFrag.EquipsToSlot.TagName != n"None")
                ImGui::TextDisabled(ImGuiSafe(f"Equips to: {TagLeaf(EquipFrag.EquipsToSlot)}"));
        }

        if (RarityIndex < 0 || RarityIndex >= RarityValues.Num())
            RarityIndex = RarityValues.Num() - 1;
        ImGui::PushItemWidth(220);
        ImGui::Combo("Rarity", RarityIndex, RarityNames);
        ImGui::PopItemWidth();
        HelpMarker("Rare / Epic / Legendary = 1 / 2 / 3 substat slots.");

        if (ImGui::Button("Grant base item"))
            GrantAndPrep(Player, RarityValues[RarityIndex]);
        ImGui::SameLine();
        ImGui::TextDisabled("(adds one to your bag, then pick its stats below)");
    }

    // The forge target: per-slot substat dropdowns, item level (equipment),
    // apply button, and a live readout of what's on the item now.
    private void DrawForge(APlayerCharacter Player)
    {
        const bool bFamiliar = GodForge::IsFamiliar(ForgeTarget.GetItemDefinition());

        ImGui::Text(ImGuiSafe(f"Forging: {ForgeTarget.GetItemDefinition().DisplayName.ToString()}"));
        ImGui::SameLine();
        ImGui::TextDisabled(ImGuiSafe(f"[{RarityName(ForgeRarity)}]"));

        TArray<FGodForgeStat> Stats;
        GodForge::GatherStats(ForgeTarget, ForgeRarity, Stats);

        if (Stats.IsEmpty())
        {
            ImGui::TextDisabled("No obtainable substats found for this item.");
            return;
        }

        // Dropdown options: one line per obtainable stat, at its max magnitude.
        TArray<FString> Options;
        for (const FGodForgeStat& S : Stats)
            Options.Add(ImGuiSafe(S.Text));

        const int Slots = int(ForgeRarity);
        SyncSlots(Slots, Stats.Num());

        ImGui::PushItemWidth(360);
        for (int i = 0; i < Slots; i++)
        {
            int Sel = SlotSel[i];
            if (Sel < 0 || Sel >= Stats.Num())
                Sel = 0;
            ImGui::Combo(f"Substat {i + 1}###gfslot{i}", Sel, Options);
            SlotSel[i] = Sel;
        }
        ImGui::PopItemWidth();

        // Item level -- the diamond badge that drives base damage/stats (equipment
        // only). The native grant leaves it at the item's low default; crafting
        // uses the crafter's level, which is why a crafted copy is far stronger.
        UItemRuntimeFragment_Equipment EquipFrag = ForgeTarget.GetRuntimeFragment_Equipment();
        if (EquipFrag != nullptr)
        {
            ImGui::Separator();
            ImGui::PushItemWidth(120);
            ImGui::InputInt("Item level", ForgeLevel);
            ImGui::PopItemWidth();
            if (ForgeLevel < 1)
                ForgeLevel = 1;
            const int MyLevel = (Player.AbilityComp != nullptr) ? Player.AbilityComp.Level : ForgeLevel;
            ImGui::SameLine();
            if (ImGui::Button(f"Match my level ({MyLevel})"))
                ForgeLevel = Math::Max(1, MyLevel);
            ImGui::TextDisabled(f"Currently level {EquipFrag.ItemLevel} -- higher = more base damage/stats.");
        }
        else if (bFamiliar)
        {
            UItemRuntimeFragment_FamiliarInfo FamInfo = ForgeTarget.GetRuntimeFragment_FamiliarInfo();
            if (FamInfo != nullptr)
            {
                ImGui::Separator();
                ImGui::TextDisabled(f"Familiar level {FamInfo.GetLevel()} (raised by XP, not set here).");
            }
        }

        ImGui::Separator();
        if (ImGui::Button("Apply chosen stats"))
            ApplyStats(Player);
        ImGui::SameLine();
        FString ApplyHint;
        if (bFamiliar)
            ApplyHint = "(summon the familiar to feel the stats)";
        else if (EquipFrag != nullptr)
            ApplyHint = "(sets substats + level; equip it afterwards)";
        else
            ApplyHint = "(equip it afterwards to feel the stats)";
        ImGui::TextDisabled(ApplyHint);

        // Live readout of what's actually on the item right now.
        UItemRuntimeFragment_Rarity Frag = ForgeTarget.GetRuntimeFragment_Rarity();
        if (Frag != nullptr && !Frag.RarityEffects.IsEmpty())
        {
            ImGui::TextDisabled("Current substats:");
            ImGui::Indent();
            for (const FPassiveEffect& Effect : Frag.RarityEffects)
                ImGui::TextColored(FColor::Yellow, ImGuiSafe(f"- {Effect.GetLocalizedText().ToString()}"));
            ImGui::Unindent();
        }
    }

    // Grants one of the selected item at the chosen rarity, captures the live
    // stack, and seeds the per-slot picks.
    private void GrantAndPrep(APlayerCharacter Player, EItemRarity Rarity)
    {
        if (!System::IsServer() || Player == nullptr || Player.InventoryComp == nullptr || InspectedItem == nullptr)
            return;

        TArray<UItemStack> Added = Player.InventoryComp.AddItemsByTagWithRarity(InspectedItem.ItemTag, Rarity, 1);
        if (Added.IsEmpty() || Added[0] == nullptr)
        {
            Print("God Forge: could not grant that item (bag full?).", 3.0, FLinearColor(1.0, 0.35, 0.2, 1.0));
            return;
        }

        ForgeTarget = Added[0];
        ForgeRarity = Rarity;

        // Default the item level to the player's level (what crafting would give),
        // so a granted piece isn't stuck at the weak base default. (Familiars
        // ignore this -- they have no equipment fragment.)
        UItemRuntimeFragment_Equipment EquipFrag = ForgeTarget.GetRuntimeFragment_Equipment();
        if (Player.AbilityComp != nullptr)
            ForgeLevel = Player.AbilityComp.Level;
        else if (EquipFrag != nullptr)
            ForgeLevel = EquipFrag.ItemLevel;
        if (ForgeLevel < 1)
            ForgeLevel = 1;

        TArray<FGodForgeStat> Stats;
        GodForge::GatherStats(ForgeTarget, Rarity, Stats);

        // Default each slot to a distinct stat so the picks start spread out.
        SlotSel.Empty();
        const int Slots = int(Rarity);
        for (int i = 0; i < Slots; i++)
            SlotSel.Add(Stats.Num() > 0 ? Math::Min(i, Stats.Num() - 1) : 0);

        Print(f"Granted {ForgeTarget.GetItemDefinition().DisplayName} -- now choose its substats.", 3.0, FLinearColor(0.5, 0.85, 1.0, 1.0));
    }

    // Writes the chosen substats onto the forged item via the deterministic
    // SetRarity overload (no rolling). Refreshes a live equipped item or summoned
    // familiar so the change is felt immediately.
    private void ApplyStats(APlayerCharacter Player)
    {
        if (!System::IsServer() || ForgeTarget == nullptr || !IsValid(ForgeTarget))
            return;

        UItemRuntimeFragment_Rarity Frag = ForgeTarget.GetRuntimeFragment_Rarity();
        if (Frag == nullptr)
        {
            Print("God Forge: that item has no rarity fragment.", 3.0, FLinearColor(1.0, 0.35, 0.2, 1.0));
            return;
        }
        TArray<FGodForgeStat> Stats;
        GodForge::GatherStats(ForgeTarget, ForgeRarity, Stats);
        if (Stats.IsEmpty())
            return;

        TArray<FPassiveEffect> Chosen;
        for (int i = 0; i < SlotSel.Num(); i++)
        {
            const int Sel = SlotSel[i];
            if (Sel < 0 || Sel >= Stats.Num())
                continue;
            Chosen.Add(Stats[Sel].Effect);
        }
        if (Chosen.IsEmpty())
            return;

        const bool bFamiliar = GodForge::IsFamiliar(ForgeTarget.GetItemDefinition());
        UItemRuntimeFragment_Equipment EquipFrag = ForgeTarget.GetRuntimeFragment_Equipment();

        // Equipment: if this exact stack is currently equipped, re-equip so the
        // stats AND new item level go live now (otherwise on next equip).
        UEquipmentInstance EquipInst = FindEquippedInstance(Player, ForgeTarget);
        if (EquipInst != nullptr)
            EquipInst.HandleUnequipped();

        Frag.SetRarity(ForgeRarity, Chosen);
        if (EquipFrag != nullptr)
            EquipFrag.SetItemLevel(Math::Max(1, ForgeLevel));

        if (EquipInst != nullptr)
            EquipInst.HandleEquipped();

        // Familiar: if it's currently summoned, re-push the rarity effects so the
        // new substats apply to the live familiar now (otherwise on next summon).
        if (bFamiliar)
            RefreshLiveFamiliar(Frag);

        FString Summary;
        for (const FPassiveEffect& Effect : Chosen)
        {
            if (Summary != "")
                Summary += ", ";
            Summary += Effect.GetLocalizedText().ToString();
        }
        const FString LevelTail = (EquipFrag != nullptr) ? f"  (level {Math::Max(1, ForgeLevel)})" : "";
        Print(f"Forged: {Summary}{LevelTail}", 5.0, FLinearColor(0.6, 1.0, 0.6, 1.0));
        Log(n"GodForge", f"Applied {Chosen.Num()} chosen substats to '{ForgeTarget.GetItemDefinition().DisplayName}'.");
    }

    // Matches the item against the player's live equipped instances.
    private UEquipmentInstance FindEquippedInstance(APlayerCharacter Player, UItemStack Item)
    {
        if (Player == nullptr || Player.EquipmentComp == nullptr)
            return nullptr;
        for (UHercEquipmentInstance E : Player.EquipmentComp.GetAllEquippedItems())
        {
            if (E != nullptr && E.ItemStack == Item)
                return Cast<UEquipmentInstance>(E);
        }
        return nullptr;
    }

    // Re-applies the item's rarity effects to its currently-summoned familiar (if
    // any), the same call the engine makes when a familiar spawns from its item.
    private void RefreshLiveFamiliar(UItemRuntimeFragment_Rarity Frag)
    {
        UItemRuntimeFragment_FamiliarInfo FamInfo = ForgeTarget.GetRuntimeFragment_FamiliarInfo();
        if (FamInfo == nullptr || !FamInfo.HasFamiliar())
            return;
        ANPCBase Familiar = FamInfo.GetFamiliar();
        if (Familiar == nullptr || Familiar.FamiliarComp == nullptr)
            return;
        Familiar.FamiliarComp.OnSpawnedFromItem(Frag);
    }

    private void ResetForge()
    {
        ForgeTarget = nullptr;
        SlotSel.Empty();
    }

    // Keep the per-slot selection array sized to the substat count.
    private void SyncSlots(int Slots, int StatCount)
    {
        while (SlotSel.Num() < Slots)
            SlotSel.Add(StatCount > 0 ? Math::Min(SlotSel.Num(), StatCount - 1) : 0);
        while (SlotSel.Num() > Slots)
            SlotSel.RemoveAt(SlotSel.Num() - 1);
    }

    private int DefaultRarityIndex(const UItemDefinition Def)
    {
        const int R = int(Def.DefaultRarity);
        if (R < int(EItemRarity::Rare))
            return RarityValues.Num() - 1;   // Common default -> Legendary
        const int Idx = R - int(EItemRarity::Rare);
        return (Idx >= 0 && Idx < RarityValues.Num()) ? Idx : RarityValues.Num() - 1;
    }

    private FString RarityName(EItemRarity Rarity)
    {
        for (int i = 0; i < RarityValues.Num(); i++)
        {
            if (RarityValues[i] == Rarity)
                return RarityNames[i];
        }
        return "Common";
    }
}

// -----------------------------------------------------------------------------
//  Registers the "God Forge" window under Cheats in the ImGui debug menu.
// -----------------------------------------------------------------------------
UCLASS()
class UGodForgeMenuSubsystem : UImGuiPersistentMenuSubsystem
{
    default WindowName = n"God Forge";
    default WindowClass = UGodForgeWindow;
    default MenuPath = "Cheats|God Forge";
}

// -----------------------------------------------------------------------------
//  World input receiver: opens/closes the ImGui debug menu (F8). Pressed in the
//  world, where gameplay input is live.
// -----------------------------------------------------------------------------
UCLASS(NotPlaceable, HideCategories = "Actor Tick Rendering Replication Collision Input")
class AGodForgeInput : AActor
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
        InputComp.BindKey(GodForgeConfig::ToggleMenuKey, EInputEvent::IE_Pressed, FInputActionHandlerDynamicSignature(this, n"OnToggleMenu"));
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
class UGodForgeController : UScriptWorldSubsystem
{
    private AGodForgeInput InputActor;
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
        if (ImGuiModule::IsInputEnabled())
            ImGuiModule::SetKeyboardInputShared(!ImGui::IsKeyboardCaptured());

        if (Game::GetLocalPlayerController() == nullptr)
            return;

        if (!bDevModeSet && GodForgeConfig::bAutoEnableDeveloperMode)
        {
            CVar::Cheats::DeveloperMode.SetBool(true);
            bDevModeSet = true;
        }

        if (!GodForgeConfig::bBindOwnMenuKey)
            return;

        if (InputActor != nullptr && IsValid(InputActor))
            return;

        InputActor = Cast<AGodForgeInput>(SpawnActor(AGodForgeInput));
    }
}
