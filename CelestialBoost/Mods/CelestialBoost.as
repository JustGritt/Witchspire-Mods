// =============================================================================
//  Celestial Boost  —  raise the spawn odds of Celestial / Shifty / Legendary
//                      wild familiars, with a live cheat-menu panel.
//
//  Vanilla rolls happen once per wild familiar, server-side, in
//  UFamiliarComponent::BeginPlay (Core/AI/Familiar/FamiliarComponent.as):
//      CelestialChance = 0.005  (0.5%)   ShiftyChance = 0.10  (10%)
//      Rarity (stars)  -> FFamiliarRarityChances::Roll() per familiar level
//
//  A separate script can't hook those rolls, so a UScriptWorldSubsystem sweeps
//  the world every few seconds, finds freshly-spawned WILD familiars it hasn't
//  seen yet, and gives each ONE top-up roll:
//    - Celestial / Shifty: effective rate becomes (vanilla rate x Multiplier),
//      computed from the familiar's ACTUAL chance so "10x" is honest:
//          q = base*(mult-1)/(1-base)   (P(final) = base + (1-base)*q = base*mult)
//      Upgrading uses the game's own SetVisualVariant() -> sparkle visuals, the
//      Celestial health bonus, SaveGame-persisted. Shifty is preserved.
//    - Legendary (3-star): set FamiliarComp.Rarity = Legendary. The nameplate
//      reads Rarity live (NameplateComponent.as) so the stars update on the spot,
//      and capture goes through CreateItemStack() -> RarityFrag.SetRarity(Rarity)
//      (FamiliarDeathComponent.as), so the BONDED familiar is genuinely Legendary
//      with proper legendary substats (re-rolled from the legendary pool).
//
//  All tunables are console variables, editable LIVE from the cheat menu
//  (Developer Mode debug menu -> "Cheats" -> "Celestial Boost") or the console.
//  The "Always Celestial/Shifty" toggles drive the game's own Herc.Familiars.*
//  cheats, so even the engine's spawn roll honors them. Changes take effect for
//  newly-spawned wild familiars (each is boosted exactly once).
//
//  Single-player / listen-server HOST only (the rolls are server-authoritative).
// =============================================================================


namespace CelestialBoostConfig
{
    // Key that opens/closes the ImGui debug menu (press it in normal gameplay).
    const FKey ToggleMenuKey = EKeys::F8;

    // Auto-enable Developer Mode on startup so the debug menu is reachable.
    const bool bAutoEnableDeveloperMode = true;

    // How often (seconds) to sweep the world for newly-spawned wild familiars.
    const float ScanInterval = 2.0;

    // Nominal vanilla bases, used ONLY for the menu's "effective %" readout.
    const float NominalCelestialBase = 0.005; // 0.5%
    const float NominalShiftyBase    = 0.10;  // 10%
}


// Runtime-tunable settings as console variables (live-editable from the menu or
// the in-game console). Celestial/Shifty "Always" reuse the game's own CVars.
namespace CelestialBoostCVars
{
    const FConsoleVariable CelestialMultiplier("Herc.CelestialBoost.CelestialMultiplier", 10.0);
    const FConsoleVariable ShiftyMultiplier("Herc.CelestialBoost.ShiftyMultiplier", 1.0);
    const FConsoleVariable AlwaysLegendary("Herc.CelestialBoost.AlwaysLegendary", false);
    const FConsoleVariable ExtraLegendaryChance("Herc.CelestialBoost.ExtraLegendaryChance", 0.0);
    const FConsoleVariable VerboseLog("Herc.CelestialBoost.VerboseLog", false);
}


// -----------------------------------------------------------------------------
//  Bootstrapper + world sweep. The local-player setup (Developer Mode + menu
//  toggle) is not server-gated; the boosting is host-only.
// -----------------------------------------------------------------------------
class UCelestialBoostSubsystem : UScriptWorldSubsystem
{
    // Familiars we've already rolled for (so each gets exactly one extra chance).
    private TArray<ANPCBase> Processed;
    private float TimeSinceScan = 0;
    private bool bAnnounced = false;
    private int TotalUpgraded = 0;

    private ACelestialBoostInput InputActor;
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
        // --- Local-player setup (cheat menu); NOT server-gated. ---
        if (ImGuiModule::IsInputEnabled())
            ImGuiModule::SetKeyboardInputShared(!ImGui::IsKeyboardCaptured());

        if (Game::GetLocalPlayerController() != nullptr)
        {
            if (!bDevModeSet && CelestialBoostConfig::bAutoEnableDeveloperMode)
            {
                CVar::Cheats::DeveloperMode.SetBool(true);
                bDevModeSet = true;
            }

            if (InputActor == nullptr || !IsValid(InputActor))
                InputActor = Cast<ACelestialBoostInput>(SpawnActor(ACelestialBoostInput));
        }

        // --- Boosting: host only (the rolls are server-authoritative). ---
        if (!System::IsServer())
            return;

        if (!bAnnounced)
        {
            bAnnounced = true;
            Log(n"CelestialBoost", "Active. Tune live via the debug menu (Cheats|Celestial Boost) or Herc.CelestialBoost.* CVars.");
        }

        TimeSinceScan += DeltaTime;
        if (TimeSinceScan < CelestialBoostConfig::ScanInterval)
            return;
        TimeSinceScan = 0;

        ScanAndBoost();
    }

    private void ScanAndBoost()
    {
        TArray<ANPCBase> NPCs;
        GetAllActorsOfClass(NPCs);

        // Drop despawned actors from the processed list so it can't grow forever.
        TArray<ANPCBase> StillValid;
        for (ANPCBase Seen : Processed)
        {
            if (Seen != nullptr && IsValid(Seen))
                StillValid.Add(Seen);
        }
        Processed = StillValid;

        const bool bVerbose = CelestialBoostCVars::VerboseLog.GetBool();
        int NewWild = 0;
        int UpgradedThisSweep = 0;

        for (ANPCBase NPC : NPCs)
        {
            if (NPC == nullptr || !IsValid(NPC))
                continue;

            UFamiliarComponent FamiliarComp = NPC.FamiliarComp;
            if (FamiliarComp == nullptr)
                continue;

            // Only capturable (ItemTag valid — mirrors the engine's capturable
            // gate), wild (unowned), living familiars.
            if (!FamiliarComp.ItemTag.IsValid())
                continue;
            if (FamiliarComp.GetFamiliarOwner() != nullptr)
                continue;
            if (!NPC.IsAlive())
                continue;

            if (Processed.Contains(NPC))
                continue;
            Processed.Add(NPC);
            NewWild++;

            if (TryBoost(NPC, FamiliarComp))
                UpgradedThisSweep++;
        }

        if (bVerbose && NewWild > 0)
        {
            TotalUpgraded += UpgradedThisSweep;
            Log(n"CelestialBoost", f"sweep: {NewWild} new wild familiar(s), upgraded {UpgradedThisSweep} (total upgraded {TotalUpgraded})");
        }
    }

    private bool TryBoost(ANPCBase NPC, UFamiliarComponent FamiliarComp)
    {
        const bool bWasCelestial = FamiliarComp.IsCelestial();
        const bool bWasShifty    = FamiliarComp.IsShifty();

        // --- Celestial / Shifty (visual variants) ---
        bool bMakeCelestial = bWasCelestial;
        if (!bWasCelestial)
        {
            bMakeCelestial = RollUpgrade(
                FamiliarComp.CelestialChance,
                CelestialBoostCVars::CelestialMultiplier.GetFloat(),
                CVar::Familiars::AlwaysCelestial.GetBool());
        }

        bool bMakeShifty = bWasShifty;
        if (!bWasShifty)
        {
            bMakeShifty = RollUpgrade(
                FamiliarComp.ShiftyChance,
                CelestialBoostCVars::ShiftyMultiplier.GetFloat(),
                CVar::Familiars::AlwaysShifty.GetBool());
        }

        bool bUpgraded = false;

        if (bMakeCelestial != bWasCelestial || bMakeShifty != bWasShifty)
        {
            EFamiliarVisualVariant Variant = EFamiliarVisualVariant::Normal;
            if (bMakeCelestial && bMakeShifty)
                Variant = EFamiliarVisualVariant::ShiftyCelestial;
            else if (bMakeCelestial)
                Variant = EFamiliarVisualVariant::Celestial;
            else if (bMakeShifty)
                Variant = EFamiliarVisualVariant::Shifty;

            // Game's own method: removes old variant effects, updates the
            // SaveGame/Replicated VariantData, applies the Celestial gameplay
            // effects (incl. health bonus) and refreshes the sparkle visuals.
            FamiliarComp.SetVisualVariant(Variant);
            bUpgraded = true;
        }

        // --- Legendary (rarity / stars) ---
        bool bMadeLegendary = false;
        if (int(FamiliarComp.Rarity) < int(EItemRarity::Legendary))
        {
            bool bMakeLegendary = CelestialBoostCVars::AlwaysLegendary.GetBool();
            if (!bMakeLegendary)
            {
                const float Extra = CelestialBoostCVars::ExtraLegendaryChance.GetFloat();
                bMakeLegendary = Extra > 0.0 && Math::RandChance(Extra);
            }

            if (bMakeLegendary)
            {
                // Nameplate reads Rarity live; capture (CreateItemStack ->
                // SetRarity) makes the bonded familiar genuinely Legendary.
                FamiliarComp.Rarity = EItemRarity::Legendary;
                bMadeLegendary = true;
                bUpgraded = true;
            }
        }

        if (bUpgraded && CelestialBoostCVars::VerboseLog.GetBool())
        {
            FString Tags = "";
            if (bMakeCelestial && !bWasCelestial) Tags += " +Celestial";
            if (bMakeShifty && !bWasShifty)       Tags += " +Shifty";
            if (bMadeLegendary)                   Tags += " +Legendary";
            Log(n"CelestialBoost", f"{NPC.GetName()}:{Tags}");
        }

        return bUpgraded;
    }

    // Currently-OFF trait -> should we flip it ON? Returns true with probability
    // q = base*(mult-1)/(1-base) so the overall rate lands on base*mult.
    private bool RollUpgrade(float BaseChance, float Multiplier, bool bAlways) const
    {
        if (bAlways)
            return true;
        if (Multiplier <= 1.0 || BaseChance <= 0.0)
            return false;

        float Target = BaseChance * Multiplier;
        if (Target >= 1.0)
            return true;

        const float Denom = 1.0 - BaseChance;
        if (Denom <= 0.0)
            return true; // base already ~100%

        const float TopUp = (Target - BaseChance) / Denom; // in [0,1]
        return Math::RandChance(TopUp);
    }
}


// -----------------------------------------------------------------------------
//  World input receiver: opens/closes the ImGui debug menu (toggle key).
// -----------------------------------------------------------------------------
UCLASS(NotPlaceable, HideCategories = "Actor Tick Rendering Replication Collision Input")
class ACelestialBoostInput : AActor
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
        InputComp.BindKey(CelestialBoostConfig::ToggleMenuKey, EInputEvent::IE_Pressed, FInputActionHandlerDynamicSignature(this, n"OnToggleMenu"));
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
//  Cheat-menu entry: "Cheats" -> "Celestial Boost".
// -----------------------------------------------------------------------------
UCLASS()
class UCelestialBoostDebugMenu : UImGuiPersistentMenuSubsystem
{
    default WindowName = n"Celestial Boost";
    default WindowClass = UCelestialBoostDebugWindow;
    default MenuPath = "Cheats|Celestial Boost";
}

UCLASS()
class UCelestialBoostDebugWindow : UImGuiDebugMenuWindow
{
    default MinSize = FVector2f(380, 0);

    UFUNCTION(BlueprintOverride)
    void DrawContents(float DeltaTime)
    {
        ImGui::Text("Wild familiar spawn odds");
        if (!System::IsServer())
            ImGui::TextColored(FColor::Yellow, "Host / single-player only.");
        ImGui::Separator();

        // --- Celestial ---
        ImGui::Text("Celestial");
        float CelMult = CelestialBoostCVars::CelestialMultiplier.GetFloat();
        if (ImGui::DragFloat("Celestial multiplier", CelMult, 0.5, 1.0, 200.0))
            CelestialBoostCVars::CelestialMultiplier.SetFloat(CelMult);

        bool bAlwaysCel = CVar::Familiars::AlwaysCelestial.GetBool();
        if (ImGui::Checkbox("Always Celestial", bAlwaysCel))
            CVar::Familiars::AlwaysCelestial.SetBool(bAlwaysCel);

        DrawEffective("Celestial", CelestialBoostConfig::NominalCelestialBase, CelMult, bAlwaysCel);
        ImGui::Separator();

        // --- Shifty ---
        ImGui::Text("Shifty");
        float ShiMult = CelestialBoostCVars::ShiftyMultiplier.GetFloat();
        if (ImGui::DragFloat("Shifty multiplier", ShiMult, 0.5, 1.0, 20.0))
            CelestialBoostCVars::ShiftyMultiplier.SetFloat(ShiMult);

        bool bAlwaysShi = CVar::Familiars::AlwaysShifty.GetBool();
        if (ImGui::Checkbox("Always Shifty", bAlwaysShi))
            CVar::Familiars::AlwaysShifty.SetBool(bAlwaysShi);

        DrawEffective("Shifty", CelestialBoostConfig::NominalShiftyBase, ShiMult, bAlwaysShi);
        ImGui::Separator();

        // --- Legendary (3-star) ---
        ImGui::Text("Legendary (3-star)");
        bool bAlwaysLeg = CelestialBoostCVars::AlwaysLegendary.GetBool();
        if (ImGui::Checkbox("Always Legendary", bAlwaysLeg))
            CelestialBoostCVars::AlwaysLegendary.SetBool(bAlwaysLeg);

        float ExtraLeg = CelestialBoostCVars::ExtraLegendaryChance.GetFloat();
        if (ImGui::DragFloat("Extra Legendary chance (0-1)", ExtraLeg, 0.01, 0.0, 1.0))
            CelestialBoostCVars::ExtraLegendaryChance.SetFloat(ExtraLeg);
        ImGui::TextDisabled("Upgrades sub-legendary wild familiars to 3 stars.");
        ImGui::Separator();

        // --- Misc ---
        bool bVerbose = CelestialBoostCVars::VerboseLog.GetBool();
        if (ImGui::Checkbox("Verbose log", bVerbose))
            CelestialBoostCVars::VerboseLog.SetBool(bVerbose);

        ImGui::TextDisabled("Changes apply to newly-spawned wild familiars.");

        if (ImGui::Button("Reset to defaults"))
        {
            CelestialBoostCVars::CelestialMultiplier.SetFloat(10.0);
            CelestialBoostCVars::ShiftyMultiplier.SetFloat(1.0);
            CelestialBoostCVars::AlwaysLegendary.SetBool(false);
            CelestialBoostCVars::ExtraLegendaryChance.SetFloat(0.0);
            CVar::Familiars::AlwaysCelestial.SetBool(false);
            CVar::Familiars::AlwaysShifty.SetBool(false);
        }
    }

    // Shows the approximate resulting rate. NOTE: ImGui::Text* treat their string
    // as a printf format, so every literal '%' is doubled to '%%'.
    private void DrawEffective(const FString& Label, float Base, float Mult, bool bAlways)
    {
        float Eff = bAlways ? 100.0 : Base * Mult * 100.0;
        if (Eff > 100.0)
            Eff = 100.0;
        const float VanillaPct = Base * 100.0;
        ImGui::TextDisabled(f"~ {Eff:.1f}%% {Label}  (vanilla {VanillaPct:.1f}%%)");
    }
}
