local Config = {
    BackgroundImage = "", -- Optional: rbxassetid://<your permitted image asset>
    EnableDataStore = false,
    DataStoreName = "LuffyAimRainbowPrefs_v1",
    DefaultWalkSpeed = 16,
    MinWalkSpeed = 8,
    MaxWalkSpeed = 32,
    DefaultFlySpeed = 42,
    MaxPracticeDistance = 140,
    AimRequestInterval = 0.12,
    PickupValue = 10,
    PickupSpawnOffset = Vector3.new(0, 3, -8),
    MaxOutlineScale = 3,
    TargetCount = 6,
    DemoInventory = { "Training Token", "Ice Fruit (Demo)", "Hot Fruit (Demo)" },
    Defaults = {
        WalkSpeed = 16,
        FlyEnabled = false,
        HitboxEnabled = false,
        HitboxScale = 1,
        AutoCollect = false,
        Rainbow = true,
        UiScale = 1,
    },
}
return Config
