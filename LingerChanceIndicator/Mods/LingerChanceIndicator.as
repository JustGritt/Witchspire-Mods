// =============================================================================
//  Linger Chance Indicator — capture-probability readout (client-side, read-only)
//
//  Floats a "Capture X%" label over the wild familiar you're looking at. X is the
//  true capture chance: the product of the two independent gates the game rolls -
//    1. linger (NPCBase::TryLingering):      (base x mult + pity) x lingerGear
//    2. bond   (BondingSpirit::OnInteract):   bondChance x bondGear
//  each clamped 0..1. Bond is usually 100% (BondingChance defaults to 1.0) but
//  some species/gear move it, so we read and fold it in rather than assume. Press
//  ToggleDetailsKey to show the full equation. Renders via UTextRenderComponent
//  (works in the game's Shipping build; no UMG asset needed).
//
//  Performance: the label runs on every client frame, so the hot path is kept lean.
//  The expensive bit is UTextRenderComponent::SetText, which re-tessellates the glyph
//  mesh - so we (a) recompute the odds + re-scan the look-at target at a fixed 20 Hz
//  rather than every frame, (b) reposition the (cheap) actor transform every frame so
//  tracking stays smooth, and (c) only call SetText/WorldSize when the text, size, or
//  colour actually changed (a small deadband on size absorbs distance jitter).
// =============================================================================

namespace LingerChanceConfig
{
    // >>> Hotkey: change this to rebind the breakdown toggle. Any EKeys::... value
    //     (e.g. EKeys::K, EKeys::J, EKeys::B). BindKey doesn't consume input, so
    //     it co-exists with the game's own bindings.
    const FKey ToggleDetailsKey = EKeys::L;
    const bool bStartWithDetailsVisible = false;   // breakdown shown on load?

    // Label placement/size. VerticalOffset: cm from the nameplate (negative =
    // below the healthbar). The label scales with distance for a constant
    // on-screen size; keep MaxTextSize high so far-away text stays readable.
    const float VerticalOffset = -10.0;
    const float ScreenSizeFactor = 0.022;   // WorldSize = distance * this
    const float MinTextSize = 10.0;
    const float MaxTextSize = 90.0;

    // How often the odds + look-at target are recomputed (seconds). Positioning still
    // runs every frame; only the raycast/attribute reads/string build are throttled.
    const float RecomputeInterval = 0.05;   // 20 Hz
    // Deadband (cm) below which a WorldSize change won't trigger a glyph rebuild.
    const float WorldSizeDeadband = 0.25;
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

    void UpdateLabel(const FVector& Location, const FRotator& Rotation, float WorldSize, const FString& Text, const FColor& Color)
    {
        if (!bShown)
        {
            SetActorHiddenInGame(false);
            bShown = true;
        }

        // Position/rotation are just a transform move - cheap, so always track.
        SetActorLocation(Location);
        SetActorRotation(Rotation);

        // The glyph mesh only needs rebuilding when the text, size, or colour change.
        // A WorldSize field change only takes visual effect via a SetText rebuild, so
        // both are driven together below.
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

    bool bDetailsVisible = LingerChanceConfig::bStartWithDetailsVisible;

    UFUNCTION(BlueprintOverride)
    void BeginPlay()
    {
        APlayerController Controller = Game::GetLocalPlayerController();
        if (Controller == nullptr)
            return;
        Controller.PushInputComponent(InputComp);
        InputComp.BindKey(LingerChanceConfig::ToggleDetailsKey, EInputEvent::IE_Pressed, FInputActionHandlerDynamicSignature(this, n"OnTogglePressed"));
    }

    UFUNCTION()
    private void OnTogglePressed(FKey Key)
    {
        bDetailsVisible = !bDetailsVisible;
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
        APlayerCharacter Player = Game::GetLocalPlayer();
        APlayerController Controller = Game::GetLocalPlayerController();
        if (Player == nullptr || Controller == nullptr)
        {
            HideLabel();
            bHasTarget = false;
            return;
        }

        EnsureInput();   // spawn the key receiver once the controller exists
        EnsureLabel();

        // --- Throttled: re-scan the look-at target and recompute the odds/text ---
        RecomputeTimer += DeltaTime;
        const bool bDetails = (Input != nullptr && Input.bDetailsVisible);
        if (RecomputeTimer >= LingerChanceConfig::RecomputeInterval || bDetails != bLastDetailsVisible)
        {
            RecomputeTimer = 0.0;
            bLastDetailsVisible = bDetails;
            RecomputeTarget(Player, bDetails);
        }

        if (!bHasTarget || CachedFamiliar == nullptr || !IsValid(CachedFamiliar))
        {
            HideLabel();
            return;
        }

        // --- Every frame: anchor to the nameplate, billboard, distance-scaled size ---
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

        // Yaw-only billboard, sized to keep a roughly constant on-screen size.
        const FVector CameraLocation = Controller.PlayerCameraManager.GetCameraLocation();
        const FVector ToCamera = CameraLocation - LabelLocation;
        const float WorldSize = Math::Clamp(ToCamera.Size() * LingerChanceConfig::ScreenSizeFactor, LingerChanceConfig::MinTextSize, LingerChanceConfig::MaxTextSize);
        FRotator FaceRotation = ToCamera.Rotation();
        FaceRotation.Pitch = 0;
        FaceRotation.Roll = 0;

        if (Label != nullptr)
            Label.UpdateLabel(LabelLocation, FaceRotation, WorldSize, CachedText, CachedColor);
    }

    // Resolves the current look-at familiar and computes its capture odds + label
    // text/colour. Clears bHasTarget when there's nothing capturable to show.
    private void RecomputeTarget(APlayerCharacter Player, bool bDetails)
    {
        bHasTarget = false;
        CachedNameplate = nullptr;

        if (Player.AimingComp == nullptr)
            return;

        const FAimingResult LookAt = Player.AimingComp.CalculateLookAtResult();
        if (!LookAt.HasTarget() || LookAt.Target == nullptr)
            return;

        ANPCBase Familiar = Cast<ANPCBase>(LookAt.Target.Owner);
        if (Familiar == nullptr || Familiar.AbilityComp == nullptr || Familiar.FamiliarComp == nullptr)
            return;

        // Filter out anything that can't actually be captured:
        //  - owned familiars can't be re-captured.
        //  - a familiar with no bond ItemTag isn't capturable at all. We mirror the
        //    engine's exact gate here (NPCBase::OnDeath only calls TryLingering when
        //    FamiliarComp.ItemTag.IsValid()). NOTE: GetElementalType() can't be used
        //    for this - it falls back to the valid parent tag Effect_Type_Element when
        //    there's no item, so non-capturables (e.g. Al'uunian Vanguard) would slip
        //    through an Element.IsValid() check.
        if (Familiar.HasPlayerOwner() || !Familiar.FamiliarComp.ItemTag.IsValid())
            return;

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
}
