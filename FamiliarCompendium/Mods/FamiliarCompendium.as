// =============================================================================
//  Familiar Compendium — a captured-familiar "pokedex" (client-side, read-only)
//
//  Press ToggleKey to open a floating panel listing every familiar species in
//  the game, grouped by element. Use the arrow keys to move a SELECTION cursor
//  through the list; the right-hand DETAIL PANE shows the highlighted familiar's
//  element, capture status and which FORMS you own (rarity stars + shifty /
//  celestial), plus a floating 3D MODEL of it.
//
//  Caught species show their name in white; species you've never bonded show
//  their name GREYED (no more "???") so the list reads as a real dex.
//
//  Data sources (all existing game systems, nothing is modified):
//   * Roster  — every UItemDefinition under the `Items` gameplay-tag tree that
//               carries a UItemFragment_Familiar, then filtered down to the base
//               catchable species (the game has no "catchable" flag, so its data
//               also holds elemental variants, named bosses and cut content; see
//               the roster-filtering rules in FamiliarDexConfig).
//   * Caught  — UPlayerStatisticsComponent.IsItemKnown(tag). The game already
//               records (and SAVES) every item the player has ever held, and a
//               bonded familiar is added to the inventory, so this persists
//               across release + quit-to-desktop with zero custom save code.
//   * Element — UItemRuntimeFragment_FamiliarActions.ProgressionElementalType.
//   * Forms   — read from the familiars you actually OWN: each bonded familiar is
//               a saved UItemStack carrying its rarity (UItemRuntimeFragment_Rarity)
//               and visual variant (UItemRuntimeFragment_FamiliarInfo.VisualVariant);
//               summoned familiars also expose UFamiliarComponent.Rarity/IsCelestial/
//               IsShifty. We scan FamiliarInventoryComp + the bag + owned NPCs each
//               open and remember the best form seen per species this session.
//
//               NOTE: the game does NOT persist per-form history beyond the caught
//               boolean, and a script mod can't safely add its own save data (an
//               earlier attempt to ride the player's EMS save corrupted the player
//               record on reload), so form info is shown for familiars you currently
//               own (which the game DOES save) plus any seen this session. A species
//               caught then released keeps the caught flag but loses its form badge
//               — that's a game-data limit we deliberately don't fight.
//
//  Renders with UTextRenderComponent (world-space 3D text) anchored in front of
//  the camera — the same Shipping-safe approach as LingerChanceIndicator; no
//  UMG/Blueprint asset required. The model preview borrows the familiar item's
//  static mesh, the same trick LegendaryTracker uses for its orb.
// =============================================================================

namespace FamiliarDexConfig
{
    // >>> Hotkeys. BindKey doesn't consume input, so these co-exist with the
    //     game's own bindings. Any EKeys::... value works.
    const FKey ToggleKey = EKeys::P;          // open / close the compendium
    const FKey ScrollUpKey = EKeys::Up;       // move selection up
    const FKey ScrollDownKey = EKeys::Down;   // move selection down

    const int   MaxVisibleRows = 18;    // body rows shown before the list scrolls
    const float PanelDistance  = 90.0;  // cm in front of the camera (just the depth the panel floats at)

    // Layout is expressed as FRACTIONS of the viewport, so the panel looks the
    // same on 16:9, 21:9, ultrawide and any resolution. At runtime these are
    // converted to world size using the measured screen span at the panel depth.
    const float TextFracH = 0.030;      // glyph height, as a fraction of viewport height
    const float LineFracH = 0.040;      // row pitch, as a fraction of viewport height
    const float LeftFracX = 0.08;       // list left edge, fraction in from the screen's left
    const float TopFracY  = 0.06;       // title row, fraction down from the screen's top

    // ----- Selection cursor + detail pane + model preview -----------------------
    // The detail pane is a second text column on the RIGHT; the model floats above
    // it. All positions are viewport fractions, like the list.
    const bool  bShowModel       = true;   // float a 3D model of the selected familiar
    const float DetailLeftFracX  = 0.60;   // detail column left edge (fraction from left; >0.5 = right of centre)
    const float DetailTopFracY   = 0.44;   // detail text block top (fraction down from top)
    const float ModelRightFracX  = 0.24;   // model offset right of the panel centre (fraction of screen width)
    const float ModelUpFracY     = 0.15;   // model offset up from the panel centre (fraction of screen height)
    const float ModelSizeFracH   = 0.22;   // model target size (fraction of screen height)
    const float ModelDepthPull   = 12.0;   // cm toward the camera, so the model floats in front of the text
    const float ModelSpinDegPerSec = 55.0; // turntable spin
    const float ModelBobAmplitude  = 2.5;  // cm of up/down bob
    const float ModelBobSpeed      = 1.6;  // bob speed (rad/s)

    // Freeze player movement + camera while the compendium is open, so it reads
    // like a real menu. Hotkeys still work (they're on a separate input component).
    const bool bFreezePlayerWhileOpen = true;

    // Hide the game HUD (health/mana, hotbar, quest tracker, ...) while open, so the
    // compendium gets a clean, uncluttered "menu" backdrop. Restored on close.
    const bool bHideHudWhileOpen = true;

    // Log every discovered species to Hercules.log on first open. Handy to verify
    // the roster was found; set false once you've confirmed it.
    const bool bVerboseLog = true;

    // ----- Background effect while the compendium is open -----------------------
    // Blur the world behind the panel with a depth-of-field post-process focused at
    // the panel depth: the panel text sits on the focal plane and stays crisp while
    // everything behind it goes soft. Asset-free -- it drives the engine's built-in
    // FPostProcessSettings, the same struct the game uses for its own effects.
    const bool  bBlurBackgroundWhileOpen = true;
    const float BlurFocalDistance = PanelDistance;  // cm; keep == PanelDistance so the text stays sharp
    const float BlurFstop = 1.0;                    // lower = stronger blur (cinematic DoF aperture)

    // Darken the screen for a "modal menu" feel, via a held manual camera fade. This
    // dims everything uniformly (the text too); the blurred, dimmed world then reads
    // clearly behind the sharp, brighter panel text. 0 = none .. 1 = fully DimColor.
    const bool  bDimBackgroundWhileOpen = true;
    const float DimAmount = 0.5;
    const FLinearColor DimColor = FLinearColor(0.0, 0.0, 0.0, 1.0);

    // Text legibility. Each glyph row is backed by a ring of black copies forming a
    // solid outline -- the real driver of readability over a bright/busy world (the
    // fullscreen dim darkens text and background equally, so it can't do this). More
    // samples = smoother outline (8 = full ring); thicker = bolder edge.
    const int   OutlineSamples = 8;       // black copies ringed around each glyph row
    const float OutlineThicknessFrac = 0.07;  // offset distance, as a fraction of glyph height

    // ----- Roster filtering -----------------------------------------------------
    // The game has no "is this catchable" flag, and its item data holds many
    // familiar definitions that aren't real catchable species: elemental recolors,
    // named bosses, and cut/broken content. These rules trim the roster down to the
    // base catchable species. Turn on bVerboseLog to see, in Hercules.log, exactly
    // what each rule KEPT vs DROPPED, then edit the rules/lists below to taste.

    // Collapse entries that share a display name into one (e.g. the four "Treetop"
    // forms). A merged species counts as caught if ANY of its forms is known.
    const bool bMergeByDisplayName = true;

    // Drop a familiar whose item tag is "<another familiar's tag> + suffix" -- i.e.
    // an elemental/named variant sitting under a base species (e.g.
    // FamiliarLoijaCrystal under FamiliarLoija, FamiliarQuolNamed under FamiliarQuol).
    const bool bDropTagVariants = true;

    // Drop a familiar whose tag-leaf contains any of these (case-insensitive). Marks
    // named bosses / variant forms that don't sit under a base tag. Edit freely.
    void GetExcludeKeywords(TArray<FString>& Out)
    {
        Out.Add("Named");
        Out.Add("Variant");
        Out.Add("Matriarch");
        Out.Add("Ethereal");
    }

    // Drop these exact tag-leaves outright (cut / broken / mistagged content). The
    // logs show AngelScript errors + "Leaked actor" for Tylocq/Octon; SilvantNox is
    // the only familiar missing the "Familiar" tag prefix. Edit freely.
    void GetExcludeTagLeaves(TArray<FString>& Out)
    {
        Out.Add("FamiliarTylocq");
        Out.Add("FamiliarOcton");
        Out.Add("SilvantNox");
    }
}

// Element -> label / colour helpers. Elements are tags under Effect.Type.Element
// (e.g. Effect.Type.Element.Fire); we colour-code by the leaf name.
namespace FamiliarDex
{
    // Variant bit-flags, OR-ed together per species in the form memory.
    const int FormNormal    = 1;
    const int FormShifty    = 2;
    const int FormCelestial = 4;
    const int FormBoth      = 8;   // shifty + celestial at once

    FString Leaf(const FGameplayTag& Tag)
    {
        FString S = Tag.ToString();
        int Index = -1;
        if (S.FindLastChar('.', Index) && Index >= 0)
            return S.RightChop(Index + 1);
        return S;
    }

    FString ElementLabel(const FGameplayTag& Element)
    {
        if (!Element.IsValid())
            return "Other";
        return Leaf(Element);
    }

    FColor ElementColor(const FGameplayTag& Element)
    {
        const FString L = Element.IsValid() ? Leaf(Element) : "";
        if (L.Contains("Fire"))                                    return FColor(255, 110, 70);
        if (L.Contains("Water"))                                   return FColor(80, 160, 255);
        if (L.Contains("Earth") || L.Contains("Nature") || L.Contains("Grass")) return FColor(120, 205, 95);
        if (L.Contains("Air") || L.Contains("Wind"))               return FColor(185, 235, 255);
        if (L.Contains("Light"))                                   return FColor(255, 235, 150);
        if (L.Contains("Dark") || L.Contains("Shadow"))            return FColor(190, 130, 225);
        if (L.Contains("Ice") || L.Contains("Frost"))              return FColor(150, 225, 240);
        if (L.Contains("Lightning") || L.Contains("Electric") || L.Contains("Thunder")) return FColor(245, 225, 90);
        if (L.Contains("Poison") || L.Contains("Toxic"))           return FColor(170, 225, 90);
        return FColor(205, 205, 205);
    }

    // Stars as a string of '*' (Common = 0 stars = ""). Clamped to 3.
    FString Stars(int Count)
    {
        FString Out;
        const int N = Math::Clamp(Count, 0, 3);
        for (int i = 0; i < N; i++)
            Out += "*";
        return Out;
    }

    // Compact owned-variant marks for the inline list row: "C" celestial, "S" shifty.
    FString VariantMarks(int Flags)
    {
        const bool bCel = (Flags & FormCelestial) != 0 || (Flags & FormBoth) != 0;
        const bool bShi = (Flags & FormShifty) != 0 || (Flags & FormBoth) != 0;
        FString Out;
        if (bCel) Out += "C";
        if (bShi) Out += "S";
        return Out;
    }

    // Human-readable list of the owned variants, for the detail pane.
    FString VariantList(int Flags)
    {
        TArray<FString> Parts;
        if ((Flags & FormNormal) != 0)    Parts.Add("Normal");
        if ((Flags & FormShifty) != 0)    Parts.Add("Shifty");
        if ((Flags & FormCelestial) != 0) Parts.Add("Celestial");
        if ((Flags & FormBoth) != 0)      Parts.Add("Shifty Celestial");
        if (Parts.Num() == 0)
            return "-";

        FString Out = Parts[0];
        for (int i = 1; i < Parts.Num(); i++)
            Out += ", " + Parts[i];
        return Out;
    }
}

// The floating panel: a pool of UTextRenderComponent rows (each backed by a ring
// of black copies forming a solid outline for legibility). The subsystem
// repositions the whole actor in front of the camera and rewrites rows each frame.
// Rows are placed at explicit panel-local positions so the list (left column) and
// the detail pane (right column) can share one pooled set of glyph rows.
UCLASS(NotPlaceable, HideCategories = "Actor Tick Rendering Replication Collision Input")
class AFamiliarDexPanel : AActor
{
    default bReplicates = false;
    default ActorHiddenInGame = true;

    UPROPERTY(DefaultComponent, RootComponent)
    USceneComponent Root;

    private TArray<UTextRenderComponent> MainRows;
    private TArray<UTextRenderComponent> ShadowRows;
    private int UsedCount = 0;

    // Glyph height (world cm), recomputed each frame from the viewport size.
    private float LayoutTextSize = 2.6;

    void SetTextSize(float InTextSize)
    {
        LayoutTextSize = InTextSize;
    }

    // Begin rewriting the panel for this frame.
    void BeginUpdate()
    {
        UsedCount = 0;
        SetActorHiddenInGame(false);
    }

    // Emit one row at an explicit panel-local position. (+Y is screen-left, +Z is
    // screen-up for the camera-facing panel.) Grows the component pool as needed.
    void AddRow(const FString& Text, const FColor& Color, float LocalX, float LocalZ)
    {
        const int i = UsedCount;
        EnsureRow(i);

        const FVector Loc = FVector(0.0, LocalX, LocalZ);
        const float Thickness = LayoutTextSize * FamiliarDexConfig::OutlineThicknessFrac;
        const int Samples = FamiliarDexConfig::OutlineSamples;
        const FText Label = FText::FromString(Text);

        // Black outline ring behind the glyph (drawn slightly further from the camera
        // along -X so the main row occludes the centre, leaving a clean edge).
        for (int k = 0; k < Samples; k++)
        {
            UTextRenderComponent S = ShadowRows[i * Samples + k];
            S.SetVisibility(true);
            S.SetRelativeLocation(Loc + FVector(-0.3, 0.0, 0.0) + OutlineOffset(k, Thickness));
            S.WorldSize = LayoutTextSize;
            S.SetText(Label);
        }

        UTextRenderComponent M = MainRows[i];
        M.SetVisibility(true);
        M.SetRelativeLocation(Loc);
        M.WorldSize = LayoutTextSize;
        M.TextRenderColor = Color;
        M.SetText(Label);

        UsedCount++;
    }

    // Hide any rows left over from a previous, longer frame.
    void EndUpdate()
    {
        const int Samples = FamiliarDexConfig::OutlineSamples;
        for (int i = UsedCount; i < MainRows.Num(); i++)
        {
            MainRows[i].SetVisibility(false);
            for (int k = 0; k < Samples; k++)
                ShadowRows[i * Samples + k].SetVisibility(false);
        }
    }

    void HidePanel()
    {
        SetActorHiddenInGame(true);
    }

    // Y/Z offset for outline copy `Dir`, evenly spaced around a ring of radius `T`.
    // (Panel-local axes: +Y is screen-left, +Z is screen-up.)
    private FVector OutlineOffset(int Dir, float T) const
    {
        const float Ang = float(Dir) * (6.2831853 / float(FamiliarDexConfig::OutlineSamples));
        return FVector(0.0, Math::Cos(Ang) * T, Math::Sin(Ang) * T);
    }

    private void EnsureRow(int Index)
    {
        const int Samples = FamiliarDexConfig::OutlineSamples;
        while (MainRows.Num() <= Index)
        {
            for (int k = 0; k < Samples; k++)
            {
                UTextRenderComponent Shadow = CreateComponent(UTextRenderComponent);
                Shadow.AttachToComponent(Root);
                Shadow.HorizontalAlignment = EHorizTextAligment::EHTA_Left;
                Shadow.VerticalAlignment = EVerticalTextAligment::EVRTA_TextCenter;
                Shadow.TextRenderColor = FColor::Black;
                Shadow.SetCollisionEnabled(ECollisionEnabled::NoCollision);
                ShadowRows.Add(Shadow);
            }

            UTextRenderComponent Main = CreateComponent(UTextRenderComponent);
            Main.AttachToComponent(Root);
            Main.HorizontalAlignment = EHorizTextAligment::EHTA_Left;
            Main.VerticalAlignment = EVerticalTextAligment::EVRTA_TextCenter;
            Main.SetCollisionEnabled(ECollisionEnabled::NoCollision);
            MainRows.Add(Main);
        }
    }
}

// Floating 3D model of the selected familiar: borrows the familiar item's static
// mesh (the same "item mesh" trick LegendaryTracker uses for its orb). Spins +
// bobs; position/scale driven by the subsystem each frame.
UCLASS(NotPlaceable, HideCategories = "Actor Tick Rendering Replication Collision Input")
class AFamiliarDexModel : AActor
{
    default bReplicates = false;
    default ActorHiddenInGame = true;

    UPROPERTY(DefaultComponent, RootComponent)
    USceneComponent Root;

    UPROPERTY(DefaultComponent, Attach = Root)
    UStaticMeshComponent MeshComp;
    default MeshComp.SetCollisionEnabled(ECollisionEnabled::NoCollision);

    private UStaticMesh CurrentMesh;
    private bool bShown = false;

    // Set the mesh (if changed) and normalize its scale so the largest dimension is
    // ~TargetSize. Safe to call every frame.
    void ConfigureMesh(UStaticMesh Mesh, float TargetSize)
    {
        if (Mesh == nullptr)
            return;
        if (Mesh != CurrentMesh)
        {
            CurrentMesh = Mesh;
            MeshComp.SetStaticMesh(Mesh);
        }

        const FVector Ext = Mesh.Bounds.BoxExtent;   // half-extents, unscaled
        const float NativeSize = 2.0 * Math::Max(Ext.X, Math::Max(Ext.Y, Ext.Z));
        const float Scale = (NativeSize > 1.0) ? (TargetSize / NativeSize) : 1.0;
        MeshComp.SetRelativeScale3D(FVector(Scale, Scale, Scale));
    }

    void Show(const FVector& Location, float SpinYaw)
    {
        if (!bShown)
        {
            SetActorHiddenInGame(false);
            bShown = true;
        }
        SetActorLocation(Location);
        MeshComp.SetRelativeRotation(FRotator(0.0, SpinYaw, 0.0));
    }

    void HideModel()
    {
        if (bShown)
        {
            SetActorHiddenInGame(true);
            bShown = false;
        }
    }
}

// Receives the toggle/scroll keys and owns the open + selection state (the
// subsystem reads these each frame). Mirrors LingerChanceIndicator's input actor.
UCLASS(NotPlaceable, HideCategories = "Actor Tick Rendering Replication Collision Input")
class AFamiliarDexInput : AActor
{
    default bReplicates = false;

    UPROPERTY(DefaultComponent, RootComponent)
    USceneComponent Root;   // a UInputComponent can't be the actor root

    UPROPERTY(DefaultComponent)
    UInputComponent InputComp;

    bool bOpen = false;
    int Selection = 0;   // index into the selectable-familiar list; subsystem clamps

    UFUNCTION(BlueprintOverride)
    void BeginPlay()
    {
        APlayerController Controller = Game::GetLocalPlayerController();
        if (Controller == nullptr)
            return;
        Controller.PushInputComponent(InputComp);
        InputComp.BindKey(FamiliarDexConfig::ToggleKey, EInputEvent::IE_Pressed, FInputActionHandlerDynamicSignature(this, n"OnTogglePressed"));
        InputComp.BindKey(FamiliarDexConfig::ScrollUpKey, EInputEvent::IE_Pressed, FInputActionHandlerDynamicSignature(this, n"OnScrollUp"));
        InputComp.BindKey(FamiliarDexConfig::ScrollDownKey, EInputEvent::IE_Pressed, FInputActionHandlerDynamicSignature(this, n"OnScrollDown"));
    }

    UFUNCTION()
    private void OnTogglePressed(FKey Key)
    {
        bOpen = !bOpen;
    }

    UFUNCTION()
    private void OnScrollUp(FKey Key)
    {
        if (bOpen)
            Selection -= 1;   // subsystem clamps to valid range
    }

    UFUNCTION()
    private void OnScrollDown(FKey Key)
    {
        if (bOpen)
            Selection += 1;
    }
}

// Driver: builds the species roster once, rebuilds the display when opened, and
// each frame parks the panel in front of the camera and fills the visible rows.
class UFamiliarDexSubsystem : UScriptWorldSubsystem
{
    private AFamiliarDexPanel Panel;
    private AFamiliarDexModel Model;
    private AFamiliarDexInput Input;

    // Roster (parallel arrays, one entry per familiar species).
    private TArray<FGameplayTag> RosterTags;
    private TArray<FString> RosterNames;
    private TArray<FGameplayTag> RosterElements;
    private bool bRosterBuilt = false;

    // Owned-form memory (this session): species display name -> OR-ed variant flags
    // / best rarity seen. Fed from the familiars the player currently owns.
    private TMap<FString, int> FormFlags;
    private TMap<FString, int> FormBestStar;

    // Pre-rendered body lines for the current open session (left list column).
    private TArray<FString> BodyText;
    private TArray<FColor> BodyColor;
    private TArray<int> RowEntry;   // body-row -> selectable entry index (-1 = header/spacer)

    // Selectable entries (one per displayed species, in list order).
    private TArray<FString> EntryName;
    private TArray<FGameplayTag> EntryElement;
    private TArray<bool> EntryCaught;
    private TArray<FGameplayTag> EntryTag;   // representative item tag (for the model)

    private int CaughtCount = 0;
    private int TotalCount = 0;
    private int ViewOffset = 0;   // first visible body row

    private bool bPrevOpen = false;
    private bool bFrozen = false;
    private bool bHudHidden = false;

    // Background blur (a depth-of-field post-process) + dim state. Created on open,
    // torn down on close. See Enable/DisableBackdrop.
    private UPostProcessComponent Backdrop;
    private bool bBackdropActive = false;

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
            CloseVisuals(Player, Controller);
            return;
        }

        EnsureInput();
        if (Input == nullptr)
            return;

        if (!Input.bOpen)
        {
            CloseVisuals(Player, Controller);
            return;
        }

        EnsurePanel();
        EnsureModel();
        if (Panel == nullptr)
            return;

        // Rising edge: (re)build roster if needed, rebuild display, reset cursor, freeze.
        if (!bPrevOpen)
        {
            if (!bRosterBuilt)
                BuildRoster();
            BuildDisplay(Player);
            Input.Selection = 0;
            ViewOffset = 0;
            if (FamiliarDexConfig::bFreezePlayerWhileOpen)
                Freeze(Player);
            if (FamiliarDexConfig::bHideHudWhileOpen)
                HideHud();
            bPrevOpen = true;
        }

        // Background blur + dim. Re-asserted every frame: the DoF component only
        // spawns once, but the manual camera fade is re-applied so the camera
        // manager can't quietly clear it mid-session.
        if (FamiliarDexConfig::bBlurBackgroundWhileOpen || FamiliarDexConfig::bDimBackgroundWhileOpen)
            EnableBackdrop(Player, Controller);

        // Clamp the selection cursor to the selectable-entry range.
        const int NumEntries = EntryName.Num();
        int Sel = (NumEntries > 0) ? Math::Clamp(Input.Selection, 0, NumEntries - 1) : -1;
        Input.Selection = (Sel < 0) ? 0 : Sel;

        // Park the panel in front of the camera, facing it. (Camera-front anchor
        // mirrors CharacterCreationWidget.as: Location + Rotation.ForwardVector.)
        auto Cam = Controller.PlayerCameraManager;
        const FVector CamLoc = Cam.GetCameraLocation();
        const FVector Forward = Cam.GetCameraRotation().ForwardVector;
        const float Dist = FamiliarDexConfig::PanelDistance;
        const FVector PanelLoc = CamLoc + Forward * Dist;
        Panel.SetActorLocation(PanelLoc);
        Panel.SetActorRotation((CamLoc - PanelLoc).Rotation());   // +X faces camera -> text reads correctly

        // Measure how many world cm the screen spans at the panel's depth, so the
        // panel can be sized as a fraction of the viewport (resolution/FOV/aspect
        // independent). Deproject the top- and bottom-centre pixels onto the panel
        // plane and take the distance between them.
        int VPX = 0;
        int VPY = 0;
        Controller.GetViewportSize(VPX, VPY);
        float ScreenH = Dist;            // safe fallback before the viewport is ready
        float Aspect = 16.0 / 9.0;
        if (VPX > 1 && VPY > 1)
        {
            Aspect = float(VPX) / float(VPY);
            const float CX = VPX * 0.5;
            const FVector TopMid = ScreenToPanelPlane(Controller, CamLoc, Forward, Dist, CX, 0.0);
            const FVector BotMid = ScreenToPanelPlane(Controller, CamLoc, Forward, Dist, CX, float(VPY));
            const float Measured = (TopMid - BotMid).Size();
            if (Measured > 1.0 && Measured < 100000.0)
                ScreenH = Measured;
        }
        const float ScreenW = ScreenH * Aspect;

        // World-space layout metrics (panel-local: +Y screen-left, +Z screen-up).
        const float TextSize = FamiliarDexConfig::TextFracH * ScreenH;
        const float LineH    = FamiliarDexConfig::LineFracH * ScreenH;
        const float LeftX    = (0.5 - FamiliarDexConfig::LeftFracX) * ScreenW;
        const float TopZ     = (0.5 - FamiliarDexConfig::TopFracY) * ScreenH;
        const float DetailX  = (0.5 - FamiliarDexConfig::DetailLeftFracX) * ScreenW;
        const float DetailTopZ = (0.5 - FamiliarDexConfig::DetailTopFracY) * ScreenH;

        // Keep the selected row inside the scroll window.
        const int Total = BodyText.Num();
        const int VisN = FamiliarDexConfig::MaxVisibleRows;
        const int SelRow = RowForEntry(Sel);
        if (SelRow >= 0)
        {
            if (SelRow < ViewOffset)
                ViewOffset = SelRow;
            else if (SelRow >= ViewOffset + VisN)
                ViewOffset = SelRow - VisN + 1;
        }
        ViewOffset = Math::Clamp(ViewOffset, 0, Math::Max(0, Total - VisN));

        // ---- Render ----
        Panel.SetTextSize(TextSize);
        Panel.BeginUpdate();

        // Title.
        float ZL = TopZ;
        Panel.AddRow(f"FAMILIAR COMPENDIUM     Captured {CaughtCount} / {TotalCount}", FColor(255, 215, 120), LeftX, ZL);
        ZL -= LineH * 1.4;

        // Scrolled list body, with the selected row highlighted.
        const FColor HighlightColor = FColor(255, 240, 170);
        const int WindowEnd = Math::Min(ViewOffset + VisN, Total);
        for (int r = ViewOffset; r < WindowEnd; r++)
        {
            FString Text = BodyText[r];
            FColor Color = BodyColor[r];
            if (RowEntry[r] == Sel && Sel >= 0)
            {
                Text = "> " + Text;
                Color = HighlightColor;
            }
            Panel.AddRow(Text, Color, LeftX, ZL);
            ZL -= LineH;
        }

        // Footer.
        const int SelDisplay = (NumEntries > 0) ? (Sel + 1) : 0;
        Panel.AddRow(f"[Up/Down] Select   [P] Close      {SelDisplay} / {NumEntries}", FColor(210, 210, 210), LeftX, ZL - LineH * 0.4);

        // Detail pane (right column) for the selected familiar.
        RenderDetail(Sel, DetailX, DetailTopZ, LineH);

        Panel.EndUpdate();

        // Floating 3D model of the selected familiar.
        UpdateModel(Sel, ScreenW, ScreenH, PanelLoc, Forward);
    }

    // Lines of the right-hand detail pane for the selected entry.
    private void RenderDetail(int Sel, float DetailX, float TopZ, float LineH)
    {
        if (Sel < 0 || Sel >= EntryName.Num())
            return;

        const FString SpeciesName = EntryName[Sel];
        const FGameplayTag Element = EntryElement[Sel];
        const bool bCaught = EntryCaught[Sel];

        float Z = TopZ;
        Panel.AddRow("DETAILS", FColor(255, 215, 120), DetailX, Z);
        Z -= LineH * 1.3;

        Panel.AddRow(SpeciesName, FColor(245, 245, 245), DetailX, Z);
        Z -= LineH;

        Panel.AddRow(f"Element: {FamiliarDex::ElementLabel(Element)}", FamiliarDex::ElementColor(Element), DetailX, Z);
        Z -= LineH * 1.2;

        if (bCaught)
        {
            Panel.AddRow("Status: Captured", FColor(150, 230, 150), DetailX, Z);
            Z -= LineH;

            int Flags = 0;
            int Best = -1;
            const bool bHasForm = FormFlags.Find(SpeciesName, Flags);
            FormBestStar.Find(SpeciesName, Best);

            if (bHasForm)
            {
                FString StarStr = (Best > 0) ? f"{FamiliarDex::Stars(Best)} ({Best}-star)" : "Common (no stars)";
                Panel.AddRow(f"Best rarity: {StarStr}", FColor(255, 210, 90), DetailX, Z);
                Z -= LineH;
                Panel.AddRow(f"Forms owned: {FamiliarDex::VariantList(Flags)}", FColor(200, 220, 255), DetailX, Z);
                Z -= LineH;
            }
            else
            {
                Panel.AddRow("Form: not currently owned", FColor(165, 165, 170), DetailX, Z);
                Z -= LineH;
                Panel.AddRow("(summon/keep it to log its form)", FColor(140, 140, 145), DetailX, Z);
                Z -= LineH;
            }
        }
        else
        {
            Panel.AddRow("Status: Not captured", FColor(150, 150, 155), DetailX, Z);
            Z -= LineH;
            Panel.AddRow("Bond this familiar to log it.", FColor(140, 140, 145), DetailX, Z);
            Z -= LineH;
        }
    }

    // Float the selected familiar's item mesh to the right of the panel.
    private void UpdateModel(int Sel, float ScreenW, float ScreenH, const FVector& PanelLoc, const FVector& Forward)
    {
        if (Model == nullptr)
            return;
        if (!FamiliarDexConfig::bShowModel || Sel < 0 || Sel >= EntryTag.Num())
        {
            Model.HideModel();
            return;
        }

        UStaticMesh Mesh = MeshFromTag(EntryTag[Sel]);
        if (Mesh == nullptr)
        {
            Model.HideModel();
            return;
        }

        // Screen-right / screen-up world directions, derived from the camera forward
        // (avoids relying on FRotator's Right/Up accessors).
        const FVector Right = FVector::UpVector.CrossProduct(Forward).GetSafeNormal();
        const FVector Up = Forward.CrossProduct(Right).GetSafeNormal();

        const float Time = Game::GetWorldTimeSeconds();
        const float BobZ = Math::Sin(Time * FamiliarDexConfig::ModelBobSpeed) * FamiliarDexConfig::ModelBobAmplitude;

        const FVector Loc = PanelLoc
            + Right * (ScreenW * FamiliarDexConfig::ModelRightFracX)
            + Up * (ScreenH * FamiliarDexConfig::ModelUpFracY + BobZ)
            - Forward * FamiliarDexConfig::ModelDepthPull;

        Model.ConfigureMesh(Mesh, ScreenH * FamiliarDexConfig::ModelSizeFracH);
        Model.Show(Loc, Time * FamiliarDexConfig::ModelSpinDegPerSec);
    }

    // Borrow a static mesh from an item definition (LegendaryTracker's orb trick).
    private UStaticMesh MeshFromTag(const FGameplayTag& Tag)
    {
        if (!Tag.IsValid())
            return nullptr;
        const UItemDefinition Def = UItemSubsystem::GetItemDefinition(Tag);
        if (Def == nullptr || Def.ActorsToSpawn.IsEmpty())
            return nullptr;
        FItemActorToSpawn Spawn = Def.ActorsToSpawn[0];
        return Spawn.StaticMesh;
    }

    // First body row that maps to selectable entry `Entry` (or -1).
    private int RowForEntry(int Entry) const
    {
        if (Entry < 0)
            return -1;
        for (int r = 0; r < RowEntry.Num(); r++)
            if (RowEntry[r] == Entry)
                return r;
        return -1;
    }

    // Build the catchable-species roster. Walk the `Items` gameplay-tag tree to its
    // leaves and keep item definitions that carry a UItemFragment_Familiar, then
    // filter out the forms that aren't real catchable species (variants, named
    // bosses, cut content) -- see the rules in FamiliarDexConfig. Name-merging
    // happens later, in BuildDisplay, where the player's caught data is available.
    private void BuildRoster()
    {
        RosterTags.Reset();
        RosterNames.Reset();
        RosterElements.Reset();

        TArray<FGameplayTag> Leaves;
        TSet<FGameplayTag> Visited;
        GatherLeafTags(GameplayTags::Items, Leaves, Visited, 0);

        // Phase 1: collect every familiar candidate (tag + name + element + leaf).
        TArray<FGameplayTag> CandTags;
        TArray<FString> CandNames;
        TArray<FGameplayTag> CandElements;
        TArray<FString> CandLeaves;
        for (const FGameplayTag& Tag : Leaves)
        {
            const UItemDefinition Def = UItemSubsystem::GetItemDefinition(Tag);
            if (Def == nullptr)
                continue;

            const UItemFragment_Familiar FamiliarFrag = Def.GetFragment(UItemFragment_Familiar);
            if (FamiliarFrag == nullptr)
                continue;   // not a familiar item

            FString SpeciesName = Def.DisplayName.ToString();
            if (SpeciesName.IsEmpty())
                SpeciesName = FamiliarDex::Leaf(Tag);

            FGameplayTag Element;
            const UItemRuntimeFragment_FamiliarActions Actions = Def.GetRuntimeFragment(UItemRuntimeFragment_FamiliarActions);
            if (Actions != nullptr)
                Element = Actions.ProgressionElementalType;

            CandTags.Add(Tag);
            CandNames.Add(SpeciesName);
            CandElements.Add(Element);
            CandLeaves.Add(FamiliarDex::Leaf(Tag));
        }

        // Exclusion lists (built once).
        TArray<FString> Keywords;
        FamiliarDexConfig::GetExcludeKeywords(Keywords);
        TArray<FString> CutLeaves;
        FamiliarDexConfig::GetExcludeTagLeaves(CutLeaves);

        // Phase 2: keep the catchable base species; log what we drop and why.
        int Dropped = 0;
        for (int i = 0; i < CandTags.Num(); i++)
        {
            const FString Leaf = CandLeaves[i];
            FString Reason;

            if (IsExactMatch(Leaf, CutLeaves))
                Reason = "cut/mistagged";
            else if (FamiliarDexConfig::bDropTagVariants && IsTagVariant(Leaf, CandLeaves))
                Reason = "variant of base tag";
            else if (HasAnyKeyword(Leaf, Keywords))
                Reason = "named/variant keyword";

            if (!Reason.IsEmpty())
            {
                Dropped++;
                if (FamiliarDexConfig::bVerboseLog)
                    Log(n"FamiliarCompendium", f"  DROP {CandNames[i]}  [{CandTags[i].ToString()}]  ({Reason})");
                continue;
            }

            RosterTags.Add(CandTags[i]);
            RosterNames.Add(CandNames[i]);
            RosterElements.Add(CandElements[i]);
        }

        if (RosterTags.Num() > 0)
            bRosterBuilt = true;   // otherwise retry next open (items may load late)

        // Distinct display names = species shown after the name-merge in BuildDisplay.
        TSet<FString> DistinctNames;
        for (const FString& N : RosterNames)
            DistinctNames.Add(N);

        Log(n"FamiliarCompendium", f"Built roster: {DistinctNames.Num()} species ({RosterTags.Num()} forms kept, {Dropped} dropped) from {Leaves.Num()} item tags");
        if (FamiliarDexConfig::bVerboseLog)
        {
            for (int i = 0; i < RosterTags.Num(); i++)
                Log(n"FamiliarCompendium", f"  KEEP {RosterNames[i]}  [{RosterTags[i].ToString()}]  element={RosterElements[i].ToString()}");
        }
    }

    // True if Leaf exactly matches an entry in List. (Index loop, not ranged-for:
    // ranged-for over a const& parameter doesn't parse in this AngelScript.)
    private bool IsExactMatch(const FString& Leaf, const TArray<FString>& List) const
    {
        for (int i = 0; i < List.Num(); i++)
            if (Leaf == List[i])
                return true;
        return false;
    }

    // True if Leaf contains any keyword (FString::Contains is case-insensitive).
    private bool HasAnyKeyword(const FString& Leaf, const TArray<FString>& Keys) const
    {
        for (int i = 0; i < Keys.Num(); i++)
            if (Leaf.Contains(Keys[i]))
                return true;
        return false;
    }

    // True if Leaf is "<some other familiar's leaf> + suffix", i.e. a variant whose
    // tag extends a shorter base familiar tag (e.g. FamiliarLoijaCrystal / FamiliarLoija).
    private bool IsTagVariant(const FString& Leaf, const TArray<FString>& AllLeaves) const
    {
        for (int i = 0; i < AllLeaves.Num(); i++)
        {
            const FString Base = AllLeaves[i];
            if (Base != Leaf && Base.Len() < Leaf.Len() && Leaf.StartsWith(Base))
                return true;
        }
        return false;
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

    // Pre-render the grouped body lines (element header + caught/uncaught rows) and
    // build the parallel selectable-entry list the cursor + detail pane use.
    private void BuildDisplay(APlayerCharacter Player)
    {
        BodyText.Reset();
        BodyColor.Reset();
        RowEntry.Reset();
        EntryName.Reset();
        EntryElement.Reset();
        EntryCaught.Reset();
        EntryTag.Reset();
        CaughtCount = 0;
        TotalCount = 0;

        // Read the forms of the familiars we currently own into the session memory.
        GatherOwnedForms(Player);

        UPlayerStatisticsComponent Stats = UPlayerStatisticsComponent::Get(Player);

        // Merge forms that share a display name into a single species (caught if ANY
        // form is known). With bMergeByDisplayName off, this is one row per form.
        TArray<FString> MNames;
        TArray<FGameplayTag> MElements;
        TArray<FGameplayTag> MTags;
        TArray<bool> MCaught;
        TMap<FString, int> NameToIndex;
        for (int i = 0; i < RosterTags.Num(); i++)
        {
            const bool bKnown = (Stats != nullptr) && Stats.IsItemKnown(RosterTags[i]);
            const FString SpeciesName = RosterNames[i];   // 'Name' shadows UObject's GetName accessor

            int Existing = -1;
            if (FamiliarDexConfig::bMergeByDisplayName && NameToIndex.Find(SpeciesName, Existing))
            {
                if (bKnown)
                    MCaught[Existing] = true;
                continue;
            }

            if (FamiliarDexConfig::bMergeByDisplayName)
                NameToIndex.Add(SpeciesName, MNames.Num());
            MNames.Add(SpeciesName);
            MElements.Add(RosterElements[i]);
            MTags.Add(RosterTags[i]);
            MCaught.Add(bKnown);
        }

        // Unique elements, in first-appearance order.
        TArray<FGameplayTag> Elements;
        for (const FGameplayTag& E : MElements)
        {
            bool Found = false;
            for (const FGameplayTag& X : Elements)
            {
                if (X == E) { Found = true; break; }
            }
            if (!Found)
                Elements.Add(E);
        }

        const FColor CaughtColor = FColor(245, 245, 245);
        const FColor UncaughtColor = FColor(120, 120, 125);   // greyed name

        for (const FGameplayTag& E : Elements)
        {
            // Split this element's species into caught / uncaught.
            TArray<int> Caught;
            TArray<int> Uncaught;
            for (int i = 0; i < MNames.Num(); i++)
            {
                if (MElements[i] != E)
                    continue;
                if (MCaught[i])
                    Caught.Add(i);
                else
                    Uncaught.Add(i);
            }

            const int GroupTotal = Caught.Num() + Uncaught.Num();
            CaughtCount += Caught.Num();
            TotalCount += GroupTotal;

            // Blank spacer between groups (empty text renders nothing).
            if (BodyText.Num() > 0)
            {
                BodyText.Add("");
                BodyColor.Add(FColor::Black);
                RowEntry.Add(-1);
            }

            // Element header, e.g. "Fire   3/5".
            BodyText.Add(f"{FamiliarDex::ElementLabel(E)}   {Caught.Num()}/{GroupTotal}");
            BodyColor.Add(FamiliarDex::ElementColor(E));
            RowEntry.Add(-1);

            for (int c = 0; c < Caught.Num(); c++)
            {
                const int Idx = Caught[c];
                const int Entry = AddEntry(MNames[Idx], MElements[Idx], true, MTags[Idx]);

                // Inline form badge: best stars + C/S marks, if we have form data.
                int Flags = 0;
                int Best = -1;
                FString Badge;
                if (FormFlags.Find(MNames[Idx], Flags))
                {
                    FormBestStar.Find(MNames[Idx], Best);
                    const FString StarStr = (Best > 0) ? FamiliarDex::Stars(Best) : "";
                    const FString Marks = FamiliarDex::VariantMarks(Flags);
                    if (!StarStr.IsEmpty() || !Marks.IsEmpty())
                        Badge = "  " + StarStr + Marks;
                }

                BodyText.Add(f"  [x] {MNames[Idx]}{Badge}");
                BodyColor.Add(CaughtColor);
                RowEntry.Add(Entry);
            }
            for (int u = 0; u < Uncaught.Num(); u++)
            {
                const int Idx = Uncaught[u];
                const int Entry = AddEntry(MNames[Idx], MElements[Idx], false, MTags[Idx]);
                BodyText.Add(f"  [ ] {MNames[Idx]}");
                BodyColor.Add(UncaughtColor);
                RowEntry.Add(Entry);
            }
        }

        if (BodyText.Num() == 0)
        {
            BodyText.Add("No familiar species found - check Hercules.log");
            BodyColor.Add(FColor(255, 120, 120));
            RowEntry.Add(-1);
        }
    }

    private int AddEntry(const FString& SpeciesName, const FGameplayTag& Element, bool bCaught, const FGameplayTag& Tag)
    {
        const int Index = EntryName.Num();
        EntryName.Add(SpeciesName);
        EntryElement.Add(Element);
        EntryCaught.Add(bCaught);
        EntryTag.Add(Tag);
        return Index;
    }

    // Scan everything the player currently owns and record the best form seen per
    // species: the bonded familiar item stacks (active familiar inventory + bag) and
    // any summoned familiar NPCs. Accumulates across opens this session.
    private void GatherOwnedForms(APlayerCharacter Player)
    {
        if (Player == nullptr)
            return;

        GatherFromInventory(Player.FamiliarInventoryComp);
        GatherFromInventory(Player.InventoryComp);

        // Summoned / live familiars owned by the local player.
        TArray<ANPCBase> NPCs;
        GetAllActorsOfClass(NPCs);
        for (ANPCBase NPC : NPCs)
        {
            if (NPC == nullptr || !IsValid(NPC))
                continue;
            UFamiliarComponent Fam = NPC.FamiliarComp;
            if (Fam == nullptr || !Fam.ItemTag.IsValid())
                continue;
            if (Cast<APlayerCharacter>(Fam.GetFamiliarOwner()) != Player)
                continue;
            RecordForm(SpeciesNameForTag(Fam.ItemTag), int(Fam.Rarity), Fam.IsCelestial(), Fam.IsShifty());
        }
    }

    private void GatherFromInventory(UInventoryComponent Inv)
    {
        if (Inv == nullptr)
            return;
        for (UItemStack Stack : Inv.AllItemStacks)
        {
            if (Stack == nullptr || Stack.StackSize <= 0)
                continue;
            const UItemDefinition Def = Stack.GetItemDefinition();
            if (Def == nullptr || Def.GetFragment(UItemFragment_Familiar) == nullptr)
                continue;

            FString SpeciesName = Def.DisplayName.ToString();
            if (SpeciesName.IsEmpty())
                SpeciesName = FamiliarDex::Leaf(Stack.GetItemTag());

            int Star = 0;
            const UItemRuntimeFragment_Rarity Rarity = Stack.GetRuntimeFragment(UItemRuntimeFragment_Rarity);
            if (Rarity != nullptr)
                Star = int(Rarity.GetRarity());

            bool bCel = false;
            bool bShi = false;
            const UItemRuntimeFragment_FamiliarInfo Info = Stack.GetRuntimeFragment(UItemRuntimeFragment_FamiliarInfo);
            if (Info != nullptr)
            {
                const EFamiliarVisualVariant V = Info.VisualVariant;
                bCel = (V == EFamiliarVisualVariant::Celestial || V == EFamiliarVisualVariant::ShiftyCelestial);
                bShi = (V == EFamiliarVisualVariant::Shifty || V == EFamiliarVisualVariant::ShiftyCelestial);
            }

            RecordForm(SpeciesName, Star, bCel, bShi);
        }
    }

    // Merge one observed form into the session memory for `SpeciesName`.
    private void RecordForm(const FString& SpeciesName, int Star, bool bCelestial, bool bShifty)
    {
        if (SpeciesName.IsEmpty())
            return;

        int Bit = FamiliarDex::FormNormal;
        if (bCelestial && bShifty) Bit = FamiliarDex::FormBoth;
        else if (bCelestial)       Bit = FamiliarDex::FormCelestial;
        else if (bShifty)          Bit = FamiliarDex::FormShifty;

        int Flags = 0;
        FormFlags.Find(SpeciesName, Flags);
        FormFlags.Add(SpeciesName, Flags | Bit);

        int Best = -1;
        FormBestStar.Find(SpeciesName, Best);
        FormBestStar.Add(SpeciesName, Math::Max(Best, Star));
    }

    private FString SpeciesNameForTag(const FGameplayTag& Tag)
    {
        const UItemDefinition Def = UItemSubsystem::GetItemDefinition(Tag);
        if (Def != nullptr)
        {
            const FString N = Def.DisplayName.ToString();
            if (!N.IsEmpty())
                return N;
        }
        return FamiliarDex::Leaf(Tag);
    }

    private void EnsurePanel()
    {
        if (Panel == nullptr || !IsValid(Panel))
            Panel = Cast<AFamiliarDexPanel>(SpawnActor(AFamiliarDexPanel));
    }

    private void EnsureModel()
    {
        if (!FamiliarDexConfig::bShowModel)
            return;
        if (Model == nullptr || !IsValid(Model))
            Model = Cast<AFamiliarDexModel>(SpawnActor(AFamiliarDexModel));
    }

    private void EnsureInput()
    {
        if (Input == nullptr || !IsValid(Input))
            Input = Cast<AFamiliarDexInput>(SpawnActor(AFamiliarDexInput));
    }

    // Tear down every open-state visual + restore the player. Called on close and
    // whenever the player/controller goes away.
    private void CloseVisuals(APlayerCharacter Player, APlayerController Controller)
    {
        HidePanel();
        if (Model != nullptr && IsValid(Model))
            Model.HideModel();
        Unfreeze(Player);
        ShowHud();
        DisableBackdrop(Controller);
        bPrevOpen = false;
    }

    private void HidePanel()
    {
        if (Panel != nullptr && IsValid(Panel))
            Panel.HidePanel();
    }

    // Freeze the player (movement + camera) the game's own way; our hotkeys live on
    // a separate input component, so they keep working.
    private void Freeze(APlayerCharacter Player)
    {
        if (bFrozen || Player == nullptr || !IsValid(Player))
            return;
        Player.DisableInput();
        bFrozen = true;
    }

    private void Unfreeze(APlayerCharacter Player)
    {
        if (!bFrozen)
            return;
        if (Player != nullptr && IsValid(Player))
            Player.EnableInput();
        bFrozen = false;
    }

    // Hide / restore the game HUD the same way the game's own ToggleVisiblity does.
    private void HideHud()
    {
        if (bHudHidden)
            return;
        AHercHUD Hud = Cast<AHercHUD>(Game::GetHUD());
        if (Hud == nullptr)
            return;
        Hud.SetVisibility(false);
        bHudHidden = true;
    }

    private void ShowHud()
    {
        if (!bHudHidden)
            return;
        AHercHUD Hud = Cast<AHercHUD>(Game::GetHUD());
        if (Hud != nullptr)
            Hud.SetVisibility(true);
        bHudHidden = false;
    }

    // Turn on the background effect: a depth-of-field post-process (world blurs,
    // panel text stays sharp because it sits at the focal distance) plus a held
    // manual camera fade (dim). Safe to call every frame -- the DoF component is
    // created once, the dim fade is re-asserted so it can't be silently cleared.
    // Mirrors PlayerSingularityPullAbility's UPostProcessComponent usage.
    private void EnableBackdrop(APlayerCharacter Player, APlayerController Controller)
    {
        if (FamiliarDexConfig::bBlurBackgroundWhileOpen && Backdrop == nullptr
            && Player != nullptr && IsValid(Player))
        {
            Backdrop = UPostProcessComponent::Create(Player);
            if (Backdrop != nullptr)
            {
                // Focal plane at the panel depth -> the world behind blurs while the
                // text (on the focal plane) stays crisp. Fstop drives blur strength;
                // MinFstop is lowered to match so Fstop isn't clamped upward.
                Backdrop.Settings.bOverride_DepthOfFieldFocalDistance = true;
                Backdrop.Settings.DepthOfFieldFocalDistance = FamiliarDexConfig::BlurFocalDistance;
                Backdrop.Settings.bOverride_DepthOfFieldFstop = true;
                Backdrop.Settings.DepthOfFieldFstop = FamiliarDexConfig::BlurFstop;
                Backdrop.Settings.bOverride_DepthOfFieldMinFstop = true;
                Backdrop.Settings.DepthOfFieldMinFstop = FamiliarDexConfig::BlurFstop;
            }
        }

        if (FamiliarDexConfig::bDimBackgroundWhileOpen
            && Controller != nullptr && Controller.PlayerCameraManager != nullptr)
            Controller.PlayerCameraManager.SetManualCameraFade(FamiliarDexConfig::DimAmount, FamiliarDexConfig::DimColor, false);

        bBackdropActive = true;
    }

    private void DisableBackdrop(APlayerController Controller)
    {
        if (!bBackdropActive)
            return;

        if (Backdrop != nullptr && IsValid(Backdrop))
        {
            Backdrop.RemoveFromRoot();
            Backdrop.DestroyComponent();
        }
        Backdrop = nullptr;

        if (Controller != nullptr && Controller.PlayerCameraManager != nullptr)
            Controller.PlayerCameraManager.StopCameraFade();

        bBackdropActive = false;
    }

    // World point where the ray through screen pixel (PX, PY) crosses the plane that
    // sits Dist cm in front of the camera along Forward.
    private FVector ScreenToPanelPlane(APlayerController PC, const FVector& CamLoc, const FVector& Forward, float Dist, float PX, float PY)
    {
        FVector RayLoc;
        FVector RayDir;
        PC.DeprojectScreenPositionToWorld(PX, PY, RayLoc, RayDir);
        const float Denom = RayDir.DotProduct(Forward);
        if (Math::Abs(Denom) < 0.0001)
            return CamLoc + Forward * Dist;
        const float T = (Dist - (RayLoc - CamLoc).DotProduct(Forward)) / Denom;
        return RayLoc + RayDir * T;
    }
}
