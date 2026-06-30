// =============================================================================
//  Photo Mode  —  a one-stop "Cheats -> Photo Mode" panel for taking screenshots.
//
//  It pulls together the bits you'd otherwise fiddle with by hand:
//    * Freeze familiars & monsters in place so they hold dead still for the shot
//      while YOU keep walking around to frame it — plus a Time-scale slider for
//      whole-world slow-mo / freeze action frames.
//
//      It takes two levers, because the pose and the movement freeze separately:
//        - CustomTimeDilation = 0 on each AI character freezes its POSE (the
//          animation advances on the actor's dilated tick).
//        - MoverComp.Deactivate() freezes its MOVEMENT. The game runs on the UE
//          Mover plugin, which simulates on its own clock and ignores
//          CustomTimeDilation — so dilation alone freezes the animation but the
//          creature keeps sliding around. Deactivating the Mover is exactly what
//          the game's own Herc.Cheats.AI.DisableMoverComponents cheat does.
//      Both are per-actor, so the player and the free camera carry on at normal
//      speed. (Plain Global Time Dilation 0 is no good here on two counts: it
//      also freezes the player, and UE clamps the global value to a tiny non-zero
//      floor, so AI never truly stops anyway.)
//    * Set the time of day (sun / sky / lighting) with a slider and presets
//      (Dawn / Noon / Golden hour / Sunset / Night), and optionally HOLD it so
//      the sky stays put.
//    * Clear the sky by hiding the cloud volumes.
//    * Apply a screen color FILTER like a camera app — saturation, grayscale,
//      contrast and a warm / cool tint, with one-tap presets (Vivid, B&W,
//      Noir, Sepia, Warm, Cool).
//    * Hide the HUD.
//
//  Everything is driven through the game's OWN systems, the same ones the native
//  "Settings -> World" debug window uses:
//    - AHercCharacter.CustomTimeDilation = 0 + MoverComp.Deactivate()
//                                              (freeze familiars & monsters in
//                                               place; player keeps moving)
//    - Gameplay::SetGlobalTimeDilation()       (whole-world slow-mo / freeze)
//    - UDaySequenceSubsystem -> ADaySequenceActor + the world  (time of day)
//      clock on AHercGameState (SetWorldTimeStamp)
//    - ACloudVolume::SetActorHiddenInGame()                    (clouds)
//    - UPostProcessComponent + FPostProcessSettings color grading (filter)
//    - AHercHUD::SetVisibility()                               (HUD)
//
//  NOTE: Witchspire has no rain / storm / weather state machine exposed to
//  scripts. The sky is a UE5 Day Sequence + Sky System, so "weather" here means
//  time-of-day mood (the real atmosphere lever) plus a clear-sky cloud toggle.
//
//  Activation: this registers a panel under the shared ImGui debug menu
//  (Developer Mode). Open that menu the way you already do (e.g. F8 from another
//  mod, or the game's debug-menu key) and pick "Cheats -> Photo Mode". To make
//  this mod able to open the menu on its OWN, flip bBindOwnMenuKey below — but
//  ONLY if no other mod already binds the same key, or they'll cancel out.
//
//  Freezing entities / time of day are server-authoritative, so they run on the
//  host (single-player or listen-server) — the host owns the authoritative
//  characters, so freezing them there replicates the held pose to any clients.
//  Hiding the HUD / clouds and the color filter are local-only (visual).
// =============================================================================


namespace PhotoModeConfig
{
    // Auto-enable Developer Mode on startup so the debug menu is reachable.
    const bool bAutoEnableDeveloperMode = true;

    // Spawn our own opener that toggles the debug menu with MenuKey. Leave FALSE
    // if another active mod already binds a menu key (e.g. CelestialBoost uses
    // F8) — two openers on the same key toggle each other and cancel out.
    const bool bBindOwnMenuKey = false;
    const FKey MenuKey = EKeys::F8;

    // How often (seconds) to re-hide cloud volumes that streamed in while the
    // "Hide clouds" toggle is on.
    const float CloudRescanInterval = 1.0;

    // How often (seconds) to re-scan for newly spawned / streamed-in familiars
    // and monsters while "Freeze familiars & monsters" is on, so late arrivals
    // freeze too. Kept short so an enemy that wanders in stops almost at once.
    const float EntityRescanInterval = 0.5;

    // --- Fly while frozen ---------------------------------------------------
    // The game's free camera moves the camera by (velocity * frame delta), and
    // when the world is frozen (Global Time Dilation 0) that delta is 0 — so it
    // stops moving. With this on, Photo Mode flies the active free camera on
    // REAL (undilated) time while frozen, so you can still reposition the shot.
    // Mouse-look keeps working on its own (the game sets rotation directly, with
    // no delta). BindKey here is non-consuming, so normal movement is untouched
    // when you're not frozen.
    const bool bEnableFrozenFlyAssist = true;
    const float DefaultCameraSpeed = 2000.0;    // cm/s; matches the game's mid speed
    const float BoostMultiplier = 5.0;          // hold Boost key
    const float SlowMultiplier = 0.2;           // hold Slow key

    const FKey FlyForwardKey = EKeys::W;
    const FKey FlyBackKey    = EKeys::S;
    const FKey FlyLeftKey    = EKeys::A;
    const FKey FlyRightKey   = EKeys::D;
    const FKey FlyUpKey      = EKeys::E;
    const FKey FlyDownKey    = EKeys::Q;
    const FKey FlyBoostKey   = EKeys::LeftShift;
    const FKey FlySlowKey    = EKeys::LeftControl;
}


// -----------------------------------------------------------------------------
//  Time-of-day helpers. The GameState re-applies the time of day every frame
//  from the world clock, so to change the time and have it STICK we move the
//  clock itself (SetWorldTimeStamp) exactly like the native World Settings menu.
// -----------------------------------------------------------------------------
namespace PhotoModeTime
{
    ADaySequenceActor GetDaySequenceActor()
    {
        UDaySequenceSubsystem Sub = UDaySequenceSubsystem::Get();
        if (Sub == nullptr)
            return nullptr;
        return Sub.GetDaySequenceActor(false);
    }

    bool IsAvailable()
    {
        return GetDaySequenceActor() != nullptr;
    }

    float GetDayLength()
    {
        ADaySequenceActor DSA = GetDaySequenceActor();
        return (DSA != nullptr && DSA.DayLength > 0.0) ? DSA.DayLength : 24.0;
    }

    // Current displayed hour, in [0, DayLength).
    float GetCurrentHour()
    {
        ADaySequenceActor DSA = GetDaySequenceActor();
        return DSA != nullptr ? DSA.TimeOfDay : 0.0;
    }

    // In-world hours that advance per real second (slope of the world clock).
    float GetHoursPerSecond(ADaySequenceActor DSA)
    {
        if (DSA == nullptr || DSA.TimePerCycle <= 0.0)
            return 0.0;
        return Math::HOURS_IN_A_SECOND * DSA.DayLength / DSA.TimePerCycle;
    }

    // Set the displayed time of day to TargetHour by nudging the world clock.
    //   bForwardOnly = true  -> only ever moves the clock forward (safe one-shot)
    //   bForwardOnly = false -> shortest path (for per-tick holding; tiny nudges)
    // Server only; returns false if it couldn't be applied.
    bool SetTimeOfDay(float TargetHour, bool bForwardOnly)
    {
        if (!System::IsServer())
            return false;

        AHercGameState GameState = Game::GetGameState();
        ADaySequenceActor DSA = GetDaySequenceActor();
        if (GameState == nullptr || DSA == nullptr)
            return false;

        const float DayLength = DSA.DayLength;
        if (DayLength <= 0.0)
            return false;

        const float HoursPerSecond = GetHoursPerSecond(DSA);
        if (HoursPerSecond <= 0.0)
            return false;

        const float Hour = Math::Clamp(TargetHour, 0.0, DayLength);

        // Both values live in [0, DayLength), so the raw difference is already in
        // (-DayLength, DayLength) — no modulo needed.
        float Delta = Hour - DSA.TimeOfDay;
        if (bForwardOnly)
        {
            if (Delta <= 0.0)
                Delta += DayLength;            // always advance
        }
        else
        {
            if (Delta > DayLength * 0.5)
                Delta -= DayLength;            // shortest path
            else if (Delta < DayLength * -0.5)
                Delta += DayLength;
        }

        const float NewTimeStamp = GameState.GetWorldTimeSeconds() + Delta / HoursPerSecond;
        GameState.SetWorldTimeStamp(NewTimeStamp);
        DSA.SetTimeOfDay(GameState.GetInWorldHoursSinceStart());
        return true;
    }
}


// -----------------------------------------------------------------------------
//  Time-of-day presets, in hours. Read from the game's day/night thresholds when
//  available (so Dawn / Sunset land exactly on the sun's transitions), otherwise
//  fall back to sensible fractions of the day length.
// -----------------------------------------------------------------------------
namespace PhotoModePresets
{
    UDayNightCicleSettings GetSettings()
    {
        // CDO access mirrors GameState.as: `TypeName.DefaultObject` (dot form).
        return UDayNightCicleSettings.DefaultObject;
    }

    float Dawn()
    {
        UDayNightCicleSettings S = GetSettings();
        return S != nullptr ? S.SunriseBeginHour : PhotoModeTime::GetDayLength() * 0.27;
    }

    float Noon()
    {
        UDayNightCicleSettings S = GetSettings();
        if (S != nullptr)
            return (S.SunriseEndHour + S.SunsetBeginHour) * 0.5;
        return PhotoModeTime::GetDayLength() * 0.5;
    }

    // Warm light just before the sun goes down.
    float GoldenHour()
    {
        UDayNightCicleSettings S = GetSettings();
        return S != nullptr ? S.SunsetBeginHour : PhotoModeTime::GetDayLength() * 0.74;
    }

    float Sunset()
    {
        UDayNightCicleSettings S = GetSettings();
        if (S != nullptr)
            return (S.SunsetBeginHour + S.SunsetEndHour) * 0.5;
        return PhotoModeTime::GetDayLength() * 0.78;
    }

    float Night()
    {
        const float DayLength = PhotoModeTime::GetDayLength();
        UDayNightCicleSettings S = GetSettings();
        if (S == nullptr)
            return DayLength * 0.95;

        // Midpoint of the night, which wraps past the end of the day.
        float NightStart = S.SunsetEndHour;
        float NightEnd = S.SunriseBeginHour + DayLength;
        float Mid = (NightStart + NightEnd) * 0.5;
        if (Mid >= DayLength)
            Mid -= DayLength;
        return Mid;
    }
}


// -----------------------------------------------------------------------------
//  Shared state, reachable anywhere via UPhotoModeStore::Get(). The ImGui window
//  writes it; the world subsystem enforces it. Resets to defaults each launch.
// -----------------------------------------------------------------------------
UCLASS()
class UPhotoModeStore : UScriptGameInstanceSubsystem
{
    bool bFreezeEntities = false; // hold familiars & monsters still (you keep moving)
    bool bHideHUD = false;
    bool bHideClouds = false;
    bool bHoldTime = false;     // re-pin the time of day every tick
    float HeldHour = 12.0;      // the hour to hold while bHoldTime is on
    float CameraSpeed = PhotoModeConfig::DefaultCameraSpeed; // fly speed while frozen

    // --- Screen color filter (camera-app look). All neutral = no effect. -----
    float FilterSaturation = 1.0;   // 0 = grayscale, 1 = normal, >1 = vivid
    float FilterContrast = 1.0;     // 1 = normal
    float FilterTemperature = 0.0;  // -1 = cool (blue), 0 = neutral, +1 = warm (orange)
}


// -----------------------------------------------------------------------------
//  Fly-while-frozen input: tracks which movement keys are held. BindKey is
//  non-consuming here, so these never interfere with normal movement — the
//  world subsystem only acts on them while the world is frozen and a free
//  camera exists.
// -----------------------------------------------------------------------------
UCLASS(NotPlaceable, HideCategories = "Actor Tick Rendering Replication Collision Input")
class APhotoModeFlyInput : AActor
{
    default bReplicates = false;

    UPROPERTY(DefaultComponent, RootComponent)
    USceneComponent Root;

    UPROPERTY(DefaultComponent)
    UInputComponent InputComp;

    bool bFwd = false;
    bool bBack = false;
    bool bLeft = false;
    bool bRight = false;
    bool bUp = false;
    bool bDown = false;
    bool bBoost = false;
    bool bSlow = false;

    UFUNCTION(BlueprintOverride)
    void BeginPlay()
    {
        APlayerController Controller = Game::GetLocalPlayerController();
        if (Controller == nullptr)
            return;
        Controller.PushInputComponent(InputComp);

        BindHeld(PhotoModeConfig::FlyForwardKey);
        BindHeld(PhotoModeConfig::FlyBackKey);
        BindHeld(PhotoModeConfig::FlyLeftKey);
        BindHeld(PhotoModeConfig::FlyRightKey);
        BindHeld(PhotoModeConfig::FlyUpKey);
        BindHeld(PhotoModeConfig::FlyDownKey);
        BindHeld(PhotoModeConfig::FlyBoostKey);
        BindHeld(PhotoModeConfig::FlySlowKey);
    }

    private void BindHeld(FKey Key)
    {
        InputComp.BindKey(Key, EInputEvent::IE_Pressed, FInputActionHandlerDynamicSignature(this, n"OnKeyDown"));
        InputComp.BindKey(Key, EInputEvent::IE_Released, FInputActionHandlerDynamicSignature(this, n"OnKeyUp"));
    }

    UFUNCTION()
    private void OnKeyDown(FKey Key) { SetKey(Key, true); }

    UFUNCTION()
    private void OnKeyUp(FKey Key) { SetKey(Key, false); }

    private void SetKey(FKey Key, bool bPressed)
    {
        if (Key == PhotoModeConfig::FlyForwardKey)    bFwd = bPressed;
        else if (Key == PhotoModeConfig::FlyBackKey)  bBack = bPressed;
        else if (Key == PhotoModeConfig::FlyLeftKey)  bLeft = bPressed;
        else if (Key == PhotoModeConfig::FlyRightKey) bRight = bPressed;
        else if (Key == PhotoModeConfig::FlyUpKey)    bUp = bPressed;
        else if (Key == PhotoModeConfig::FlyDownKey)  bDown = bPressed;
        else if (Key == PhotoModeConfig::FlyBoostKey) bBoost = bPressed;
        else if (Key == PhotoModeConfig::FlySlowKey)  bSlow = bPressed;
    }

    bool HasMoveInput() const
    {
        return bFwd || bBack || bLeft || bRight || bUp || bDown;
    }

    // Local move vector: X = forward, Y = right, Z = up.
    FVector GetMoveInput() const
    {
        const float X = (bFwd ? 1.0 : 0.0) - (bBack ? 1.0 : 0.0);
        const float Y = (bRight ? 1.0 : 0.0) - (bLeft ? 1.0 : 0.0);
        const float Z = (bUp ? 1.0 : 0.0) - (bDown ? 1.0 : 0.0);
        return FVector(X, Y, Z);
    }

    float GetSpeedScale() const
    {
        float Scale = 1.0;
        if (bBoost) Scale *= PhotoModeConfig::BoostMultiplier;
        if (bSlow)  Scale *= PhotoModeConfig::SlowMultiplier;
        return Scale;
    }
}


// -----------------------------------------------------------------------------
//  Optional opener: toggles the shared ImGui debug menu with MenuKey. Only
//  spawned when bBindOwnMenuKey is true.
// -----------------------------------------------------------------------------
UCLASS(NotPlaceable, HideCategories = "Actor Tick Rendering Replication Collision Input")
class APhotoModeInput : AActor
{
    default bReplicates = false;

    UPROPERTY(DefaultComponent, RootComponent)
    USceneComponent Root;       // a UInputComponent can't be the actor root

    UPROPERTY(DefaultComponent)
    UInputComponent InputComp;

    UFUNCTION(BlueprintOverride)
    void BeginPlay()
    {
        APlayerController Controller = Game::GetLocalPlayerController();
        if (Controller == nullptr)
            return;
        Controller.PushInputComponent(InputComp);
        InputComp.BindKey(PhotoModeConfig::MenuKey, EInputEvent::IE_Pressed, FInputActionHandlerDynamicSignature(this, n"OnToggleMenu"));
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
//  Driver: enables Developer Mode, shares keyboard input while the menu is open,
//  optionally spawns the opener, and ENFORCES the store every frame (HUD, clouds,
//  held time of day) so the settings stick even with the panel closed.
// -----------------------------------------------------------------------------
class UPhotoModeSubsystem : UScriptWorldSubsystem
{
    private APhotoModeInput InputActor;
    private APhotoModeFlyInput FlyInput;
    private bool bDevModeSet = false;

    private bool bAppliedHideHUD = false;
    private bool bAppliedHideClouds = false;
    private bool bAppliedFreezeEntities = false;
    private float CloudRescanTimer = 0.0;
    private float EntityRescanTimer = 0.0;
    private float LastRealTime = -1.0;

    // The AI characters we've frozen, so we restore exactly those (and never
    // re-activate a Mover the GAME disabled itself, e.g. significance culling).
    private TArray<AHercCharacter> FrozenChars;

    // Unbound post-process component that drives the screen color filter. Created
    // lazily the first time a non-neutral filter is used.
    private UPostProcessComponent FilterPP;

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
        // when ImGui is actively capturing it (so typing in fields still works).
        if (ImGuiModule::IsInputEnabled())
            ImGuiModule::SetKeyboardInputShared(!ImGui::IsKeyboardCaptured());

        APlayerController Controller = Game::GetLocalPlayerController();
        if (Controller == nullptr)
            return;

        if (!bDevModeSet && PhotoModeConfig::bAutoEnableDeveloperMode)
        {
            CVar::Cheats::DeveloperMode.SetBool(true);
            bDevModeSet = true;
        }

        if (PhotoModeConfig::bBindOwnMenuKey && (InputActor == nullptr || !IsValid(InputActor)))
            InputActor = Cast<APhotoModeInput>(SpawnActor(APhotoModeInput));

        if (PhotoModeConfig::bEnableFrozenFlyAssist && (FlyInput == nullptr || !IsValid(FlyInput)))
            FlyInput = Cast<APhotoModeFlyInput>(SpawnActor(APhotoModeFlyInput));

        UPhotoModeStore Store = UPhotoModeStore::Get();
        if (Store == nullptr)
            return;

        ApplyHUD(Store);
        ApplyClouds(Store, DeltaTime);
        ApplyFilter(Store);
        ApplyEntityFreeze(Store, DeltaTime);
        ApplyFrozenFly(Store);

        // Hold the sky at a fixed hour (server only; SetTimeOfDay no-ops on clients).
        if (Store.bHoldTime)
            PhotoModeTime::SetTimeOfDay(Store.HeldHour, false);
    }

    // Freeze familiars & monsters in place while the player and the world keep
    // running at normal speed. Two levers are needed, because they freeze
    // different things:
    //   * CustomTimeDilation = 0  freezes the POSE (animation advances on the
    //     actor's dilated tick).
    //   * MoverComp.Deactivate()  freezes MOVEMENT. The game runs on the UE Mover
    //     plugin, which simulates on its own clock and ignores CustomTimeDilation
    //     — so dilation alone leaves them sliding around. This is exactly what the
    //     game's own Herc.Cheats.AI.DisableMoverComponents cheat does.
    // Re-scans periodically so enemies that spawn / stream in mid-shot freeze too.
    // Server only — the host owns the authoritative characters.
    private void ApplyEntityFreeze(UPhotoModeStore Store, float DeltaTime)
    {
        if (!System::IsServer())
            return;

        const bool bChanged = Store.bFreezeEntities != bAppliedFreezeEntities;

        if (Store.bFreezeEntities)
        {
            EntityRescanTimer += DeltaTime;
            const bool bRescan = EntityRescanTimer >= PhotoModeConfig::EntityRescanInterval;
            if (!bChanged && !bRescan)
                return;

            EntityRescanTimer = 0.0;
            bAppliedFreezeEntities = true;
            FreezeAICharacters();
        }
        else if (bChanged)
        {
            bAppliedFreezeEntities = false;
            EntityRescanTimer = 0.0;
            UnfreezeAICharacters();
        }
    }

    // Stop every AI-driven character cold. Only touches characters whose Mover is
    // currently active — that skips ones we already froze, and ones the game has
    // disabled itself (significance culling, death) — and records each so we
    // restore exactly what we froze.
    private void FreezeAICharacters()
    {
        TArray<AHercCharacter> Characters;
        GetAllActorsOfClass(Characters);
        for (AHercCharacter Character : Characters)
        {
            if (Character == nullptr || !IsValid(Character))
                continue;
            // AI only — a player's controller is an APlayerController, not AAIController.
            if (Cast<AAIController>(Character.Controller) == nullptr)
                continue;

            UMoverComponent MoverComp = Character.MoverComp;
            if (MoverComp == nullptr || !MoverComp.IsActive())
                continue;   // already frozen by us, or disabled by the game

            // A Mover we'd already deactivated reads inactive, so reaching here with
            // an active one means it's either new or the game re-activated it (e.g.
            // significance LOD as the player nears) — (re-)freeze it either way, but
            // only track it once.
            Character.CustomTimeDilation = 0.0;   // freeze the pose
            MoverComp.Deactivate();                // freeze the movement
            if (!FrozenChars.Contains(Character))
                FrozenChars.Add(Character);
        }
    }

    // Restore exactly the characters we froze, then forget them.
    private void UnfreezeAICharacters()
    {
        for (AHercCharacter Character : FrozenChars)
        {
            if (Character == nullptr || !IsValid(Character))
                continue;
            Character.CustomTimeDilation = 1.0;
            UMoverComponent MoverComp = Character.MoverComp;
            if (MoverComp != nullptr)
                MoverComp.Activate();
        }
        FrozenChars.Empty();
    }

    // While the world is frozen, fly the active free camera on real (undilated)
    // time so it can still be repositioned. Skipped entirely when not frozen, so
    // the game's own free camera keeps doing the moving at normal speed.
    private void ApplyFrozenFly(UPhotoModeStore Store)
    {
        if (FlyInput == nullptr || !IsValid(FlyInput))
            return;

        // Track real time every frame so the first frozen frame has a sane delta.
        const float Now = Gameplay::GetRealTimeSeconds();
        float RealDelta = (LastRealTime >= 0.0) ? (Now - LastRealTime) : 0.0;
        LastRealTime = Now;
        RealDelta = Math::Clamp(RealDelta, 0.0, 0.1);

        // Only take over when (near) frozen, or we'd double the game freecam.
        if (Gameplay::GetGlobalTimeDilation() > 0.001)
            return;
        if (RealDelta <= 0.0 || !FlyInput.HasMoveInput())
            return;

        // The active free camera is the game freecam's view target.
        TArray<APlayerDebugCamera> Cameras;
        GetAllActorsOfClass(Cameras);
        if (Cameras.Num() == 0)
            return;
        APlayerDebugCamera Camera = Cameras[0];
        if (Camera == nullptr || !IsValid(Camera))
            return;

        const FVector MoveInput = FlyInput.GetMoveInput();
        const float Speed = Store.CameraSpeed * FlyInput.GetSpeedScale();

        // Planar (W/A/S/D) follows where the camera looks; up/down is world-vertical.
        FVector WorldMove = Camera.ActorRotation.RotateVector(FVector(MoveInput.X, MoveInput.Y, 0.0));
        WorldMove += FVector::UpVector * MoveInput.Z;
        Camera.AddActorWorldOffset(WorldMove * Speed * RealDelta);
    }

    // Hide / restore the HUD only when the desired state changes, so we don't
    // fight other systems that legitimately re-show it.
    private void ApplyHUD(UPhotoModeStore Store)
    {
        if (Store.bHideHUD == bAppliedHideHUD)
            return;
        AHercHUD HUD = Cast<AHercHUD>(Game::GetHUD());
        if (HUD == nullptr)
            return;
        HUD.SetVisibility(!Store.bHideHUD);
        bAppliedHideHUD = Store.bHideHUD;
    }

    // Hide cloud volumes when toggled on (and re-hide any that stream in), or
    // restore them all when toggled off.
    private void ApplyClouds(UPhotoModeStore Store, float DeltaTime)
    {
        const bool bChanged = Store.bHideClouds != bAppliedHideClouds;
        CloudRescanTimer += DeltaTime;
        const bool bRescan = Store.bHideClouds && CloudRescanTimer >= PhotoModeConfig::CloudRescanInterval;

        if (!bChanged && !bRescan)
            return;

        CloudRescanTimer = 0.0;
        bAppliedHideClouds = Store.bHideClouds;

        TArray<ACloudVolume> CloudVolumes;
        GetAllActorsOfClass(CloudVolumes);
        for (ACloudVolume CloudVolume : CloudVolumes)
        {
            if (CloudVolume != nullptr && IsValid(CloudVolume))
                CloudVolume.SetActorHiddenInGame(Store.bHideClouds);
        }
    }

    // Screen color filter (saturation / grayscale / contrast / warm-cool) through
    // an UNBOUND post-process component. It's local & visual, like the HUD / cloud
    // toggles, so it works on clients too; unbound means it covers the whole screen
    // no matter where the free camera flies (a bounded one would vanish once the
    // camera left the player's bounds). Each grade only engages when its slider is
    // off-neutral, so a neutral filter leaves the game's own color grading untouched.
    private void ApplyFilter(UPhotoModeStore Store)
    {
        // Don't spawn the component until a filter is actually used.
        if (IsFilterNeutral(Store) && (FilterPP == nullptr || !IsValid(FilterPP)))
            return;

        if (FilterPP == nullptr || !IsValid(FilterPP))
        {
            APlayerCharacter Player = Game::GetLocalPlayer();
            if (Player == nullptr || !IsValid(Player))
                return;     // e.g. dedicated server / no local pawn yet
            FilterPP = UPostProcessComponent::Create(Player);
            if (FilterPP == nullptr)
                return;
            FilterPP.bUnbound = true;   // affect the whole screen, free-cam included
        }

        const float Sat = Store.FilterSaturation;
        FilterPP.Settings.bOverride_ColorSaturation = Sat != 1.0;
        FilterPP.Settings.ColorSaturation = FVector4(Sat, Sat, Sat, 1.0);

        const float Con = Store.FilterContrast;
        FilterPP.Settings.bOverride_ColorContrast = Con != 1.0;
        FilterPP.Settings.ColorContrast = FVector4(Con, Con, Con, 1.0);

        // Temperature as a simple, predictable tint: warm = more red / less blue.
        const float T = Store.FilterTemperature;
        FilterPP.Settings.bOverride_ColorGain = T != 0.0;
        FilterPP.Settings.ColorGain = FVector4(1.0 + 0.25 * T, 1.0, 1.0 - 0.25 * T, 1.0);
    }

    private bool IsFilterNeutral(UPhotoModeStore Store) const
    {
        return Store.FilterSaturation == 1.0
            && Store.FilterContrast == 1.0
            && Store.FilterTemperature == 0.0;
    }
}


// -----------------------------------------------------------------------------
//  Cheat-menu entry: "Cheats" -> "Photo Mode".
// -----------------------------------------------------------------------------
UCLASS()
class UPhotoModeDebugMenu : UImGuiPersistentMenuSubsystem
{
    default WindowName = n"Photo Mode";
    default WindowClass = UPhotoModeDebugWindow;
    default MenuPath = "Cheats|Photo Mode";
}

UCLASS()
class UPhotoModeDebugWindow : UImGuiDebugMenuWindow
{
    default MinSize = FVector2f(360, 0);

    UFUNCTION(BlueprintOverride)
    void DrawContents(float DeltaTime)
    {
        UPhotoModeStore Store = UPhotoModeStore::Get();
        if (Store == nullptr)
        {
            ImGui::Text("Photo Mode store unavailable.");
            return;
        }

        const bool bServer = System::IsServer();

        ImGui::Text("Pose the world, then grab your shot.");
        if (!bServer)
            ImGui::TextColored(FColor::Yellow, "Freeze & time of day need host / single-player.");
        ImGui::Separator();

        DrawFreeze(Store, bServer);
        ImGui::NewLine();
        DrawTimeOfDay(Store, bServer);
        ImGui::NewLine();
        DrawSky(Store);
        ImGui::NewLine();
        DrawFilter(Store);
        ImGui::NewLine();
        DrawHud(Store);
        ImGui::Separator();

        if (ImGui::Button("Reset everything"))
        {
            if (bServer)
                Gameplay::SetGlobalTimeDilation(1.0);
            Store.bFreezeEntities = false;  // subsystem restores their normal time next tick
            Store.bHoldTime = false;
            Store.bHideClouds = false;
            Store.bHideHUD = false;
            SetFilter(Store, 1.0, 1.0, 0.0);   // neutral = no filter
        }
        ImGui::TextDisabled("Tip: use your free-camera key to fly the shot.");
    }

    // --- Freeze familiars & monsters + whole-world slow-mo -------------------
    private void DrawFreeze(UPhotoModeStore Store, bool bServer)
    {
        ImGui::Text("World");
        ImGui::Separator();

        if (!bServer)
        {
            ImGui::TextDisabled("(host only)");
            return;
        }

        // Primary freeze: hold familiars & monsters still while YOU keep moving.
        // Per-actor time dilation, so the player and free camera are untouched.
        bool bFreezeEntities = Store.bFreezeEntities;
        if (ImGui::Checkbox("Freeze familiars & monsters", bFreezeEntities))
            Store.bFreezeEntities = bFreezeEntities;
        ImGui::SameLine();
        ImGui::TextDisabled("they hold still - you move freely");

        // Secondary: whole-world time scale (slow-mo, or 0 to freeze EVERYTHING,
        // yourself included). Independent of the freeze above.
        float Dilation = Gameplay::GetGlobalTimeDilation();
        if (ImGui::DragFloat("Time scale", Dilation, 0.01, 0.0, 4.0))
            Gameplay::SetGlobalTimeDilation(Math::Clamp(Dilation, 0.0, 100.0));
        ImGui::SameLine();
        ImGui::TextDisabled("1.0 = normal (whole world; 0 freezes you too)");

        // Only when the Time scale has frozen the whole world (so the game's own
        // free camera stalls) do we offer the fly-cam assist + its speed.
        if (Dilation <= 0.001 && PhotoModeConfig::bEnableFrozenFlyAssist)
        {
            ImGui::TextDisabled("Free-cam fly: W/A/S/D + E/Q  -  Shift boost, Ctrl slow");
            float Speed = Store.CameraSpeed;
            if (ImGui::DragFloat("Camera speed", Speed, 25.0, 25.0, 50000.0))
                Store.CameraSpeed = Math::Clamp(Speed, 1.0, 100000.0);
        }
    }

    // --- Time of day ---------------------------------------------------------
    private void DrawTimeOfDay(UPhotoModeStore Store, bool bServer)
    {
        ImGui::Text("Time of day");
        ImGui::Separator();

        if (!PhotoModeTime::IsAvailable())
        {
            ImGui::TextDisabled("Day-night cycle not available on this level.");
            return;
        }

        const float DayLength = PhotoModeTime::GetDayLength();
        const float CurHour = PhotoModeTime::GetCurrentHour();

        AHercGameState GameState = Game::GetGameState();
        const int Day = GameState != nullptr ? GameState.GetInWorldDay() : 0;
        const int Hh = int(CurHour);
        const int Mm = int((CurHour - Hh) * 60);
        ImGui::Text(f"Day {Day}  -  {Hh :02d}:{Mm :02d}");

        if (!bServer)
        {
            ImGui::TextDisabled("(host only)");
            return;
        }

        float EditHour = Store.bHoldTime ? Store.HeldHour : CurHour;
        if (ImGui::DragFloat("Hour", EditHour, 0.05, 0.0, DayLength))
            ApplyTime(Store, Math::Clamp(EditHour, 0.0, DayLength));

        if (ImGui::Button("Dawn"))        ApplyTime(Store, PhotoModePresets::Dawn());
        ImGui::SameLine();
        if (ImGui::Button("Noon"))        ApplyTime(Store, PhotoModePresets::Noon());
        ImGui::SameLine();
        if (ImGui::Button("Golden hour")) ApplyTime(Store, PhotoModePresets::GoldenHour());
        ImGui::SameLine();
        if (ImGui::Button("Sunset"))      ApplyTime(Store, PhotoModePresets::Sunset());
        ImGui::SameLine();
        if (ImGui::Button("Night"))       ApplyTime(Store, PhotoModePresets::Night());

        bool bHold = Store.bHoldTime;
        if (ImGui::Checkbox("Hold time of day", bHold))
        {
            Store.bHoldTime = bHold;
            if (bHold)
                Store.HeldHour = PhotoModeTime::GetCurrentHour();
        }
        ImGui::SameLine();
        ImGui::TextDisabled("keeps the sky fixed");
    }

    // Apply a chosen hour. If we're holding, update the held target and take the
    // shortest path; otherwise it's a one-shot forward nudge (which still sticks
    // while the world is frozen).
    private void ApplyTime(UPhotoModeStore Store, float Hour)
    {
        if (Store.bHoldTime)
            Store.HeldHour = Hour;
        PhotoModeTime::SetTimeOfDay(Hour, !Store.bHoldTime);
    }

    // --- Sky / weather -------------------------------------------------------
    private void DrawSky(UPhotoModeStore Store)
    {
        ImGui::Text("Sky");
        ImGui::Separator();

        bool bHideClouds = Store.bHideClouds;
        if (ImGui::Checkbox("Hide clouds", bHideClouds))
            Store.bHideClouds = bHideClouds;
        ImGui::SameLine();
        ImGui::TextDisabled("clear sky");
    }

    // --- Filter (screen color grade) -----------------------------------------
    // Local visual, so it works for everyone (no host gate). Presets just set the
    // sliders below; the subsystem turns the values into post-process settings.
    private void DrawFilter(UPhotoModeStore Store)
    {
        ImGui::Text("Filter");
        ImGui::Separator();

        //                              sat    contrast  temp
        if (ImGui::Button("None"))  SetFilter(Store, 1.00, 1.00,  0.00);
        ImGui::SameLine();
        if (ImGui::Button("Vivid")) SetFilter(Store, 1.45, 1.15,  0.05);
        ImGui::SameLine();
        if (ImGui::Button("B&W"))   SetFilter(Store, 0.00, 1.05,  0.00);
        ImGui::SameLine();
        if (ImGui::Button("Noir"))  SetFilter(Store, 0.00, 1.50,  0.00);
        ImGui::SameLine();
        if (ImGui::Button("Sepia")) SetFilter(Store, 0.25, 1.05,  0.55);
        ImGui::SameLine();
        if (ImGui::Button("Warm"))  SetFilter(Store, 1.10, 1.00,  0.50);
        ImGui::SameLine();
        if (ImGui::Button("Cool"))  SetFilter(Store, 1.10, 1.00, -0.50);

        float Sat = Store.FilterSaturation;
        if (ImGui::DragFloat("Saturation", Sat, 0.01, 0.0, 2.0))
            Store.FilterSaturation = Math::Clamp(Sat, 0.0, 4.0);
        ImGui::SameLine();
        ImGui::TextDisabled("0 = grayscale");

        float Con = Store.FilterContrast;
        if (ImGui::DragFloat("Contrast", Con, 0.01, 0.5, 2.0))
            Store.FilterContrast = Math::Clamp(Con, 0.0, 4.0);

        float Temp = Store.FilterTemperature;
        if (ImGui::DragFloat("Temperature", Temp, 0.01, -1.0, 1.0))
            Store.FilterTemperature = Math::Clamp(Temp, -1.0, 1.0);
        ImGui::SameLine();
        ImGui::TextDisabled("cool <-> warm");
    }

    private void SetFilter(UPhotoModeStore Store, float Sat, float Con, float Temp)
    {
        Store.FilterSaturation = Sat;
        Store.FilterContrast = Con;
        Store.FilterTemperature = Temp;
    }

    // --- HUD -----------------------------------------------------------------
    private void DrawHud(UPhotoModeStore Store)
    {
        bool bHideHUD = Store.bHideHUD;
        if (ImGui::Checkbox("Hide HUD", bHideHUD))
            Store.bHideHUD = bHideHUD;
    }
}
