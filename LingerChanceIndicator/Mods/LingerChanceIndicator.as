// =============================================================================
//  Linger Chance Indicator — capture-probability readout (client-side, read-only)
//
//  Floats a "Capture X%" label over the wild familiar you're looking at. X is the
//  true capture chance: the product of the two independent gates the game rolls -
//    1. linger (NPCBase::TryLingering):      (base x mult + pity) x lingerGear
//    2. bond   (BondingSpirit::OnInteract):   bondChance x bondGear
//  each clamped 0..1. Bond is usually 100% (BondingChance defaults to 1.0) but
//  some species/gear move it, so we read and fold it in rather than assume. Press
//  ToggleDetailsKey to cycle the readout through three modes: compact "Capture X%",
//  the full equation, then hidden. Renders via UTextRenderComponent (works in the
//  game's Shipping build; no UMG asset needed).
//
//  Performance: the label runs on every client frame, so the hot path is kept lean.
//  The expensive bit is UTextRenderComponent::SetText, which re-tessellates the glyph
//  mesh, so the work is split by how often it actually has to change:
//    - Every frame: only the actor transform moves (location + yaw billboard toward
//      the camera). That rebuilds no geometry, so tracking stays smooth at any FPS.
//    - At a fixed 20 Hz: re-scan the look-at target and re-apply the glyph content
//      (size/text/colour). Pinning this to the recompute rate stops re-tessellation
//      from scaling with frame rate; SetText/WorldSize still only fire when the size
//      (past a deadband), text, or colour actually changed.
//    - Per look-at target: the odds + label string are built once and cached, so the
//      attribute reads and string formatting are skipped while you keep looking at the
//      same familiar (a ~1 s refresh still catches a mid-look gear/pity change).
// =============================================================================

// How the readout is displayed; the toggle key steps through these in order.
enum ELingerDisplayMode
{
    Capture,     // headline only: "Capture X%"
    Breakdown,   // headline + the full equation
    None,        // label fully hidden
}

namespace LingerChanceConfig
{
    // >>> Hotkey: change this to rebind the display cycle. Any EKeys::... value
    //     (e.g. EKeys::K, EKeys::J, EKeys::B). BindKey doesn't consume input, so
    //     it co-exists with the game's own bindings. Each press advances
    //     Capture -> Breakdown -> None -> Capture.
    const FKey ToggleDetailsKey = EKeys::L;
    const ELingerDisplayMode StartMode = ELingerDisplayMode::Capture;   // mode on load

    // Label placement/size. VerticalOffset: cm from the nameplate (negative =
    // below the healthbar). The label scales with distance for a constant
    // on-screen size; keep MaxTextSize high so far-away text stays readable.
    const float VerticalOffset = -10.0;
    const float ScreenSizeFactor = 0.022;   // WorldSize = distance * this
    const float MinTextSize = 10.0;
    const float MaxTextSize = 90.0;

    // How often the look-at target is re-scanned and the glyph content re-applied
    // (seconds). The actor transform still tracks every frame; the raycast, attribute
    // reads, string build and glyph rebuild are all throttled to this rate.
    const float RecomputeInterval = 0.05;   // 20 Hz
    // Deadband (cm) below which a WorldSize change won't trigger a glyph rebuild.
    const float WorldSizeDeadband = 0.25;
    // While the same familiar stays targeted its odds are cached and the label string
    // reused; force a fresh re-read every this-many recompute ticks (so this x
    // RecomputeInterval seconds) to catch a mid-look gear/pity change.
    const int OddsRefreshTicks = 20;   // ~1 s at the default 20 Hz
}

// The floating label: one reused instance the subsystem repositions, re-aims at
// the camera, and rewrites only when its content changes. ShadowComp is a black
// copy behind the main text so it stays legible on any background.
UCLASS(NotPlaceable, HideCategories = "Actor Tick Rendering Replication Collision Input")
class ALingerChanceLabel : AActor
{
    default bReplicates = false;
    default ActorHiddenInGame = true;   // hidden until we have a target

    UPROPERTY(DefaultComponent, RootComponent)
    UTextRenderComponent TextRenderComp;
    default TextRenderComp.HorizontalAlignment = EHorizTextAligment::EHTA_Center;
    default TextRenderComp.VerticalAlignment = EVerticalTextAligment::EVRTA_TextTop;
    default TextRenderComp.SetCollisionEnabled(ECollisionEnabled::NoCollision);

    UPROPERTY(DefaultComponent)
    UTextRenderComponent ShadowComp;
    default ShadowComp.HorizontalAlignment = EHorizTextAligment::EHTA_Center;
    default ShadowComp.VerticalAlignment = EVerticalTextAligment::EVRTA_TextTop;
    default ShadowComp.TextRenderColor = FColor::Black;
    default ShadowComp.SetCollisionEnabled(ECollisionEnabled::NoCollision);

    // Last applied glyph-mesh inputs, so we can skip redundant (expensive) rebuilds.
    private bool bShown = false;
    private FString CachedText;
    private FColor CachedColor = FColor::White;
    private float CachedWorldSize = -1.0;

    // Per-frame: just move the actor (location + yaw billboard). A transform change
    // rebuilds no glyph geometry, so this stays cheap enough to run every frame and
    // keeps tracking smooth regardless of frame rate.
    void MoveTo(const FVector& Location, const FRotator& Rotation)
    {
        if (!bShown)
        {
            SetActorHiddenInGame(false);
            bShown = true;
        }
        SetActorLocation(Location);
        SetActorRotation(Rotation);
    }

    // At the recompute cadence: refresh the glyph mesh, but only the parts that
    // actually changed. The WorldSize/SetText path re-tessellates, so it's gated
    // behind a size deadband plus a text/colour change test. A WorldSize field change
    // only takes visual effect via a SetText rebuild, so the two are driven together.
    void ApplyContent(float WorldSize, const FString& Text, const FColor& Color)
    {
        const bool bSizeChanged = Math::Abs(WorldSize - CachedWorldSize) > LingerChanceConfig::WorldSizeDeadband;
        const bool bTextChanged = Text.Compare(CachedText) != 0;
        const bool bColorChanged = Color.R != CachedColor.R || Color.G != CachedColor.G || Color.B != CachedColor.B;
        if (!bSizeChanged && !bTextChanged && !bColorChanged)
            return;   // mesh identical - skip the re-tessellation

        if (bSizeChanged)
        {
            TextRenderComp.WorldSize = WorldSize;
            ShadowComp.WorldSize = WorldSize;

            // Drop shadow: same text nudged down-right and slightly behind (billboard
            // axes: +X toward camera, +Y right, +Z up).
            const float ShadowDist = WorldSize * 0.06;
            ShadowComp.SetRelativeLocation(FVector(-WorldSize * 0.04, ShadowDist, -ShadowDist));
            CachedWorldSize = WorldSize;
        }

        TextRenderComp.TextRenderColor = Color;   // shadow stays black
        CachedColor = Color;

        const FText AsText = FText::FromString(Text);
        TextRenderComp.SetText(AsText);
        ShadowComp.SetText(AsText);
        CachedText = Text;
    }

    void HideLabel()
    {
        if (bShown)
        {
            SetActorHiddenInGame(true);
            bShown = false;
        }
    }
}

// Receives the toggle key and owns the runtime "show details" flag (the subsystem
// reads it each frame). Mirrors QuickDeposit.as's input-actor pattern.
UCLASS(NotPlaceable, HideCategories = "Actor Tick Rendering Replication Collision Input")
class ALingerChanceInput : AActor
{
    default bReplicates = false;

    UPROPERTY(DefaultComponent, RootComponent)
    USceneComponent Root;   // a UInputComponent can't be the actor root

    UPROPERTY(DefaultComponent)
    UInputComponent InputComp;

    ELingerDisplayMode DisplayMode = LingerChanceConfig::StartMode;

    UFUNCTION(BlueprintOverride)
    void BeginPlay()
    {
        APlayerController Controller = Game::GetLocalPlayerController();
        if (Controller == nullptr)
            return;
        Controller.PushInputComponent(InputComp);
        InputComp.BindKey(LingerChanceConfig::ToggleDetailsKey, EInputEvent::IE_Pressed, FInputActionHandlerDynamicSignature(this, n"OnTogglePressed"));
    }

    // One step around the Capture -> Breakdown -> None -> Capture cycle.
    UFUNCTION()
    private void OnTogglePressed(FKey Key)
    {
        switch (DisplayMode)
        {
            case ELingerDisplayMode::Capture:   DisplayMode = ELingerDisplayMode::Breakdown; break;
            case ELingerDisplayMode::Breakdown: DisplayMode = ELingerDisplayMode::None;       break;
            default:                            DisplayMode = ELingerDisplayMode::Capture;    break;
        }
    }
}

// Driver: recomputes the look-at target + odds at a fixed cadence, repositions the
// label every frame, and rewrites the text only when it changes.
class ULingerChanceSubsystem : UScriptWorldSubsystem
{
    private ALingerChanceLabel Label;
    private ALingerChanceInput Input;

    // Throttle state for the expensive recompute (raycast + attribute reads + strings).
    private float RecomputeTimer = 1.0;   // high so the first tick recomputes immediately
    private bool bLastDetailsVisible = false;

    // Per-target odds cache: while the same familiar + detail mode persist we reuse the
    // built string instead of re-reading attributes every tick. The countdown bounds
    // how many recomputes we trust the cache for before forcing a fresh read.
    private bool bLastBuiltDetails = false;
    private int OddsRefreshCountdown = 0;

    // Last recompute result, reused by the per-frame positioning pass.
    private ANPCBase CachedFamiliar;
    private UNameplateComponent CachedNameplate;
    private FString CachedText;
    private FColor CachedColor = FColor::White;
    private bool bHasTarget = false;

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
        APlayerController Controller = Game::GetLocalPlayerController();
        if (Controller == nullptr)
        {
            HideLabel();
            ClearTarget();
            return;
        }

        EnsureInput();   // spawn the key receiver once the controller exists
        EnsureLabel();

        // "None" hides the readout entirely but keeps the input actor alive so the
        // next key press brings it back.
        const ELingerDisplayMode Mode = (Input != nullptr) ? Input.DisplayMode : LingerChanceConfig::StartMode;
        if (Mode == ELingerDisplayMode::None)
        {
            HideLabel();
            ClearTarget();
            return;
        }

        // --- Throttled: re-scan the look-at target and refresh the odds/text/size ---
        RecomputeTimer += DeltaTime;
        const bool bDetails = (Mode == ELingerDisplayMode::Breakdown);
        bool bRecomputed = false;
        if (RecomputeTimer >= LingerChanceConfig::RecomputeInterval || bDetails != bLastDetailsVisible)
        {
            RecomputeTimer = 0.0;
            bLastDetailsVisible = bDetails;
            // The player is only needed by the recompute, so fetch it here rather than
            // on every frame.
            APlayerCharacter Player = Game::GetLocalPlayer();
            if (Player != nullptr)
                RecomputeTarget(Player, bDetails);
            else
                ClearTarget();
            bRecomputed = true;
        }

        if (!bHasTarget || CachedFamiliar == nullptr || !IsValid(CachedFamiliar))
        {
            HideLabel();
            return;
        }

        // --- Every frame: anchor to the nameplate and yaw-billboard toward the camera.
        FVector Anchor;
        if (CachedNameplate != nullptr)
        {
            Anchor = CachedNameplate.GetWorldLocation();
        }
        else
        {
            FVector BoundsOrigin;
            FVector BoundsExtent;
            CachedFamiliar.GetActorBounds(true, BoundsOrigin, BoundsExtent);
            const FVector ActorLoc = CachedFamiliar.GetActorLocation();
            Anchor = FVector(ActorLoc.X, ActorLoc.Y, BoundsOrigin.Z + BoundsExtent.Z);
        }
        const FVector LabelLocation = Anchor + FVector::UpVector * LingerChanceConfig::VerticalOffset;

        const FVector CameraLocation = Controller.PlayerCameraManager.GetCameraLocation();
        const FVector ToCamera = CameraLocation - LabelLocation;
        FRotator FaceRotation = ToCamera.Rotation();
        FaceRotation.Pitch = 0;
        FaceRotation.Roll = 0;

        if (Label == nullptr)
            return;

        // Transform tracks every frame (cheap, no geometry rebuild); the glyph content
        // (size/text/colour) is only re-applied on recompute ticks, so re-tessellation
        // can't outpace the recompute rate even on a high-refresh display.
        Label.MoveTo(LabelLocation, FaceRotation);
        if (bRecomputed)
        {
            const float WorldSize = Math::Clamp(ToCamera.Size() * LingerChanceConfig::ScreenSizeFactor, LingerChanceConfig::MinTextSize, LingerChanceConfig::MaxTextSize);
            Label.ApplyContent(WorldSize, CachedText, CachedColor);
        }
    }

    // Resolves the current look-at familiar and computes its capture odds + label
    // text/colour. Clears bHasTarget when there's nothing capturable to show.
    private void RecomputeTarget(APlayerCharacter Player, bool bDetails)
    {
        if (Player.AimingComp == nullptr)
        {
            ClearTarget();
            return;
        }

        const FAimingResult LookAt = Player.AimingComp.CalculateLookAtResult();
        if (!LookAt.HasTarget() || LookAt.Target == nullptr)
        {
            ClearTarget();
            return;
        }

        ANPCBase Familiar = Cast<ANPCBase>(LookAt.Target.Owner);
        if (Familiar == nullptr || Familiar.AbilityComp == nullptr || Familiar.FamiliarComp == nullptr)
        {
            ClearTarget();
            return;
        }

        // Filter out anything that can't actually be captured:
        //  - owned familiars can't be re-captured.
        //  - a familiar with no bond ItemTag isn't capturable at all. We mirror the
        //    engine's exact gate here (NPCBase::OnDeath only calls TryLingering when
        //    FamiliarComp.ItemTag.IsValid()). NOTE: GetElementalType() can't be used
        //    for this - it falls back to the valid parent tag Effect_Type_Element when
        //    there's no item, so non-capturables (e.g. Al'uunian Vanguard) would slip
        //    through an Element.IsValid() check.
        if (Familiar.HasPlayerOwner() || !Familiar.FamiliarComp.ItemTag.IsValid())
        {
            ClearTarget();
            return;
        }

        // Steady state: same familiar, same detail mode, cache not yet expired -> the
        // odds and label string are unchanged, so reuse them and skip the attribute
        // reads and string formatting entirely. The countdown forces a periodic fresh
        // read so a mid-look gear/pity change still surfaces.
        if (Familiar == CachedFamiliar && bDetails == bLastBuiltDetails && OddsRefreshCountdown > 0)
        {
            OddsRefreshCountdown -= 1;
            bHasTarget = true;
            return;
        }
        OddsRefreshCountdown = LingerChanceConfig::OddsRefreshTicks;
        bLastBuiltDetails = bDetails;

        const FGameplayTag Element = Familiar.FamiliarComp.GetElementalType();

        // Gate 1 - linger, mirroring NPCBase::TryLingering: (base x mult + pity) x gear.
        // RawBase is the familiar's species attribute, before the difficulty mult.
        const float RawBase = Familiar.AbilityComp.GetAttributeCurrentValue(UFamiliarAttributeSet::GetLingeringChanceAttribute(), 0.0);
        const float LingeringMultiplier = CVar::Familiars::LingeringChanceMultiplier.Float;
        const float SuccessiveFailBonus = Player.AbilityComp.GetAttributeCurrentValue(UPlayerBondingAttributeSet::GetLingering_SuccessiveFailBonusAttribute(), 0.0);
        const float LingerModifier = UPlayerBondingAttributeSet::GetLingeringModifier(Player, Element);
        const float LingerChance = Math::Clamp((RawBase * LingeringMultiplier + SuccessiveFailBonus) * LingerModifier, 0.0, 1.0);

        // Gate 2 - bond, mirroring BondingSpirit::OnInteractSuccess: RandChance(BondingChance, bondGear).
        // The spirit only becomes yours if this second roll also lands, so true capture = linger x bond.
        // BondingChance defaults to 1.0 (FamiliarAttributeSet), so this is usually 100% - but reading
        // it keeps the readout honest for any species/gear that lowers it. Bond gear is its own modifier.
        const float BondingChance = Familiar.AbilityComp.GetAttributeCurrentValue(UFamiliarAttributeSet::GetBondingChanceAttribute(), 1.0);
        const float BondModifier = UPlayerBondingAttributeSet::GetBondingModifier(Player, Element);
        const float BondChance = Math::Clamp(BondingChance * BondModifier, 0.0, 1.0);

        const float CaptureChance = LingerChance * BondChance;

        // Headline (one decimal so small gear bonuses stay visible).
        FString Text = f"Capture {CaptureChance * 100 :.1f}%";

        // When toggled on, append the equation, e.g. = 2.0% x 3.00 x 1.31. Pity
        // adds before the gear multiply, so it's parenthesized: (b x m + p) x g.
        // Default factors (x1.00 / +0%) are dropped to keep it tidy.
        if (bDetails)
        {
            const bool bHasMult = Math::Abs(LingeringMultiplier - 1.0) >= 0.005;
            const bool bHasGear = Math::Abs(LingerModifier - 1.0) >= 0.005;
            const bool bHasPity = SuccessiveFailBonus > 0.0;
            const bool bHasBondGate = BondChance < 0.995;   // a sub-100% bond roll actually lowers capture

            FString PreGear = f"{RawBase * 100 :.1f}%";
            if (bHasMult)
                PreGear += f" x {LingeringMultiplier :.2f}";
            if (bHasPity)
                PreGear += f" + {SuccessiveFailBonus * 100 :.1f}% pity";

            FString Equation = PreGear;
            if (bHasGear)
            {
                if (bHasPity)
                    Equation = f"({PreGear})";
                Equation += f" x {LingerModifier :.2f}";
            }

            // Surface the second gate only when it bites, so default 100%-bond familiars read as before.
            if (bHasBondGate)
            {
                // Wrap an unparenthesized "+pity" sum so the bond multiply binds to the whole linger chance.
                if (bHasPity && !bHasGear)
                    Equation = f"({Equation})";
                Equation += f" x {BondChance * 100 :.0f}% bond";
            }

            Text += f"  = {Equation}";
        }

        // Rarity color (red -> gold -> green); the shadow keeps it legible anywhere.
        FColor Color = FColor(255, 75, 65);
        if (CaptureChance >= 0.50)
            Color = FColor(95, 240, 115);
        else if (CaptureChance >= 0.20)
            Color = FColor(255, 210, 60);

        CachedFamiliar = Familiar;
        CachedNameplate = UNameplateComponent::Get(Familiar);
        CachedText = Text;
        CachedColor = Color;
        bHasTarget = true;
    }

    private void EnsureLabel()
    {
        if (Label == nullptr || !IsValid(Label))
            Label = Cast<ALingerChanceLabel>(SpawnActor(ALingerChanceLabel));
    }

    private void EnsureInput()
    {
        if (Input == nullptr || !IsValid(Input))
            Input = Cast<ALingerChanceInput>(SpawnActor(ALingerChanceInput));
    }

    private void HideLabel()
    {
        if (Label != nullptr && IsValid(Label))
            Label.HideLabel();
    }

    // Drop the current target and its odds cache so the next acquisition rebuilds fresh.
    private void ClearTarget()
    {
        bHasTarget = false;
        CachedFamiliar = nullptr;
        CachedNameplate = nullptr;
        OddsRefreshCountdown = 0;
    }
}
