// =============================================================================
//  Legendary Tracker  —  float a glowing orb (and a label) over nearby wild
//                        Legendary (3-star) familiars while you carry the
//                        detector trinket.
//
//  Rarity == stars:  Common=0, Rare=1*, Epic=2*, Legendary=3*  (the game's own
//  URarityStarsWidget shows int(Rarity) stars). A wild familiar's rarity lives
//  on UFamiliarComponent::Rarity, a *Replicated* property, so the local client
//  reads it directly — the visuals are pure local, no server logic.
//
//  -------------------------------------------------------------------------
//  THE DETECTOR ("borrow an existing item")
//  -------------------------------------------------------------------------
//  A true custom item isn't possible from script (items are cooked C++-backed
//  assets), so we *borrow* an existing one: "Vesper's Locket of Lost Things"
//  (Items.Unique_StarlingsLocket). It's granted once (gated on IsItemKnown so
//  dropping it is respected); hotkey (default K) re-grants. Put it on a hotbar
//  slot and SELECT it to switch the trail ON; select anything else to switch it
//  OFF. (Trail-only mode: the floating orb + label are disabled by default.)
//
//  -------------------------------------------------------------------------
//  THE VISUALS
//  -------------------------------------------------------------------------
//  Over each nearby legendary we float:
//    * an ORB — a real item's static mesh (default the Asterine Gem), spinning
//      and bobbing. Sourced from an item definition (UItemDefinition.ActorsToSpawn),
//      which is always loaded, so it works anywhere (unlike the crafting-beam VFX,
//      which only exists on workstations near base). Same mesh trick as ReforgeAltar.
//    * a LABEL — a gold billboarded UTextRenderComponent ("*** <name> <dist>m"),
//      same tech as LingerChanceIndicator (works in Shipping, no UMG asset).
//  Toggle either with bShowOrb / bShowText.
// =============================================================================


namespace LegendaryTrackerConfig
{
    // ---- The borrowed detector item ----------------------------------------
    const FName   DetectorItemTag  = n"Items.Unique_StarlingsLocket";
    const FString DetectorItemName = "Vesper's Locket of Lost Things";

    const bool bAutoGrantOnce     = true;     // gift the detector the first time only
    const bool bEnableGrantHotkey = true;
    // Context-sensitive: if you DON'T have the locket, K grants one; if you
    // already do (grant would be a no-op), K instead toggles the beam mode
    // (permanent <-> ping-on-select).
    const FKey GrantDetectorKey   = EKeys::K;
    const bool bEnforceSingleLocket = true;   // keep at most ONE locket — trim any extras the player picks up
    const bool bVanishDroppedLocket = true;   // a locket dropped on the floor disappears instead of lingering as a pickup
    const float UpkeepInterval      = 0.25;   // seconds between inventory-upkeep passes (single-locket trim + vanish drops)

    // ---- What to track ------------------------------------------------------
    const int   MinStars     = 3;        // 1 = Rare+, 2 = Epic+, 3 = Legendary only
    const float DetectRadius  = 15000.0; // UU (cm): 100 = 1 m -> 150 m
    const float ScanInterval  = 0.5;     // seconds between world rescans

    // ---- Orb (floating item mesh; the orb's ITEM encodes the variant) ------
    //  The orb borrows an item's world mesh. A DIFFERENT item per variant gives
    //  each its own colour — beams can't be tinted from script, but item meshes
    //  come in whatever colour the item is. Any tag works; if a tag has no
    //  usable mesh the orb falls back to the legendary one (so nothing breaks).
    //  Set bDumpItemCatalog = true once to log which items have a mesh, then
    //  pick good-looking ones here.
    const bool  bShowOrb         = false;  // orb above each familiar (off: trail-only mode)
    const FName OrbItemTag                = n"Items.AsterineGem";   // plain legendary (blue)
    const FName CelestialOrbItemTag       = n"Items.TearofAluun";   // celestial — guess (Al'uun = celestial theme)
    const FName ShiftyOrbItemTag          = n"Items.CorruptedDust"; // shifty — guess (corruption = dark/violet)
    const FName ShiftyCelestialOrbItemTag = n"Items.FireGem";       // both — guess (distinct red/orange)
    const float OrbTargetSize    = 45.0;   // cm, largest dimension of the mesh
    const float OrbVerticalOffset = 60.0;  // cm above the familiar's head
    const float OrbSpinDegPerSec = 90.0;   // spin speed
    const float OrbBobAmplitude  = 14.0;   // cm of up/down bob
    const float OrbBobSpeed      = 2.2;    // bob speed (rad/s)

    // One-time: log every item that has a usable orb mesh (tag + name) to
    // Hercules.log, to help choose the per-variant orbs above. Set false after.
    // (Catalogue already dumped — flip back to true if you need it again.)
    const bool bDumpItemCatalog = false;

    // ---- Label (billboarded text) ------------------------------------------
    const bool  bShowText        = false;  // text above each familiar (off: trail-only mode)
    const float TextVerticalOffset = 135.0; // cm above the head (sits above the orb)
    const float ScreenSizeFactor = 0.030;   // WorldSize = distance * this
    const float MinTextSize      = 14.0;
    const float MaxTextSize      = 140.0;
    const float WorldSizeDeadband = 0.5;    // cm; below this a size change skips a glyph rebuild
    const FColor MarkerColor     = FColor(255, 195, 60);  // gold

    // ---- Trail beam (crafting-station connection beam, you -> the NEAREST target) --------
    //  Borrows the crafting "connection" beam (AWorkstation.CraftingComp.
    //  StationConnectionVisualEffect) — the blue beam a station draws to an
    //  inventory it's using. It's a connecting line from its spawn location to the
    //  EndPos param (no StartPosition/Duration params), and it does NOT auto-
    //  destroy — we remove it ourselves.
    //  NOTE: this VFX lives on workstations, so it only resolves once a workstation
    //  has been loaded (i.e. near base). It's just an asset pointer, so once cached
    //  it works anywhere you roam.
    //
    //  By default the beam fires ONCE the moment you select the locket (a single
    //  line you -> nearest legendary — a directional "ping" shown for
    //  TrailTravelDuration seconds), then stays quiet until you re-select. Set
    //  bBeamOnSelectOnly = false for a continuous beam that re-anchors every
    //  TrailRespawnInterval while a target is in range.
    const bool  bShowTrail        = true;
    const bool  bBeamOnSelectOnly = true;   // one ping on select (vs. continuous)
    const float TrailStartOffsetZ = 70.0;   // cm above the player where the beam starts
    const float TrailTravelDuration  = 1.1; // seconds the ping beam stays on screen
    const float TrailRespawnInterval = 3.0; // continuous mode only: seconds between re-anchors

    // ---- Permanent beam (toggled by the K hotkey while you hold the locket) -
    //  Toggles a PERMANENT beam (vs. the default ping-on-select). To keep the
    //  beam's dense "stars & glitter" off your screen, the permanent beam is
    //  drawn REVERSED — it originates on the familiar and ends at you, so the
    //  glittery origin sits on the distant familiar. Still gated on the locket
    //  being selected.
    const float BeamReanchorDist   = 60.0;      // cm the target must move before the beam's start re-anchors

    // ---- Special variants (Celestial / Shifty) -----------------------------
    //  Visual variants on UFamiliarComponent (IsCelestial / IsShifty),
    //  independent of rarity. Tracked in ADDITION to legendaries; each gets its
    //  own ORB item (colour) and label colour.
    //  NOTE: Shifty is ~10% of all spawns (Celestial ~0.5%) — tracking Shifty
    //  regardless of rarity can add a lot of markers. Flip bTrackShifty off if
    //  it's too noisy.
    const bool bTrackCelestial = true;   // also track Celestial familiars (any rarity)
    const bool bTrackShifty    = true;   // also track Shifty familiars (any rarity)

    const FColor CelestialColor       = FColor(120, 235, 255);  // cyan
    const FColor ShiftyColor          = FColor(200, 130, 255);  // violet
    const FColor ShiftyCelestialColor = FColor(255, 130, 215);  // magenta (both)
    // (plain legendaries keep MarkerColor — gold — and the native blue beam.)

    const bool bVerboseLog = true;   // log activation / grants / orb-mesh resolution
}


// -----------------------------------------------------------------------------
//  Floating orb: a spinning item mesh. Position + spin driven by the subsystem.
// -----------------------------------------------------------------------------
UCLASS(NotPlaceable, HideCategories = "Replication")
class ALegendaryOrb : AActor
{
    default bReplicates = false;
    default ActorHiddenInGame = true;

    UPROPERTY(DefaultComponent, RootComponent)
    USceneComponent Root;

    UPROPERTY(DefaultComponent, Attach = Root)
    UStaticMeshComponent MeshComp;
    default MeshComp.SetCollisionEnabled(ECollisionEnabled::NoCollision);

    private bool bShown = false;
    private UStaticMesh CurrentMesh;

    // Set the mesh + normalized scale (largest dimension ~= TargetSize). Pooled
    // orbs are reused across variants, so re-apply whenever the mesh changes.
    void ConfigureMesh(UStaticMesh Mesh, float TargetSize)
    {
        if (Mesh == nullptr || Mesh == CurrentMesh)
            return;
        CurrentMesh = Mesh;

        MeshComp.SetStaticMesh(Mesh);

        const FVector Ext = Mesh.Bounds.BoxExtent;   // half-extents, unscaled
        const float NativeSize = 2.0 * Math::Max(Ext.X, Math::Max(Ext.Y, Ext.Z));
        const float Scale = (NativeSize > 1.0) ? (TargetSize / NativeSize) : 1.0;
        MeshComp.SetRelativeScale3D(FVector(Scale, Scale, Scale));
    }

    bool IsConfigured() const { return CurrentMesh != nullptr; }

    void UpdateOrb(const FVector& Location, float SpinYaw)
    {
        if (!bShown)
        {
            SetActorHiddenInGame(false);
            bShown = true;
        }
        SetActorLocation(Location);
        MeshComp.SetRelativeRotation(FRotator(0.0, SpinYaw, 0.0));
    }

    void HideOrb()
    {
        if (bShown)
        {
            SetActorHiddenInGame(true);
            bShown = false;
        }
    }
}


// -----------------------------------------------------------------------------
//  Billboarded text label with a black drop-shadow. Copied from
//  LingerChanceIndicator's label.
// -----------------------------------------------------------------------------
UCLASS(NotPlaceable, HideCategories = "Actor Tick Rendering Replication Collision Input")
class ALegendaryMarker : AActor
{
    default bReplicates = false;
    default ActorHiddenInGame = true;

    UPROPERTY(DefaultComponent, RootComponent)
    UTextRenderComponent TextRenderComp;
    default TextRenderComp.HorizontalAlignment = EHorizTextAligment::EHTA_Center;
    default TextRenderComp.VerticalAlignment = EVerticalTextAligment::EVRTA_TextCenter;
    default TextRenderComp.SetCollisionEnabled(ECollisionEnabled::NoCollision);

    UPROPERTY(DefaultComponent)
    UTextRenderComponent ShadowComp;
    default ShadowComp.HorizontalAlignment = EHorizTextAligment::EHTA_Center;
    default ShadowComp.VerticalAlignment = EVerticalTextAligment::EVRTA_TextCenter;
    default ShadowComp.TextRenderColor = FColor::Black;
    default ShadowComp.SetCollisionEnabled(ECollisionEnabled::NoCollision);

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

        SetActorLocation(Location);
        SetActorRotation(Rotation);

        const bool bSizeChanged = Math::Abs(WorldSize - CachedWorldSize) > LegendaryTrackerConfig::WorldSizeDeadband;
        const bool bTextChanged = Text.Compare(CachedText) != 0;
        const bool bColorChanged = Color.R != CachedColor.R || Color.G != CachedColor.G || Color.B != CachedColor.B;
        if (!bSizeChanged && !bTextChanged && !bColorChanged)
            return;

        if (bSizeChanged)
        {
            TextRenderComp.WorldSize = WorldSize;
            ShadowComp.WorldSize = WorldSize;

            const float ShadowDist = WorldSize * 0.06;
            ShadowComp.SetRelativeLocation(FVector(-WorldSize * 0.04, ShadowDist, -ShadowDist));
            CachedWorldSize = WorldSize;
        }

        TextRenderComp.TextRenderColor = Color;
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


// -----------------------------------------------------------------------------
//  Receives the (optional) "grant detector" + "toggle permanent beam" hotkeys.
// -----------------------------------------------------------------------------
UCLASS(NotPlaceable, HideCategories = "Actor Tick Rendering Replication Collision Input")
class ALegendaryTrackerInput : AActor
{
    default bReplicates = false;

    UPROPERTY(DefaultComponent, RootComponent)
    USceneComponent Root;

    UPROPERTY(DefaultComponent)
    UInputComponent InputComp;

    // One context-sensitive key (see GrantDetectorKey): the subsystem decides on
    // press whether to grant the locket or toggle the beam, based on ownership.
    bool bGrantRequested = false;

    UFUNCTION(BlueprintOverride)
    void BeginPlay()
    {
        if (!LegendaryTrackerConfig::bEnableGrantHotkey)
            return;

        APlayerController Controller = Game::GetLocalPlayerController();
        if (Controller == nullptr)
            return;

        Controller.PushInputComponent(InputComp);

        InputComp.BindKey(LegendaryTrackerConfig::GrantDetectorKey, EInputEvent::IE_Pressed, FInputActionHandlerDynamicSignature(this, n"OnGrantPressed"));
    }

    UFUNCTION()
    private void OnGrantPressed(FKey Key)
    {
        bGrantRequested = true;
    }
}


// -----------------------------------------------------------------------------
//  Driver: grants the detector, gates on carrying it, rescans nearby legendaries
//  on a fixed cadence, and floats an orb + label over each one every frame.
// -----------------------------------------------------------------------------
class ULegendaryTrackerSubsystem : UScriptWorldSubsystem
{
    private ALegendaryTrackerInput Input;
    private TArray<ALegendaryMarker> Markers;   // text pool
    private TArray<ALegendaryOrb>    Orbs;       // orb pool

    private TArray<ANPCBase>    Tracked;
    private TArray<FString>     TrackedText;
    private TArray<FColor>      TrackedLabelColor;  // per-target label colour (variant-coded)
    private TArray<UStaticMesh> TrackedOrbMesh;     // per-target orb mesh (variant-coded)

    private FGameplayTag LocketTag;
    private bool  bLocketResolved = false;
    private bool  bGrantChecked   = false;
    private bool  bAnnounced      = false;
    private bool  bWasActive      = false;
    private bool  bCatalogDumped  = false;
    private float ScanTimer       = 0;
    private float UpkeepTimer      = 0;   // throttles the inventory-upkeep pass (single-locket + vanish drops)

    // Per-variant orb meshes (each variant falls back to the legendary mesh).
    private UStaticMesh OrbMeshLegendary;
    private UStaticMesh OrbMeshCelestial;
    private UStaticMesh OrbMeshShifty;
    private UStaticMesh OrbMeshBoth;
    private bool bOrbMeshResolved = false;

    private UNiagaraSystem    BeamEffect;          // cached crafting-station connection beam VFX
    private bool              bBeamResolved = false;
    private UNiagaraComponent Beam;                // the single live beam: you -> nearest target
    private float             LastBeamSpawnTime = 0.0; // when the current pulse was (re)fired
    private bool              bBeamActive = false;     // a pulse cycle is in progress
    private bool              bFireBeamPending = false; // one-shot mode: a select-ping is queued
    private float             BeamDespawnTime = 0.0;   // one-shot mode: when to remove the ping beam
    private bool              bPermanentBeamOn = false; // hotkey toggle: permanent familiar->you beam
    private FVector           LastBeamStart;            // permanent mode: where the beam's start is anchored

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
        if (Player == nullptr || Controller == nullptr || Controller.PlayerCameraManager == nullptr)
        {
            HideAllVisuals();
            return;
        }

        // Wait for item assets before touching the item subsystem.
        UItemSubsystem ItemSub = UItemSubsystem::Get();
        if (ItemSub == nullptr || !ItemSub.IsDoneLoading())
        {
            HideAllVisuals();
            return;
        }

        if (!bAnnounced)
        {
            bAnnounced = true;
            if (LegendaryTrackerConfig::bVerboseLog)
                Log(n"LegendaryTracker", f"Active. Detector='{LegendaryTrackerConfig::DetectorItemName}' MinStars={LegendaryTrackerConfig::MinStars}");
        }

        // One-time catalogue dump (retries each tick until item defs have loaded).
        if (LegendaryTrackerConfig::bDumpItemCatalog && !bCatalogDumped)
        {
            if (DumpItemCatalog())
                bCatalogDumped = true;
        }

        ResolveLocketTag();
        ResolveOrbMesh();
        EnsureInput();
        MaybeGrantDetector(Player);

        if (Input != nullptr && Input.bGrantRequested)
        {
            Input.bGrantRequested = false;
            // Context-sensitive K: grant the locket if the player doesn't carry
            // one; once they do (grant would be a no-op), the same key toggles
            // the permanent beam instead.
            const bool bHasLocket = LocketTag.IsValid()
                && Player.InventoryComp != nullptr
                && Player.InventoryComp.GetTotalItemCountByTag(LocketTag) > 0;
            if (bHasLocket)
                ToggleBeam();
            else
                DoGrant(Player, true);
        }

        // Inventory upkeep: keep at most one locket AND vanish any dropped on the
        // floor. Runs whether or not the tracker is active (dropping deselects the
        // locket, so we can't gate this on the active scan), on a light cadence.
        UpkeepTimer += DeltaTime;
        if (UpkeepTimer >= LegendaryTrackerConfig::UpkeepInterval)
        {
            UpkeepTimer = 0;
            EnforceSingleLocket(Player);
            VanishDroppedLockets();
        }

        const bool bActive = IsDetectorSelected(Player);
        if (bActive != bWasActive)
        {
            bWasActive = bActive;
            if (bActive)
            {
                // Just selected: queue a single beam ping and force an immediate
                // rescan so the nearest target is known this very frame.
                bFireBeamPending = true;
                ScanTimer = LegendaryTrackerConfig::ScanInterval;
            }
            if (LegendaryTrackerConfig::bVerboseLog)
                Log(n"LegendaryTracker", bActive ? "Detector selected — trail ON." : "Detector deselected — trail OFF.");
        }
        if (!bActive)
        {
            bFireBeamPending = false;   // re-arm only on the next fresh select
            HideAllVisuals();
            return;
        }

        ScanTimer += DeltaTime;
        if (ScanTimer >= LegendaryTrackerConfig::ScanInterval)
        {
            ScanTimer = 0;
            ResolveBeamEffect();
            RebuildTracked(Player);
        }
        UpdateVisuals(Player, Controller);
    }

    // -------------------------------------------------------------------------
    //  Detection
    // -------------------------------------------------------------------------
    private void RebuildTracked(APlayerCharacter Player)
    {
        Tracked.Reset();
        TrackedText.Reset();
        TrackedLabelColor.Reset();
        TrackedOrbMesh.Reset();

        const FVector PlayerLoc = Player.GetActorLocation();

        int NLeg = 0; int NCel = 0; int NShi = 0; int NBoth = 0;   // variant breakdown (diagnostic)

        TArray<ANPCBase> NPCs;
        GetAllActorsOfClass(NPCs);

        for (ANPCBase NPC : NPCs)
        {
            if (NPC == nullptr || !IsValid(NPC))
                continue;

            UFamiliarComponent Fam = NPC.FamiliarComp;
            if (Fam == nullptr)
                continue;
            if (!Fam.ItemTag.IsValid())
                continue;
            if (Fam.GetFamiliarOwner() != nullptr)
                continue;
            if (!NPC.IsAlive())
                continue;

            // Track legendaries (by rarity) plus, optionally, the special
            // visual variants regardless of rarity.
            const bool bIsLegendary = int(Fam.Rarity) >= LegendaryTrackerConfig::MinStars;
            const bool bCelestial   = Fam.IsCelestial();
            const bool bShifty      = Fam.IsShifty();
            const bool bTrack = bIsLegendary
                || (LegendaryTrackerConfig::bTrackCelestial && bCelestial)
                || (LegendaryTrackerConfig::bTrackShifty && bShifty);
            if (!bTrack)
                continue;

            const float Dist = (NPC.GetActorLocation() - PlayerLoc).Size();
            if (Dist > LegendaryTrackerConfig::DetectRadius)
                continue;

            const int DistM = int(Dist / 100.0);
            const FString FamName = Fam.GetFamiliarName().ToString();   // 'Name' shadows GetName accessor

            // Prefix tokens (rarity stars + variant words) and the variant colour.
            FString Prefix;
            if (bIsLegendary) Prefix += "*** ";
            if (bCelestial)   Prefix += "CELESTIAL ";
            if (bShifty)      Prefix += "SHIFTY ";

            FColor LabelCol;
            UStaticMesh OrbM;
            if (bCelestial && bShifty)
            {
                LabelCol = LegendaryTrackerConfig::ShiftyCelestialColor;
                OrbM = OrbMeshBoth;
                NBoth++;
            }
            else if (bCelestial)
            {
                LabelCol = LegendaryTrackerConfig::CelestialColor;
                OrbM = OrbMeshCelestial;
                NCel++;
            }
            else if (bShifty)
            {
                LabelCol = LegendaryTrackerConfig::ShiftyColor;
                OrbM = OrbMeshShifty;
                NShi++;
            }
            else
            {
                LabelCol = LegendaryTrackerConfig::MarkerColor;  // plain legendary
                OrbM = OrbMeshLegendary;
                NLeg++;
            }

            Tracked.Add(NPC);
            TrackedText.Add(f"{Prefix}{FamName}  {DistM}m");
            TrackedLabelColor.Add(LabelCol);
            TrackedOrbMesh.Add(OrbM);
        }

        if (LegendaryTrackerConfig::bVerboseLog && Tracked.Num() > 0)
            Log(n"LegendaryTracker", f"tracking {Tracked.Num()} nearby — legendary:{NLeg} celestial:{NCel} shifty:{NShi} both:{NBoth}");
    }

    // -------------------------------------------------------------------------
    //  Per-frame: float an orb + label over each tracked legendary.
    // -------------------------------------------------------------------------
    private void UpdateVisuals(APlayerCharacter Player, APlayerController Controller)
    {
        const FVector CamLoc = Controller.PlayerCameraManager.GetCameraLocation();

        // Shared orb animation (same phase for all orbs).
        const float Time = Game::GetWorldTimeSeconds();
        const float SpinYaw = Time * LegendaryTrackerConfig::OrbSpinDegPerSec;
        const float BobZ = Math::Sin(Time * LegendaryTrackerConfig::OrbBobSpeed) * LegendaryTrackerConfig::OrbBobAmplitude;
        const bool bOrbOn = LegendaryTrackerConfig::bShowOrb && OrbMeshLegendary != nullptr;

        // Nearest tracked familiar this frame -> the beam's far (live) end.
        const FVector PlayerLoc = Player.GetActorLocation();
        float        BestDistSq = -1.0;
        FVector      BestTarget;

        int Shown = 0;
        for (int i = 0; i < Tracked.Num(); i++)
        {
            ANPCBase NPC = Tracked[i];
            if (NPC == nullptr || !IsValid(NPC) || !NPC.IsAlive())
                continue;

            UFamiliarComponent Fam = NPC.FamiliarComp;
            if (Fam == nullptr || Fam.GetFamiliarOwner() != nullptr)
                continue;

            // Head-top anchor.
            FVector BoundsOrigin;
            FVector BoundsExtent;
            NPC.GetActorBounds(true, BoundsOrigin, BoundsExtent);
            const FVector ActorLoc = NPC.GetActorLocation();
            const float HeadZ = BoundsOrigin.Z + BoundsExtent.Z;
            const FVector HeadTop = FVector(ActorLoc.X, ActorLoc.Y, HeadZ);
            const FVector OrbAnchor = HeadTop + FVector::UpVector * LegendaryTrackerConfig::OrbVerticalOffset;

            // Nearest legendary -> beam tip (aim at the orb's resting spot).
            const float DistSq = (ActorLoc - PlayerLoc).SizeSquared();
            if (BestDistSq < 0.0 || DistSq < BestDistSq)
            {
                BestDistSq = DistSq;
                BestTarget = OrbAnchor;
            }

            // Orb (the orb's item mesh = the variant's colour).
            if (bOrbOn)
            {
                ALegendaryOrb Orb = EnsureOrb(Shown);
                if (Orb != nullptr)
                {
                    Orb.ConfigureMesh(TrackedOrbMesh[i], LegendaryTrackerConfig::OrbTargetSize);
                    Orb.UpdateOrb(OrbAnchor + FVector::UpVector * BobZ, SpinYaw);
                }
            }

            // Label.
            if (LegendaryTrackerConfig::bShowText)
            {
                ALegendaryMarker Marker = EnsureMarker(Shown);
                if (Marker != nullptr)
                {
                    const FVector LabelLoc = HeadTop + FVector::UpVector * LegendaryTrackerConfig::TextVerticalOffset;
                    const FVector ToCam = CamLoc - LabelLoc;
                    const float WorldSize = Math::Clamp(ToCam.Size() * LegendaryTrackerConfig::ScreenSizeFactor, LegendaryTrackerConfig::MinTextSize, LegendaryTrackerConfig::MaxTextSize);
                    FRotator Face = ToCam.Rotation();
                    Face.Pitch = 0;
                    Face.Roll = 0;
                    Marker.UpdateLabel(LabelLoc, Face, WorldSize, TrackedText[i], TrackedLabelColor[i]);
                }
            }

            Shown++;
        }

        // Hide leftover visuals from a previous, larger frame.
        for (int i = Shown; i < Markers.Num(); i++)
            if (Markers[i] != nullptr && IsValid(Markers[i]))
                Markers[i].HideLabel();
        for (int i = Shown; i < Orbs.Num(); i++)
            if (Orbs[i] != nullptr && IsValid(Orbs[i]))
                Orbs[i].HideOrb();

        // Trail beam: origin on the player, live end on the nearest familiar.
        const FVector PlayerStart = PlayerLoc + FVector::UpVector * LegendaryTrackerConfig::TrailStartOffsetZ;
        UpdateTrail(PlayerStart, BestDistSq >= 0.0, BestTarget);
    }

    // -------------------------------------------------------------------------
    //  Trail beam. Two modes:
    //   * One-shot (default): fire a SINGLE pulse you -> nearest legendary the
    //     first frame a target exists after you select the locket, then stay
    //     quiet until you re-select. A directional "ping", not a constant beam.
    //   * Continuous: re-fire on a TIMER (TrailRespawnInterval) while a target is
    //     in range, both ends driven live each frame (follows you + the familiar).
    // -------------------------------------------------------------------------
    private void UpdateTrail(const FVector& PlayerLoc, bool bHasTarget, const FVector& TargetLoc)
    {
        if (!LegendaryTrackerConfig::bShowTrail || BeamEffect == nullptr)
        {
            ClearBeam();
            return;
        }

        const float Now = Game::GetWorldTimeSeconds();

        // Permanent beam (hotkey): reversed — origin on the familiar, far end on
        // you, so the glittery origin stays on the distant familiar. We drive your
        // end live and re-anchor the start only when the nearest target moves.
        if (bPermanentBeamOn)
        {
            if (!bHasTarget)
            {
                ClearBeam();
                return;
            }

            const bool bNeedAnchor = !bBeamActive
                || (TargetLoc - LastBeamStart).SizeSquared() > (LegendaryTrackerConfig::BeamReanchorDist * LegendaryTrackerConfig::BeamReanchorDist);
            if (bNeedAnchor)
            {
                ClearBeam();
                Beam = Niagara::SpawnSystemAtLocation(BeamEffect, TargetLoc);   // start AT the familiar
                LastBeamStart = TargetLoc;
                bBeamActive = true;
                if (Beam == nullptr)
                    return;
            }

            if (Beam != nullptr && IsValid(Beam))
                Beam.SetVectorParameter(n"EndPos", PlayerLoc);
            return;
        }

        if (LegendaryTrackerConfig::bBeamOnSelectOnly)
        {
            // Fire exactly once per select, as soon as there's something to aim at.
            if (bFireBeamPending && bHasTarget)
            {
                ClearBeam();
                Beam = Niagara::SpawnSystemAtLocation(BeamEffect, PlayerLoc);
                bFireBeamPending = false;
                if (Beam != nullptr)
                    Beam.SetVectorParameter(n"EndPos", TargetLoc);
                BeamDespawnTime = Now + LegendaryTrackerConfig::TrailTravelDuration;
            }
            // The station beam is persistent (no auto-destroy) -> remove the ping
            // ourselves once its on-screen time is up.
            else if (Beam != nullptr && IsValid(Beam) && Now >= BeamDespawnTime)
            {
                ClearBeam();
            }
            return;
        }

        // ----- Continuous mode -----
        if (!bHasTarget)
        {
            ClearBeam();
            return;
        }

        // Re-anchor the beam's start to your current spot every interval (the
        // station beam has no live StartPosition param, so we respawn to move it).
        const bool bDue = !bBeamActive || (Now - LastBeamSpawnTime) >= LegendaryTrackerConfig::TrailRespawnInterval;
        if (bDue)
        {
            ClearBeam();
            Beam = Niagara::SpawnSystemAtLocation(BeamEffect, PlayerLoc);
            LastBeamSpawnTime = Now;
            bBeamActive = true;
            if (Beam == nullptr)
                return;
        }

        // EndPos IS a live param -> drive it every frame so the far end tracks the
        // familiar between re-anchors. (Start stays put until the next re-anchor.)
        if (Beam != nullptr && IsValid(Beam))
            Beam.SetVectorParameter(n"EndPos", TargetLoc);
    }

    private void ClearBeam()
    {
        if (Beam != nullptr && IsValid(Beam))
            Beam.DestroyComponent(Beam.Owner);
        Beam = nullptr;
        bBeamActive = false;   // next target re-fires a fresh pulse right away
    }

    private void ResolveBeamEffect()
    {
        if (bBeamResolved || !LegendaryTrackerConfig::bShowTrail)
            return;

        // Source the blue "connection" beam off any loaded crafting station. Only
        // available near base; once cached (an asset pointer) it works anywhere.
        TArray<AWorkstation> Workstations;
        GetAllActorsOfClass(Workstations);
        for (AWorkstation WS : Workstations)
        {
            if (WS == nullptr || WS.CraftingComp == nullptr)
                continue;
            if (WS.CraftingComp.StationConnectionVisualEffect == nullptr)
                continue;

            BeamEffect = WS.CraftingComp.StationConnectionVisualEffect;
            bBeamResolved = true;
            if (LegendaryTrackerConfig::bVerboseLog)
                Log(n"LegendaryTracker", "Trail beam VFX sourced from a crafting station's connection beam (blue).");
            return;
        }
        // No station loaded yet — retry next scan (don't latch bBeamResolved).
    }

    private ALegendaryMarker EnsureMarker(int Index)
    {
        while (Markers.Num() <= Index)
        {
            ALegendaryMarker M = Cast<ALegendaryMarker>(SpawnActor(ALegendaryMarker));
            Markers.Add(M);
        }
        return Markers[Index];
    }

    private ALegendaryOrb EnsureOrb(int Index)
    {
        // Mesh is set per-familiar in UpdateVisuals (variant-coded), not here.
        while (Orbs.Num() <= Index)
            Orbs.Add(Cast<ALegendaryOrb>(SpawnActor(ALegendaryOrb)));
        return Orbs[Index];
    }

    private void HideAllVisuals()
    {
        for (int i = 0; i < Markers.Num(); i++)
            if (Markers[i] != nullptr && IsValid(Markers[i]))
                Markers[i].HideLabel();
        for (int i = 0; i < Orbs.Num(); i++)
            if (Orbs[i] != nullptr && IsValid(Orbs[i]))
                Orbs[i].HideOrb();
        ClearBeam();
    }

    // -------------------------------------------------------------------------
    //  Orb mesh: borrow a static mesh from an existing item definition.
    // -------------------------------------------------------------------------
    private void ResolveOrbMesh()
    {
        if (bOrbMeshResolved)
            return;
        bOrbMeshResolved = true;

        OrbMeshLegendary = MeshFromItemTag(LegendaryTrackerConfig::OrbItemTag);
        UStaticMesh Cel  = MeshFromItemTag(LegendaryTrackerConfig::CelestialOrbItemTag);
        UStaticMesh Shi  = MeshFromItemTag(LegendaryTrackerConfig::ShiftyOrbItemTag);
        UStaticMesh Both = MeshFromItemTag(LegendaryTrackerConfig::ShiftyCelestialOrbItemTag);

        // A variant with no usable mesh falls back to the legendary orb.
        OrbMeshCelestial = (Cel  != nullptr) ? Cel  : OrbMeshLegendary;
        OrbMeshShifty    = (Shi  != nullptr) ? Shi  : OrbMeshLegendary;
        OrbMeshBoth      = (Both != nullptr) ? Both : OrbMeshLegendary;

        if (LegendaryTrackerConfig::bVerboseLog)
        {
            const bool bHaveFallback = OrbMeshLegendary != nullptr;
            LogOrbResolve("legendary", LegendaryTrackerConfig::OrbItemTag, OrbMeshLegendary, bHaveFallback);
            LogOrbResolve("celestial", LegendaryTrackerConfig::CelestialOrbItemTag, Cel, bHaveFallback);
            LogOrbResolve("shifty",    LegendaryTrackerConfig::ShiftyOrbItemTag, Shi, bHaveFallback);
            LogOrbResolve("both",      LegendaryTrackerConfig::ShiftyCelestialOrbItemTag, Both, bHaveFallback);
        }
    }

    // Logs whether the variant's OWN item mesh resolved (vs fell back to legendary).
    private void LogOrbResolve(const FString& Variant, FName Tag, UStaticMesh OwnMesh, bool bHaveFallback)
    {
        const FString TagStr = Tag.ToString();
        if (OwnMesh != nullptr)
            Log(n"LegendaryTracker", f"orb[{Variant}]: '{TagStr}' resolved");
        else if (bHaveFallback)
            Log(n"LegendaryTracker", f"orb[{Variant}]: '{TagStr}' has no mesh — using legendary fallback (blue)");
        else
            Log(n"LegendaryTracker", f"orb[{Variant}]: '{TagStr}' has no mesh and no fallback — orb hidden");
    }

    private UStaticMesh MeshFromItemTag(FName ItemTagName)
    {
        const FGameplayTag Tag = FGameplayTag::RequestGameplayTag(ItemTagName);
        if (!Tag.IsValid())
            return nullptr;
        const UItemDefinition Def = UItemSubsystem::GetItemDefinition(Tag);
        if (Def == nullptr || Def.ActorsToSpawn.IsEmpty())
            return nullptr;
        FItemActorToSpawn Spawn = Def.ActorsToSpawn[0];
        return Spawn.StaticMesh;
    }

    // -------------------------------------------------------------------------
    //  One-time catalogue dump: every item that has a usable orb mesh (tag +
    //  name), to help choose the per-variant orb items. Returns true once item
    //  defs have loaded and the dump ran.
    // -------------------------------------------------------------------------
    private bool DumpItemCatalog()
    {
        TArray<FGameplayTag> Leaves;
        TSet<FGameplayTag> Visited;
        GatherLeafTags(GameplayTags::Items, Leaves, Visited, 0);
        if (Leaves.Num() == 0)
            return false;   // tag tree not ready yet

        int Loaded = 0;
        int WithMesh = 0;

        Log(n"LegendaryTracker", f"===== ORB ITEM CATALOGUE START ({Leaves.Num()} item tags) =====");
        Log(n"LegendaryTracker", "(items below have a usable orb mesh — candidates for the per-variant orbs)");

        for (const FGameplayTag& Tag : Leaves)
        {
            const UItemDefinition Def = UItemSubsystem::GetItemDefinition(Tag);
            if (Def == nullptr)
                continue;
            Loaded++;
            if (Def.ActorsToSpawn.IsEmpty() || Def.ActorsToSpawn[0].StaticMesh == nullptr)
                continue;

            WithMesh++;
            const FString ItemName = Def.DisplayName.ToString();
            const FString TagStr = Tag.ToString();
            Log(n"LegendaryTracker", f"  ORB-ABLE  {ItemName}  [{TagStr}]");
        }

        if (Loaded == 0)
            return false;   // defs not ready yet — try again next tick

        Log(n"LegendaryTracker", f"===== ORB ITEM CATALOGUE END: {WithMesh} items with a mesh / {Loaded} defs loaded =====");
        return true;
    }

    // Recursively collect leaf tags (tags with no children) beneath Root.
    private void GatherLeafTags(const FGameplayTag& Root, TArray<FGameplayTag>& OutLeaves, TSet<FGameplayTag>& Visited, int Depth)
    {
        if (Depth > 12 || Visited.Contains(Root))
            return;
        Visited.Add(Root);

        const FGameplayTagContainer Children = UGameplayTagsManager::RequestGameplayTagChildren(Root);
        if (Children.GameplayTags.Num() == 0)
        {
            OutLeaves.Add(Root);
            return;
        }
        for (const FGameplayTag& Child : Children.GameplayTags)
            GatherLeafTags(Child, OutLeaves, Visited, Depth + 1);
    }

    // -------------------------------------------------------------------------
    //  Detector item
    // -------------------------------------------------------------------------
    private void ResolveLocketTag()
    {
        if (bLocketResolved)
            return;
        bLocketResolved = true;
        LocketTag = FGameplayTag::RequestGameplayTag(LegendaryTrackerConfig::DetectorItemTag);
        if (!LocketTag.IsValid())
            Log(n"LegendaryTracker", f"WARNING: detector item tag '{LegendaryTrackerConfig::DetectorItemName}' did not resolve");
    }

    // The trail is gated on the detector being the player's SELECTED hotbar
    // item (not merely carried) — put the locket on a hotbar slot and select it.
    private bool IsDetectorSelected(APlayerCharacter Player)
    {
        if (!LocketTag.IsValid() || Player.HotbarComp == nullptr)
            return false;
        UItemStack Stack = Player.HotbarComp.GetSelectedItemStack();
        return Stack != nullptr && Stack.GetItemTag() == LocketTag;
    }

    private void MaybeGrantDetector(APlayerCharacter Player)
    {
        if (bGrantChecked)
            return;
        if (!System::IsServer())
        {
            bGrantChecked = true;
            return;
        }
        if (!LegendaryTrackerConfig::bAutoGrantOnce || !LocketTag.IsValid())
        {
            bGrantChecked = true;
            return;
        }
        if (Player.InventoryComp == nullptr)
            return;

        UPlayerStatisticsComponent Stats = UPlayerStatisticsComponent::Get(Player);
        if (Stats != nullptr && Stats.IsItemKnown(LocketTag))
        {
            bGrantChecked = true;
            return;
        }
        if (Player.InventoryComp.GetTotalItemCountByTag(LocketTag) > 0)
        {
            bGrantChecked = true;
            return;
        }

        DoGrant(Player, false);
        // Only stop retrying once the player actually holds it. A full-bag grant
        // is skipped (no floor spill), so leave the check open and try again on a
        // later tick — the first-time gift lands as soon as a slot frees up.
        if (Player.InventoryComp.GetTotalItemCountByTag(LocketTag) > 0)
            bGrantChecked = true;
    }

    // Single-locket rule: the detector is a one-of-a-kind tool, not a stackable
    // consumable. Keep at most ONE in the inventory at any time, trimming any
    // extras the player may have acquired (e.g. picking up a dropped copy).
    // Server-authoritative, same as the grant path.
    //
    // We KEEP the copy the player currently has selected on the hotbar (so the
    // trim never flicks the tracker off mid-use) and remove every OTHER locket
    // stack by handle. The locket is non-stackable, so each extra is its own
    // slot; the final guard also pares a merged stack down to 1 just in case.
    private void EnforceSingleLocket(APlayerCharacter Player)
    {
        if (!LegendaryTrackerConfig::bEnforceSingleLocket)
            return;
        if (!System::IsServer() || !LocketTag.IsValid() || Player.InventoryComp == nullptr)
            return;

        if (Player.InventoryComp.GetTotalItemCountByTag(LocketTag) <= 1)
            return;   // fast path: at most one, nothing to do

        // Prefer to keep the selected stack; otherwise the first locket we find.
        UItemStack Keep = nullptr;
        if (Player.HotbarComp != nullptr)
        {
            UItemStack Sel = Player.HotbarComp.GetSelectedItemStack();
            if (Sel != nullptr && Sel.GetItemTag() == LocketTag)
                Keep = Sel;
        }

        int Removed = 0;
        // Snapshot first — RemoveItemStack mutates AllItemStacks mid-iteration.
        TArray<UItemStack> Stacks = Player.InventoryComp.AllItemStacks;
        for (UItemStack Stack : Stacks)
        {
            if (Stack == nullptr || Stack.StackSize <= 0 || Stack.GetItemTag() != LocketTag)
                continue;
            if (Keep == nullptr)        // nothing chosen yet -> this becomes the keeper
            {
                Keep = Stack;
                continue;
            }
            if (Stack == Keep)
                continue;
            Removed += Stack.StackSize;
            Player.InventoryComp.RemoveItemStack(Stack);
        }

        // Keeper holds >1 (stackable build) -> pare down to a single locket. Every
        // other locket stack is gone now, so a by-tag remove only touches Keep.
        if (Keep != nullptr && Keep.StackSize > 1)
        {
            const int Extra = Keep.StackSize - 1;
            Removed += Extra;
            Player.InventoryComp.RemoveItemsByTag(LocketTag, Extra);
        }

        if (Removed > 0 && LegendaryTrackerConfig::bVerboseLog)
            Log(n"LegendaryTracker", f"Enforced single locket — removed {Removed} extra.");
    }

    // Make a dropped locket disappear instead of resting on the floor as a world
    // pickup. Server-authoritative: any AHercItemPickup carrying the locket tag is
    // destroyed (network-wide). Re-grant with the hotkey (K) to get one back.
    private void VanishDroppedLockets()
    {
        if (!LegendaryTrackerConfig::bVanishDroppedLocket)
            return;
        if (!System::IsServer() || !LocketTag.IsValid())
            return;

        TArray<AHercItemPickup> Pickups;
        GetAllActorsOfClass(Pickups);

        int Vanished = 0;
        for (AHercItemPickup Pickup : Pickups)
        {
            if (Pickup == nullptr || !IsValid(Pickup))
                continue;
            if (Pickup.ItemTag != LocketTag)
                continue;
            Pickup.DestroyActor();
            Vanished++;
        }

        if (Vanished > 0 && LegendaryTrackerConfig::bVerboseLog)
            Log(n"LegendaryTracker", f"Vanished {Vanished} dropped locket(s) from the floor.");
    }

    private void DoGrant(APlayerCharacter Player, bool bFromHotkey)
    {
        if (!System::IsServer() || !LocketTag.IsValid() || Player.InventoryComp == nullptr)
            return;

        if (Player.InventoryComp.GetTotalItemCountByTag(LocketTag) > 0)
        {
            if (bFromHotkey && LegendaryTrackerConfig::bVerboseLog)
                Log(n"LegendaryTracker", "Grant hotkey: you already carry the detector.");
            return;
        }

        // Never grant into a full bag: AddItemsByTag would spill the locket onto
        // the floor, and spamming K would carpet the area with drops and lag the
        // server. Bail out cleanly instead.
        if (!Player.InventoryComp.CanAddItemsByTag(LocketTag, 1))
        {
            if (bFromHotkey && LegendaryTrackerConfig::bVerboseLog)
                Log(n"LegendaryTracker", "Grant hotkey: inventory full — locket not granted.");
            return;
        }

        Player.InventoryComp.AddItemsByTag(LocketTag, 1);
        if (LegendaryTrackerConfig::bVerboseLog)
            Log(n"LegendaryTracker", f"Granted detector: {LegendaryTrackerConfig::DetectorItemName}");
    }

    // Flip the beam between permanent (familiar -> you) and ping-on-select.
    private void ToggleBeam()
    {
        bPermanentBeamOn = !bPermanentBeamOn;
        bFireBeamPending = false;   // a mode toggle shouldn't trigger a stale select-ping
        ClearBeam();                // reset so the new mode starts clean
        if (LegendaryTrackerConfig::bVerboseLog)
            Log(n"LegendaryTracker", bPermanentBeamOn ? "Permanent beam ON (familiar -> you)." : "Permanent beam OFF (ping-on-select).");
    }

    private void EnsureInput()
    {
        if (!LegendaryTrackerConfig::bEnableGrantHotkey)
            return;
        if (Input == nullptr || !IsValid(Input))
            Input = Cast<ALegendaryTrackerInput>(SpawnActor(ALegendaryTrackerInput));
    }
}
