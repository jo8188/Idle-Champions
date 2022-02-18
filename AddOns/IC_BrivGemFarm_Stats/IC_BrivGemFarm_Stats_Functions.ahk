class IC_BrivGemFarm_Stats_Component
{
    doesExist := true
    StatsTabFunctions := {}
    isLoaded := false

    ; Update Tab Stats Variables
    TotalRunCount := 0
    FailedStacking := 0
    FailedStackConv := 0
    SlowRunTime := 0
    FastRunTime := 0
    ScriptStartTime := 0
    CoreXPStart := 0
    GemStart := 0
    GemSpentStart := 0
    BossesPerHour := 0
    LastResetCount := 0
    RunStartTime := A_TickCount
    IsStarted := false ; Skip recording of first run
    StackFail := ""
    SilverChestCountStart := 0
    GoldChestCountStart := 0
    LastTriggerStart := false
    ActiveGameInstance := 1
    FailRunTime := 0
    TotalRunCountRetry := 0

    
    SharedRunData[]
    {
        get 
        {
            try
            {
                return ComObjActive("{416ABC15-9EFC-400C-8123-D7D8778A2103}")
            }
            catch, Err
            {
                return new IC_SharedData_Class
            }
        }
    }


    BuildToolTips()
    {
        StackFailToolTip := "
        (
            StackFail Types:
            1.  Ran out of stacks when ( > min stack zone AND < target stack zone). only reported when fail recovery is on
                Will stack farm - only a warning. Configuration likely incorrect
            2.  Failed stack conversion (Haste <= 50, SB > target stacks). Forced Reset
            3.  Game was stuck (checkifstuck), forced reset
            4.  Ran out of haste and steelbones > target, forced reset
            5.  Failed stack conversion, all stacks lost.
            6.  Modron not resetting, forced reset
        )"
        GUIFunctions.AddToolTip("FailedStackingID", StackFailToolTip)
    }

    AddStatsTabMod(FunctionName, Object := "")
    {
        if(Object != "")
        {
            functionToPush := ObjBindMethod(%Object%, FunctionName)
        }
        else
        {
            functionToPush := Func(FunctionName)
        }
        if(this.StatsTabFunctions == "")
            this.StatsTabFunctions := {}
        this.StatsTabFunctions.Push(functionToPush)
    }

    UpdateStatsTabWithMods()
    {
        for k,v in this.StatsTabFunctions
        {
            v.Call()
        }
        this.StatsTabFunctions := {}
    }
    
    ;Updates GUI dtCurrentRunTimeID and dtCurrentLevelTimeID
    UpdateStatTimers()
    {
        static startTime := A_TickCount
        static previousZoneStartTime := A_TickCount
        static previousLoopStartTime := A_TickCount
        static lastZone := -1
        static lastResetCount := 0
        static sbStackMessage := ""
        static hasteStackMessage := ""
        static LastTriggerStart := false

        TriggerStart := IsObject(this.SharedRunData) ? this.SharedRunData.TriggerStart : LastTriggerStart
        Critical, On
        currentZone := g_SF.Memory.ReadCurrentZone()
        if ( g_SF.Memory.ReadResetsCount() > lastResetCount OR (g_SF.Memory.ReadResetsCount() == 0 AND g_SF.Memory.ReadAreaActive() AND lastResetCount != 0 ) OR (TriggerStart AND LastTriggerStart != TriggerStart)) ; Modron or Manual reset happend
        {
            lastResetCount := g_SF.Memory.ReadResetsCount()
            previousLoopStartTime := A_TickCount
        }

        if !g_SF.Memory.ReadUserIsInited()
        {
            ; do not update lastZone if game is loading
        }
        else if ( (currentZone > lastZone) AND (currentZone >= 2)) ; zone reset
        {
            lastZone := currentZone
            previousZoneStartTime := A_TickCount
        }
        else if ((g_SF.Memory.ReadHighestZone() < 3) AND (lastZone >= 3) AND (currentZone > 0) ) ; After reset. +1 buffer for time to read value
        {
            lastZone := currentZone
            previousLoopStartTime := A_TickCount
        }

        sbStacks := g_SF.Memory.ReadSBStacks()
        if (sbStacks == "")
        {
            if (SubStr(sbStackMessage, 1, 1) != "[")
            {
                sbStackMessage := "[" . sbStackMessage . "] last seen"
            }
        } else {
            sbStackMessage := sbStacks
        }
        hasteStacks := g_SF.Memory.ReadHasteStacks()
        if (hasteStacks == "")
        {
            if (SubStr(hasteStackMessage, 1, 1) != "[")
            {
                hasteStackMessage := "[" . hasteStackMessage . "] last seen"
            }
        } else {
            hasteStackMessage := hasteStacks
        }
        GuiControl, ICScriptHub:, g_StackCountSBID, % sbStackMessage
        GuiControl, ICScriptHub:, g_StackCountHID, % hasteStackMessage

        dtCurrentRunTime := Round( ( A_TickCount - previousLoopStartTime ) / 60000, 2 )
        GuiControl, ICScriptHub:, dtCurrentRunTimeID, % dtCurrentRunTime

        dtCurrentLevelTime := Round( ( A_TickCount - previousZoneStartTime ) / 1000, 2 )
        GuiControl, ICScriptHub:, dtCurrentLevelTimeID, % dtCurrentLevelTime
        Critical, Off
    }

    ;Updates the stats tab's once per run stats
    UpdateStartLoopStats()
    {
        Critical, On
        if !this.isStarted
        {
            this.LastResetCount := g_SF.Memory.ReadResetsCount()
            this.isStarted := true
        }

        ;testReadAreaActive := g_SF.Memory.ReadAreaActive()
        this.StackFail := Max(this.StackFail, this.SharedRunData.StackFail)
        this.TriggerStart := IsObject(this.SharedRunData) ? this.SharedRunData.TriggerStart : this.LastTriggerStart
        if ( g_SF.Memory.ReadResetsCount() > this.LastResetCount OR (g_SF.Memory.ReadResetsCount() == 0 AND g_SF.Memory.ReadOfflineDone() AND this.LastResetCount != 0 ) OR (this.TriggerStart AND this.LastTriggerStart != this.TriggerStart) )
        {
            while(!g_SF.Memory.ReadOfflineDone() AND IsObject(this.SharedRunData) AND this.SharedRunData.TriggerStart)
            {
                Critical, Off
                Sleep, 50
                Critical, On
            }
            ; CoreXP starting on FRESH run.
            if(!this.TotalRunCount OR (this.TotalRunCount AND this.TotalRunCountRetry < 2 AND (!this.CoreXPStart OR !this.GemStart)))
            {
                if(this.TotalRunCount)
                    this.TotalRunCountRetry++
                this.ActiveGameInstance := g_SF.Memory.ReadActiveGameInstance()
                this.CoreXPStart := g_SF.Memory.GetCoreXPByInstance(this.ActiveGameInstance)
                this.GemStart := g_SF.Memory.ReadGems()
                this.GemSpentStart := g_SF.Memory.ReadGemsSpent()
                this.LastResetCount := g_SF.Memory.ReadResetsCount()
                this.SilverChestCountStart := g_SF.Memory.GetChestCountByID(1)
                this.GoldChestCountStart := g_SF.Memory.GetChestCountByID(2)
                
                ; start count after first run since total chest count is counted after first run
                if(IsObject(this.SharedRunData)) 
                {
                    this.SharedRunData.PurchasedGoldChests := 0
                    this.SharedRunData.PurchasedSilverChests := 0    
                }
                
                this.FastRunTime := 1000
                this.ScriptStartTime := A_TickCount
            }
            if(IsObject(IC_InventoryView_Component) AND g_InventoryView != "") ; If InventoryView AddOn is available
            {
                InventoryViewRead := ObjBindMethod(g_InventoryView, "ReadInventory")
                InventoryViewRead.Call(this.TotalRunCount)
            }
            this.LastResetCount := g_SF.Memory.ReadResetsCount()
            this.PreviousRunTime := round( ( A_TickCount - RunStartTime ) / 60000, 2 )
            GuiControl, ICScriptHub:, PrevRunTimeID, % this.PreviousRunTime

            if (this.TotalRunCount AND (!this.StackFail OR this.StackFail == 6))
            {
                if (this.SlowRunTime < this.PreviousRunTime)
                    GuiControl, ICScriptHub:, SlowRunTimeID, % this.SlowRunTime := this.PreviousRunTime
                if (this.FastRunTime > this.PreviousRunTime)
                    GuiControl, ICScriptHub:, FastRunTimeID, % this.FastRunTime := this.PreviousRunTime
            }
            if ( this.StackFail ) ; 1 = Did not make it to Stack Zone. 2 = Stacks did not convert. 3 = Game got stuck in adventure and restarted.
            {
                GuiControl, ICScriptHub:, FailRunTimeID, % this.PreviousRunTime
                this.FailRunTime += this.PreviousRunTime
                GuiControl, ICScriptHub:, TotalFailRunTimeID, % round( this.FailRunTime, 2 )
                GuiControl, ICScriptHub:, FailedStackingID, % ArrFnc.GetDecFormattedArrayString(this.SharedRunData.StackFailStats.TALLY)
            }

            GuiControl, ICScriptHub:, TotalRunCountID, % this.TotalRunCount
            dtTotalTime := (A_TickCount - this.ScriptStartTime) / 3600000
            GuiControl, ICScriptHub:, dtTotalTimeID, % Round( dtTotalTime, 2 )
            GuiControl, ICScriptHub:, AvgRunTimeID, % Round( ( dtTotalTime / this.TotalRunCount ) * 60, 2 )

            currentCoreXP := g_SF.Memory.GetCoreXPByInstance(this.ActiveGameInstance)
            if(currentCoreXP)
                this.BossesPerHour := Round( ( ( currentCoreXP - this.CoreXPStart ) / 5 ) / dtTotalTime, 2 )
            GuiControl, ICScriptHub:, bossesPhrID, % this.BossesPerHour

            this.GemsTotal := ( g_SF.Memory.ReadGems() - this.GemStart ) + ( g_SF.Memory.ReadGemsSpent() - this.GemSpentStart )
            GuiControl, ICScriptHub:, GemsTotalID, % this.GemsTotal
            GuiControl, ICScriptHub:, GemsPhrID, % Round( this.GemsTotal / dtTotalTime, 2 )

            if (IsObject(this.SharedRunData))
            {
                GuiControl, ICScriptHub:, SilversPurchasedID, % g_SF.Memory.GetChestCountByID(1) - SilverChestCountStart + (IsObject(this.SharedRunData) ? this.SharedRunData.PurchasedSilverChests : SilversPurchasedID)
                GuiControl, ICScriptHub:, GoldsPurchasedID, % g_SF.Memory.GetChestCountByID(2) - GoldChestCountStart + (IsObject(this.SharedRunData) ? this.SharedRunData.PurchasedGoldChests : GoldsPurchasedID)
                GuiControl, ICScriptHub:, SilversOpenedID, % (IsObject(this.SharedRunData) ? this.SharedRunData.OpenedSilverChests : SilversOpenedID)
                GuiControl, ICScriptHub:, GoldsOpenedID, % (IsObject(this.SharedRunData) ? this.SharedRunData.OpenedGoldChests : GoldsOpenedID)
                GuiControl, ICScriptHub:, ShiniesID, % (IsObject(this.SharedRunData) ? this.SharedRunData.ShinyCount : ShiniesID)
            }
            ++this.TotalRunCount
            this.StackFail := 0
            this.SharedRunData.StackFail := false
            this.SharedRunData.TriggerStart := false
            this.RunStartTime := A_TickCount
        }
        if (IsObject(this.SharedRunData))
            this.LastTriggerStart := this.SharedRunData.TriggerStart
        Critical, Off
    }

    UpdateGUIFromCom()
    {
        static SharedRunData
        ;activeObjects := GetActiveObjects()
        try ; avoid thrown errors when comobject is not available.
        {
            SharedRunData := ComObjActive("{416ABC15-9EFC-400C-8123-D7D8778A2103}")
            if(!g_isDarkMode)
                GuiControl, ICScriptHub: +cBlack, LoopID, 
            else
                GuiControl, ICScriptHub: +cSilver, LoopID, 
            GuiControl, ICScriptHub:, LoopID, % SharedRunData.LoopString
            GuiControl, ICScriptHub:, SwapsMadeThisRunID, % SharedRunData.SwapsMadeThisRun
            GuiControl, ICScriptHub:, BossesHitThisRunID, % SharedRunData.BossesHitThisRun
            GuiControl, ICScriptHub:, TotalBossesHitID, % SharedRunData.TotalBossesHit
        }
        catch
        {
            GuiControl, ICScriptHub: +cRed, LoopID, 
            GuiControl, ICScriptHub:, LoopID, % "Error reading from gem farm script [Closed Script?]."
        }
    }

    ResetBrivFarmStats()
    {
        this.ResetUpdateStats()
        this.ResetComObjectStats()
    }

    ResetComObjectStats()
    {
        try ; avoid thrown errors when comobject is not available.
        {
            SharedRunData := ComObjActive("{416ABC15-9EFC-400C-8123-D7D8778A2103}")
            SharedRunData.StackFailStats := new StackFailStates
            SharedRunData.LoopString := ""
            SharedRunData.TotalBossesHit := 0
            SharedRunData.BossesHitThisRun := 0
            SharedRunData.SwapsMadeThisRun := 0
            SharedRunData.StackFail := 0
            SharedRunData.OpenedSilverChests := 0
            SharedRunData.OpenedGoldChests := 0
            SharedRunData.PurchasedGoldChests := 0
            SharedRunData.PurchasedSilverChests := 0
            SharedRunData.ShinyCount := 0
        }
    }

    ResetUpdateStats()
    {
        this.TotalRunCount := 0
        this.FailedStacking := 0
        this.FailedStackConv := 0
        this.SlowRunTime := 0
        this.FastRunTime := 0
        this.ScriptStartTime := 0
        this.CoreXPStart := 0
        this.GemStart := 0
        this.GemSpentStart := 0
        this.BossesPerHour := 0
        this.LastResetCount := 0
        this.RunStartTime := A_TickCount
        this.IsStarted := false ; Skip recording of first run
        this.StackFail := ""
        this.SilverChestCountStart := 0
        this.GoldChestCountStart := 0
        this.LastTriggerStart := false
        this.ActiveGameInstance := 1
        this.FailRunTime := 0
        this.TotalRunCountRetry := 0
    }

    ;===========================================
    ;Functions for updating GUI stats and timers
    ;===========================================

    CreateTimedFunctions()
    {
        this.TimedFunctions := {}
        fncToCallOnTimer :=  ObjBindMethod(this, "UpdateStatTimers")
        this.TimerFunctions[fncToCallOnTimer] := 200
        fncToCallOnTimer :=  ObjBindMethod(this, "UpdateStartLoopStats")
        this.TimerFunctions[fncToCallOnTimer] := 3000
        ; TODO: add this from IC_MemoryFunctions and remove from here
        if(IsFunc(Func("IC_MemoryFunctions_ReadMemory")))
        {
            fncToCallOnTimer :=  Func("IC_MemoryFunctions_ReadMemory")
            this.TimerFunctions[fncToCallOnTimer] := 250
        }
        fncToCallOnTimer := ObjBindMethod(this, "UpdateGUIFromCom")
        this.TimerFunctions[fncToCallOnTimer] := 100
        fncToCallOnTimer := ObjBindMethod(g_SF, "MonitorIsGameClosed")
        this.TimerFunctions[fncToCallOnTimer] := 200
    }

    ; Starts functions that need to be run in a separate thread such as GUI Updates.
    StartTimedFunctions()
    {
        for k,v in this.TimerFunctions
        {
            SetTimer, %k%, %v%, 0
        }
    }

    StopTimedFunctions()
    {
        for k,v in this.TimerFunctions
        {
            SetTimer, %k%, Off
            SetTimer, %k%, Delete
        }
    }
}