// =============================================================================
//  Quick Deposit  —  base-wide quick-deposit hotkey
//
//  Press the hotkey while standing in your base to sweep your backpack into the
//  base's chests: every item you're carrying that a chest ALREADY stores gets
//  sent to that chest. Items the base doesn't already have stay in your bag, and
//  toolbar (hotbar) items are never deposited. A cyan beam arcs from you to each
//  chest as the items land (the crafting resource-pull effect, in reverse).
//
//  How it works:
//    - Hearth::IsLocationInHearth(player)  -> gates it to "at base" only.
//    - AHearthManager.GetInventories()     -> every base storage inventory.
//    - For items a chest already stocks, deposit into that chest: fill its
//      existing stacks first, then create a new stack if it has a free slot, so
//      a chest full of capped stacks still accepts more. Respects each item's
//      max stack size (with StackBoost that cap is 1000, which is expected).
//
//  Default hotkey: H  (set HotkeyKey in the QuickDepositConfig namespace).
//
//  NOTE: built for single-player / listen-server (the base inventory list is
//  server-side). Reads/writes happen locally; no save tampering.
// =============================================================================


namespace QuickDepositConfig
{
    // The hotkey that deposits your similar items into base chests.
    // Set it to any key, e.g. EKeys::G, EKeys::V, EKeys::B, EKeys::T, EKeys::X ...
    const FKey HotkeyKey = EKeys::H;

    // The "items flying to the chest" beam (reuses the crafting resource-pull VFX).
    const bool bShowDepositBeam = true;

    // Seconds the beam lingers before it's cleaned up.
    const float BeamLifetime = 1.0;
}


// -----------------------------------------------------------------------------
//  Input receiver: a tiny actor that pushes an input component onto the local
//  player's controller and binds the hotkey (BindKey does NOT consume input, so
//  it plays nicely with the game's own bindings).
// -----------------------------------------------------------------------------
UCLASS(NotPlaceable, HideCategories = "Actor Tick Rendering Replication Collision Input")
class AQuickDepositInput : AActor
{
    default bReplicates = false;

    // Trivial root (a UInputComponent can't be the actor root; it's not a scene component).
    UPROPERTY(DefaultComponent, RootComponent)
    USceneComponent Root;

    UPROPERTY(DefaultComponent)
    UInputComponent InputComp;

    // Deposit-beam VFX state.
    private UNiagaraSystem CachedBeamEffect;
    private bool bSearchedBeamEffect = false;
    private TArray<UNiagaraComponent> ActiveBeams;

    UFUNCTION(BlueprintOverride)
    void BeginPlay()
    {
        APlayerController Controller = Game::GetLocalPlayerController();
        if (Controller == nullptr)
            return;

        Controller.PushInputComponent(InputComp);

        // --- The hotkey (set it in QuickDepositConfig::HotkeyKey). ---
        InputComp.BindKey(QuickDepositConfig::HotkeyKey, EInputEvent::IE_Pressed, FInputActionHandlerDynamicSignature(this, n"OnHotkeyPressed"));
    }

    UFUNCTION()
    private void OnHotkeyPressed(FKey Key)
    {
        QuickDepositAtBase();
    }

    private void QuickDepositAtBase()
    {
        APlayerCharacter Player = Game::GetLocalPlayer();
        if (Player == nullptr || Player.InventoryComp == nullptr)
            return;

        // Gate: only while standing in the base (inside a hearth's range).
        if (!Hearth::IsLocationInHearth(Player.GetActorLocation()))
        {
            Log(n"QuickDeposit", "Not at base - ignoring hotkey.");
            return;
        }

        AHearthManager HearthManager = AGameManager::Get(AHearthManager);
        if (HearthManager == nullptr)
            return;

        // Snapshot the bag, skipping the toolbar/hotbar so quick-slot tools and
        // weapons are never deposited. Hotbar items occupy the first
        // GetSlotCount() slots (see InventoryComponent::SmartTransferItemStack).
        const int HotbarSlots = (Player.HotbarComp != nullptr ? Player.HotbarComp.GetSlotCount() : 0);

        TArray<UItemStack> DepositStacks;
        for (UItemStack Stack : Player.InventoryComp.AllItemStacks)
        {
            if (Stack == nullptr || Stack.StackSize <= 0)
                continue;
            if (Stack.GetSlot() < HotbarSlots)   // toolbar item -> leave it alone
                continue;
            DepositStacks.Add(Stack);
        }

        // Fresh beams for this press.
        ClearDepositBeams();
        const FVector BeamStart = Player.GetActorLocation() + FVector::UpVector * 60.0;

        int TotalDeposited = 0;
        for (const FHearthInventory& Entry : HearthManager.GetInventories())
        {
            UInventoryComponent ChestInv = Entry.Component;
            if (ChestInv == nullptr || ChestInv == Player.InventoryComp)
                continue;

            const int ChestBefore = SumStacks(DepositStacks);

            for (UItemStack Stack : DepositStacks)
            {
                if (Stack == nullptr || Stack.StackSize <= 0)
                    continue;

                // Only into chests that ALREADY stock this item ("similar"). Fills
                // existing stacks first, then creates a new stack if the chest has
                // a free slot -- so a chest full of capped stacks still accepts more.
                if (ChestInv.GetTotalItemCountByTag(Stack.GetItemTag()) > 0)
                    ChestInv.SmartTransferItemStack(Stack, EItemEventFlags::None);
            }

            const int ChestDeposited = ChestBefore - SumStacks(DepositStacks);
            if (ChestDeposited > 0)
            {
                TotalDeposited += ChestDeposited;
                if (QuickDepositConfig::bShowDepositBeam)
                    SpawnDepositBeam(ChestInv, BeamStart);   // beam: player -> this chest
            }
        }

        if (ActiveBeams.Num() > 0)
            System::SetTimer(this, n"ClearDepositBeams", QuickDepositConfig::BeamLifetime, false);

        Log(n"QuickDeposit", f"Deposited {TotalDeposited} item(s) into base chests.");
    }

    private int SumStacks(const TArray<UItemStack>& Stacks) const
    {
        int Total = 0;
        for (UItemStack Stack : Stacks)
        {
            if (Stack != nullptr)
                Total += Stack.StackSize;
        }
        return Total;
    }

    // Reuses the crafting "resource pull" beam (StationConnectionVisualEffect, off
    // any crafting station) drawn from the player to the chest -- the crafting
    // effect in reverse. Found once and cached; null if no station has one.
    private UNiagaraSystem GetBeamEffect()
    {
        if (bSearchedBeamEffect)
            return CachedBeamEffect;
        bSearchedBeamEffect = true;

        TArray<AWorkstation> Workstations;
        GetAllActorsOfClass(Workstations);
        for (AWorkstation Workstation : Workstations)
        {
            if (Workstation == nullptr || Workstation.CraftingComp == nullptr)
                continue;
            if (Workstation.CraftingComp.StationConnectionVisualEffect != nullptr)
            {
                CachedBeamEffect = Workstation.CraftingComp.StationConnectionVisualEffect;
                break;
            }
        }
        return CachedBeamEffect;
    }

    private void SpawnDepositBeam(UInventoryComponent ChestInv, const FVector& StartLocation)
    {
        UNiagaraSystem Effect = GetBeamEffect();
        if (Effect == nullptr || ChestInv == nullptr)
            return;

        AActor ChestActor = ChestInv.GetOwner();
        if (ChestActor == nullptr)
            return;

        // Chests expose a "BuildingConnectionSocket" -- the same anchor the crafting
        // beam uses (see CraftingComponent::SpawnInventoryBeingUsedEffect).
        USceneComponent Socket = USceneComponent::Get(ChestActor, n"BuildingConnectionSocket");
        const FVector EndLocation = (Socket != nullptr ? Socket.WorldLocation : ChestActor.GetActorLocation());

        UNiagaraComponent Beam = Niagara::SpawnSystemAtLocation(Effect, StartLocation);
        if (Beam == nullptr)
            return;

        Beam.SetVectorParameter(n"EndPos", EndLocation);
        ActiveBeams.Add(Beam);
    }

    UFUNCTION()
    private void ClearDepositBeams()
    {
        for (UNiagaraComponent Beam : ActiveBeams)
        {
            if (Beam != nullptr)
                Beam.DestroyComponent(Beam.Owner);
        }
        ActiveBeams.Reset();
    }
}

// -----------------------------------------------------------------------------
//  Bootstrapper: auto-created per game world; spawns the input actor once the
//  local player controller exists.
// -----------------------------------------------------------------------------
class UQuickDepositSubsystem : UScriptWorldSubsystem
{
    private AQuickDepositInput InputActor;

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
        // Already set up.
        if (InputActor != nullptr && IsValid(InputActor))
            return;

        // Wait until the local player controller exists, then bind once.
        if (Game::GetLocalPlayerController() == nullptr)
            return;

        InputActor = Cast<AQuickDepositInput>(SpawnActor(AQuickDepositInput));
    }
}
