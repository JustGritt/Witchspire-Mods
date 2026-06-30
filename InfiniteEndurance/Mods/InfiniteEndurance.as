// =============================================================================
//  Infinite Endurance — a "never run out of stamina" cheat, in the Cheats menu
//
//  Adds an "Infinite Endurance" entry to the in-game ImGui Cheats menu (the same
//  debug menu Vanity Wardrobe / Reforge use). Tick the checkbox and the
//  subsystem tops up BOTH endurance bars to their maximum every frame:
//   * On-foot Stamina — sprint, dodge, etc.; never get the Exhaustion debuff.
//   * Broom Power      — the broom's own "boost/sprint" bar; hold boost forever
//                        without it draining out and dropping you back to glide.
//
//  Opening the menu: this mod auto-enables Developer Mode, so any mod that opens
//  the ImGui menu reveals the entry (e.g. Vanity Wardrobe's F7). It also binds
//  its own opener (default F8, configurable / disableable) so it works stand-alone.
//
//  How it works (no game data is modified, nothing is saved):
//   * Stamina lives on UActionAttributeSet (Stamina / MaxStamina); the broom's
//     boost bar lives on UBroomAttributeSet (Power / MaxPower). Abilities pay
//     their cost / drain as normal; we simply refill the bars afterwards via
//     UHercAbilityComponent::SetAttributeBaseValue, the same call the game uses
//     for its own attribute book-keeping (see NPCBase / BroomAttributeSet).
//     Writing the base value directly also bypasses the regen delay, the
//     Exhaustion block, and the broom's post-boost power-regen suppression.
//   * The on/off flag lives on a UScriptGameInstanceSubsystem singleton
//     (UInfiniteEnduranceStore::Get()), shared between the ImGui checkbox and the
//     world subsystem that does the refill — the same store pattern Vanity
//     Wardrobe uses.
//
//  Single-player / host only: these are server-authoritative attributes, so the
//  refill is gated behind IsServer() (always true when you host).
// =============================================================================

namespace InfiniteEnduranceConfig
{
    // Start with the cheat already on when the game launches?
    const bool bStartEnabled = false;

    // Auto-enable Developer Mode on startup so the ImGui Cheats menu (and this
    // entry) is available. Set false if you prefer to enable it yourself.
    const bool bAutoEnableDeveloperMode = true;

    // Bind our own key to open/close the ImGui menu, so the mod works on its own
    // without another mod (Vanity Wardrobe, Reforge, ...) opening it. Pressing it
    // toggles the SAME shared cheat menu, so it's harmless alongside those mods.
    // Set false if you'd rather only use another mod's opener (e.g. F7).
    const bool bBindOwnMenuKey = true;
    const FKey MenuKey = EKeys::F8;   // F6=wardrobe, F7=menu, F9=altar are taken

    // Log each toggle to Hercules.log (handy to confirm the mod loaded).
    const bool bVerboseLog = true;
}

// -----------------------------------------------------------------------------
//  Shared on/off state. A game-instance subsystem singleton so the ImGui window
//  (which flips it) and the world subsystem (which acts on it) see the same flag.
//  Reachable anywhere via UInfiniteEnduranceStore::Get().
// -----------------------------------------------------------------------------
UCLASS()
class UInfiniteEnduranceStore : UScriptGameInstanceSubsystem
{
    bool bEnabled = InfiniteEnduranceConfig::bStartEnabled;
    bool bLogged = false;   // so the world subsystem only logs on a real change
}

// -----------------------------------------------------------------------------
//  The ImGui window: a single checkbox plus a live readout of both bars.
// -----------------------------------------------------------------------------
UCLASS()
class UInfiniteEnduranceWindow : UImGuiDebugMenuWindow
{
    UFUNCTION(BlueprintOverride)
    bool Initialize(UObject UserData)
    {
        return true;
    }

    UFUNCTION(BlueprintOverride)
    void DrawContents(float DeltaTime)
    {
        UInfiniteEnduranceStore Store = UInfiniteEnduranceStore::Get();
        if (Store == nullptr)
        {
            ImGui::Text("Store unavailable.");
            return;
        }

        ImGui::Text("Keeps your stamina and broom boost topped up.");
        ImGui::TextDisabled("Sprint / dodge / fly without ever running out.");

        if (!System::IsServer())
            ImGui::TextColored(FColor::Red, "Host / single-player only.");

        ImGui::Separator();

        bool bEnabled = Store.bEnabled;
        if (ImGui::Checkbox("Infinite Endurance", bEnabled))
            Store.bEnabled = bEnabled;

        // Live readout so you can see the bars sitting at full while it's on.
        APlayerCharacter Player = Game::GetLocalPlayer();
        if (Player != nullptr)
        {
            UHercAbilityComponent Ability = UHercAbilityComponent::Get(Player);
            if (Ability != nullptr)
            {
                const int Stam = int(Ability.GetAttributeCurrentValue(UActionAttributeSet::GetStaminaAttribute()));
                const int MaxStam = int(Ability.GetAttributeCurrentValue(UActionAttributeSet::GetMaxStaminaAttribute()));
                ImGui::Text(f"Stamina:    {Stam} / {MaxStam}");

                const UBroomAttributeSet BroomSet = Ability.GetAttributeSet(UBroomAttributeSet);
                if (BroomSet != nullptr)
                {
                    const int Pow = int(Ability.GetAttributeCurrentValue(UBroomAttributeSet::GetPowerAttribute()));
                    const int MaxPow = int(Ability.GetAttributeCurrentValue(UBroomAttributeSet::GetMaxPowerAttribute()));
                    ImGui::Text(f"Broom boost: {Pow} / {MaxPow}");
                }
            }
        }
    }
}

// Registers the "Infinite Endurance" window under Cheats in the ImGui debug menu.
UCLASS()
class UInfiniteEnduranceMenu : UImGuiPersistentMenuSubsystem
{
    default WindowName = n"Infinite Endurance";
    default WindowClass = UInfiniteEnduranceWindow;
    default MenuPath = "Cheats|Infinite Endurance";
}

// -----------------------------------------------------------------------------
//  Optional world input receiver: opens / closes the ImGui debug menu. Only
//  spawned when bBindOwnMenuKey is true. Mirrors Reforge / Vanity Wardrobe.
// -----------------------------------------------------------------------------
UCLASS(NotPlaceable, HideCategories = "Actor Tick Rendering Replication Collision Input")
class AInfiniteEnduranceInput : AActor
{
    default bReplicates = false;

    UPROPERTY(DefaultComponent, RootComponent)
    USceneComponent Root;   // a UInputComponent can't be the actor root

    UPROPERTY(DefaultComponent)
    UInputComponent InputComp;

    UFUNCTION(BlueprintOverride)
    void BeginPlay()
    {
        APlayerController Controller = Game::GetLocalPlayerController();
        if (Controller == nullptr)
            return;
        Controller.PushInputComponent(InputComp);
        InputComp.BindKey(InfiniteEnduranceConfig::MenuKey, EInputEvent::IE_Pressed, FInputActionHandlerDynamicSignature(this, n"OnToggleMenu"));
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
//  Driver: auto-enables Developer Mode, shares keyboard input while the menu is
//  open, spawns the optional opener, and — while the checkbox is on — refills
//  both endurance bars every frame.
// -----------------------------------------------------------------------------
class UInfiniteEnduranceSubsystem : UScriptWorldSubsystem
{
    private AInfiniteEnduranceInput InputActor;
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
        // Keep keyboard input flowing to the game while ImGui is open, except when
        // ImGui is actively capturing it (so our opener key can close it again).
        if (ImGuiModule::IsInputEnabled())
            ImGuiModule::SetKeyboardInputShared(!ImGui::IsKeyboardCaptured());

        APlayerController Controller = Game::GetLocalPlayerController();
        if (Controller == nullptr)
            return;

        if (!bDevModeSet && InfiniteEnduranceConfig::bAutoEnableDeveloperMode)
        {
            CVar::Cheats::DeveloperMode.SetBool(true);
            bDevModeSet = true;
        }

        if (InfiniteEnduranceConfig::bBindOwnMenuKey && (InputActor == nullptr || !IsValid(InputActor)))
            InputActor = Cast<AInfiniteEnduranceInput>(SpawnActor(AInfiniteEnduranceInput));

        UInfiniteEnduranceStore Store = UInfiniteEnduranceStore::Get();
        if (Store == nullptr)
            return;

        if (InfiniteEnduranceConfig::bVerboseLog && Store.bEnabled != Store.bLogged)
        {
            Log(n"InfiniteEndurance", Store.bEnabled ? "Infinite Endurance: ON" : "Infinite Endurance: OFF");
            Store.bLogged = Store.bEnabled;
        }

        if (!Store.bEnabled)
            return;

        APlayerCharacter Player = Game::GetLocalPlayer();
        if (Player == nullptr || !System::IsServer())
            return;

        // Keep both endurance bars pinned to max. These attributes are
        // server-authoritative, so this is a no-op on a non-hosting MP client.
        UHercAbilityComponent Ability = UHercAbilityComponent::Get(Player);
        if (Ability == nullptr)
            return;

        // On-foot stamina (UActionAttributeSet).
        const float MaxStam = Ability.GetAttributeCurrentValue(UActionAttributeSet::GetMaxStaminaAttribute());
        const float CurStam = Ability.GetAttributeCurrentValue(UActionAttributeSet::GetStaminaAttribute());
        if (CurStam < MaxStam)
            Ability.SetAttributeBaseValue(UActionAttributeSet::GetStaminaAttribute(), MaxStam);

        // Broom boost power (UBroomAttributeSet) — only if the player actually has
        // the broom attribute set granted (it normally always is).
        const UBroomAttributeSet BroomSet = Ability.GetAttributeSet(UBroomAttributeSet);
        if (BroomSet != nullptr)
        {
            const float MaxPow = Ability.GetAttributeCurrentValue(UBroomAttributeSet::GetMaxPowerAttribute());
            const float CurPow = Ability.GetAttributeCurrentValue(UBroomAttributeSet::GetPowerAttribute());
            if (CurPow < MaxPow)
                Ability.SetAttributeBaseValue(UBroomAttributeSet::GetPowerAttribute(), MaxPow);
        }
    }
}
