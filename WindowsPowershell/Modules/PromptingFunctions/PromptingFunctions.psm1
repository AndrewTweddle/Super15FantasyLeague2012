# Author: Andrew Tweddle
# Notes:  This library is used for automation of processes.
#         It provides a trade-off between the benefits of automation (reduced risk of human error, productivity) 
#         and the benefits of human oversight (responding to unexpected errors)

# Known bugs:
#
# 1. The library should always prompt for manual actions, even if set to run all steps
# 2. Consider modifying the -automatic switch to do children automatically, but NOT the action itself

# Ideas for future enhancements:
#
# 1. Add a switch -askIfOK to prompt user to confirm that the action was okay (e.g. msbuild errors aren't always accessible)
# 2. Add CmdLet metadata for prompting functions
# 3. Add support for parallel steps run as concurrent Powershell jobs. Add a -sequential switch when invoking a prompt, so that parallel steps are run sequentially instead.
# 4. Implement GO TO functionality by using "gs 1.1.2.3" to go to a particular step number, or "go Use DBHelper to build the SQL scripts" to go to a step with a particular label. All previous steps are skipped.
# 5. Implement RUN TO functionality by using "rs 1.1.2.3" to run to a particular step number, or "ro Use DBHelper to build the SQL scripts" to run to a step with a particular label. All previous steps are executed.
# 6. Add $hint parameter for additional information shown in grey before the action is done (particularly where it's a manual action)
# 7. Allow actions to be run even if the -manual switch is used. The action should run BEFORE asking the user whether they have completed the action or not.
# 8. When running all actions, or all actions at a level, consider checking for a special keypress to "break into" the automatic steps.
# 9. Consider providing a preview option (like the built-in -whatif switch). This displays all actions to be taken, but without actually executing them. 
#    This has risks however since the automation script needs to support and honour the preview option.
#    A -supportsPreview option will need to be added.
#    If set, then the action can be run and the script writer undertakes to call a Get-PromptingPreviewMode to check if in preview mode or not.
#    If not set (the default), then the action will not be run, so any child actions will not be displayed either.

function Get-PromptingInProgress
{
    (test-path variable:prompting_InProgress) -and $global:prompting_InProgress
}

function Write-Prompt
( 
    [string] $text = "`r`n",
    [ConsoleColor] $backgroundColor = $Host.UI.RawUI.BackgroundColor,
    [ConsoleColor] $foregroundColor = $Host.UI.RawUI.ForegroundColor
)
{
    # Calculate indentation and indent the text based on the level of nesting:
    $indentation = new-object string -argumentList ' ',$(2 * $global:prompting_currentLevel)
    if ($indentation)
    {
        $indentedText = $indentation + ($text -replace "(`r`n|`r|`n)","`$1$indentation")
    }
    else
    {
        $indentedText = $text
    }
    
    Write-Host $indentedText -backgroundColor:$backgroundColor -foregroundColor:$foregroundColor
}

function Write-PromptingInstructions
{
    $bgColor = 'White'
    $fgColor = 'Black'
    Write-Prompt 'Prompting options at each step:' $bgColor $fgColor
    Write-Prompt '-------------------------------' $bgColor $fgColor
    # Write-Host
    Write-Prompt 'H/O/?   Help (these instructions)' $bgColor $fgColor
    Write-Prompt 'Y/ENTER Yes' $bgColor $fgColor
    Write-Prompt 'N       No' $bgColor $fgColor
    Write-Prompt 'A       All (at all levels)' $bgColor $fgColor
    Write-Prompt 'Q       Quit (none at any level)' $bgColor $fgColor
    Write-Prompt 'C       Complete this level' $bgColor $fgColor
    Write-Prompt 'S       Skip remaining steps at this level' $bgColor $fgColor
    Write-Prompt 'E       Enter nested prompt (like a breakpoint - type Exit to get out of nested prompt)' $bgColor $fgColor
    Write-Prompt 'D       Enter debug mode' $bgColor $fgColor
    Write-Prompt '        NB: D/DS steps through each line.' $bgColor $fgColor
    Write-Prompt '            DT just shows a trace of the commands.' $bgColor $fgColor
    Write-Prompt '            DI just shows debug info for the prompting library' $bgColor $fgColor
    Write-Prompt '            DLS/DLT steps or traces through the prompting library code as well' $bgColor $fgColor
    Write-Prompt 'X       Exit debug mode' $bgColor $fgColor
    Write-Host
}

function Write-PromptingDebugInfo
{
    $bgColor = 'White'
    $fgColor = 'Red'
    Write-Prompt '*** DEBUG INFO:' $bgColor $fgColor
    Write-Prompt "`$global:prompting_currentLevel = $global:prompting_currentLevel" $bgColor $fgColor
    Write-Prompt "`$global:prompting_StepNumbers = $global:prompting_StepNumbers" $bgColor $fgColor
    Write-Prompt "`$global:prompting_lastPromptResults = $global:prompting_lastPromptResults" $bgColor $fgColor
    Write-Prompt "`$global:Prompting_LastPromptResult = $global:Prompting_LastPromptResult" $bgColor $fgColor
    Write-Prompt "`$global:prompting_InProgress = $global:prompting_InProgress" $bgColor $fgColor
    Write-Prompt "`$global:prompting_DebugMode = $global:prompting_DebugMode" $bgColor $fgColor
    Write-Host
}

function Invoke-PromptingAction
(
    [string] $actionName = $( throw 'Please provide the action name' ),
    [ScriptBlock] $action = $null,  # The action to perform
    [switch] $manual = $false,      # Don't do the action, just prompt the user as to whether they have done it
    [switch] $mandatory = $false,   # Don't allow the user to skip this action
    [switch] $automatic = $false,   # Complete this level and all its sub-actions without any prompting (only if an error occurs will prompting resume)
    [switch] $beep = $false,        # Beep if the action is done
    [string] $logFilePath = $null,  # Only used for the highest level prompt, this will store a transcript of each action performed
    [switch] $localScope = $true    # If set to false, the action will be run in its own private scope. By default it runs in the scope of the prompting library.
)
{
    # Ensure that nested statements don't go into debug mode unnecessarily:
    switch ($global:prompting_DebugMode) {
        'ds' { Set-PSDebug -off }
        'dt' { Set-PSDebug -off }
    }
    
    # Check that the parameters are consistent:
    if (($action -eq $null) -and (-not $manual))
    {
        throw 'No action script block has been provided and the manual switch has been set'
    }
    
    # Start prompting automatically if it hasn't been started:
    [bool] $isSelfContainedPromptingRun = $false
    
    if (-not (Get-PromptingInProgress))
    {
        # Initialize the prompting variables:
        $isSelfContainedPromptingRun = $true
        $global:prompting_lastPromptResults = @('')
        $global:prompting_StepNumbers = @(1)
        $global:prompting_currentLevel = 0
        $global:prompting_DebugMode = 'x'
        $global:prompting_logFilePath = $logFilePath
        if ($logFilePath)
        {
            Start-Transcript $logFilePath -noClobber
        }
        $global:prompting_InProgress = $true
        
        $stepLabel = 'run'
    }
    else
    {
        $stepLabel = 'step'
    }
    
    try
    {
        $global:Prompting_LastPromptResult = $global:prompting_lastPromptResults[$global:prompting_currentLevel]
        
        if ( @('Q','S') -notcontains $global:Prompting_LastPromptResult)
        {
            if ($global:prompting_currentLevel -eq 0)
            {
                $stepDescription = "[$([datetime]::Now.ToString('yyyy-MM-dd HH:mm:ss'))] Run: $actionName $( if ($mandatory) {'[MANDATORY]'})"
                $dashChar = '='
                $backgroundColor = 'Green'
            }
            else
            {
                $stepDescription = [string]::Join('.', $global:prompting_StepNumbers[1..$global:prompting_currentLevel]);
                $stepDescription = "[$([datetime]::Now.ToString('HH:mm:ss'))]     Step $($stepDescription). $actionName $( if ($mandatory) {'[MANDATORY]'})"
                $dashChar = '-'
                $backgroundColor = 'Yellow'
            }
            $dashes = new-object System.String -argumentList $dashChar,$($stepDescription.Length)
            
            Write-Prompt $dashes $backgroundColor Black
            Write-Prompt $stepDescription $backgroundColor Black
            Write-Host
            
            if ($global:prompting_currentLevel -eq 0)
            {
                Write-PromptingInstructions
            }
        }
        else
        {
            Write-Prompt "[$([datetime]::Now.ToString('HH:mm:ss'))]     Skipped step: $actionName" Red White
        }
        
        $promptingStepNumberUpdated = $false
        try
        {
            # Based on the result of the last test, the prompt result may be known:
            if ( @('A','Q','C','S') -contains $global:Prompting_LastPromptResult)
            {
                $promptResult = $global:Prompting_LastPromptResult
            }
            elseif ($automatic)
            {
                $promptResult = 'C'
                $global:prompting_lastPromptResults[$global:prompting_currentLevel] = 'C'
            }
            else
            {
                $showPrompt = $true
                while ($showPrompt) 
                {
                    $showPrompt = $false
                    if ($manual) 
                    {
                        Write-Prompt 'Have you performed the action?' Magenta Black
                    }
                    else
                    {
                        Write-Prompt "Continue with the $($stepLabel)?" Cyan Black
                    }
                    $promptResult = Read-Host
                    
                    # Unless in manual mode, just pressing carriage return is the same as choosing yes:
                    if ([string]::IsNullOrEmpty($promptResult) -and (-not $manual))
                    {
                        Write-Prompt 'Y'
                        $promptResult = 'Y'
                    }
                    
                    switch -regex ($promptResult) {
                        # Common options:
                        '^[HhOo]|\?'  { 
                            Write-PromptingInstructions
                            $showPrompt = $true 
                        }
                        '^[Ee]' { 
                            # Enter a nested prompt (useful for debugging)
                            $host.EnterNestedPrompt()
                            $showPrompt = $true
                        }   
                        '^[Dd][Ll][sS]?$' {
                            # Debug prompting library with stepping through commands
                            $global:prompting_DebugMode = 'dls'
                            $showPrompt = $true 
                            Set-PSDebug -Step
                        } 
                        '^[Dd][Ll][Tt]' {
                            # Debug prompting library with tracing commands
                            $global:prompting_DebugMode = 'dlt'
                            $showPrompt = $true 
                            Set-PSDebug -Trace 2
                        } 
                        '^[Dd][sS]?$' {
                            # Debug with stepping through commands
                            Set-PSDebug -off
                            $global:prompting_DebugMode = 'ds'
                            $showPrompt = $true 
                        }
                        '^[Dd][Tt]'   { 
                            # Debug with tracing commands
                            Set-PSDebug -off
                            $global:prompting_DebugMode = 'dt'
                            $showPrompt = $true
                        }
                        '^[Dd][Ii]' {
                            # Debug info for the prompting framework
                            Write-PromptingDebugInfo
                            $showPrompt = $true 
                        }
                        '^[Xx]' {
                            # Stop debugging:
                            Set-PSDebug -off
                            $global:prompting_DebugMode = 'x'
                            $showPrompt = $true 
                        }
                        # Other options:
                        '^[Yy]' { break; }
                        '^[Nn]' { 
                            if ($mandatory) {
                                Write-Prompt 'This option is mandatory and can not be skipped' White Red
                                Write-Host
                                $showPrompt = $true
                            }
                            break; 
                        }
                        '^[Aa]' { break; }
                        '^[Cc]' { break; }
                        '^[Qq]' { break; }
                        '^[Ss]' { break; }
                        '^$'    {
                            Write-Prompt 'When confirming that an action has been performed, <ENTER> does not default to Yes'
                            Write-Host
                            $showPrompt = $true
                        }
                        default {
                            Write-Prompt "Unrecognised option: $promptResult" White Red
                            Write-Host
                            $showPrompt = $true 
                        }
                    }
                }
                $global:prompting_lastPromptResults[$global:prompting_currentLevel] = $promptResult
            }
            
            if ($manual) 
            {
                $performAction = $false
            }
            else
            {
                $performAction = @('Y','A','C') -contains $promptResult
            }
            
            if ($performAction)
            {
                # Start the next prompting level, so that nested actions fall in a sub-section of the current action:
                $global:prompting_lastPromptResult = $global:prompting_lastPromptResults[$global:prompting_currentLevel]
                if ($global:prompting_lastPromptResult -notmatch '^[AaQqCcSs]')
                {
                    $global:prompting_lastPromptResult = ''
                }
                $global:prompting_lastPromptResults = $global:prompting_lastPromptResults + @($global:prompting_lastPromptResult)
                $global:prompting_StepNumbers = $global:prompting_StepNumbers + @(1)
                $global:prompting_currentLevel++

                try
                {
                    while ($performAction)  
                    {
                        try 
                        {
                            try
                            {
                                switch ($global:prompting_DebugMode) {
                                    'ds' { Set-PSDebug -step }
                                    'dt' { Set-PSDebug -Trace 2 }
                                }
                                try
                                {
                                    if ($localScope)
                                    {
                                        . $action
                                    }
                                    else
                                    {
                                        & $action
                                    }
                                }
                                finally
                                {
                                    switch ($global:prompting_DebugMode) {
                                        'ds' { Set-PSDebug -off }
                                        'dt' { Set-PSDebug -off }
                                    }
                                }
                                $performAction = $false
                            }
                            finally
                            {
                                if ($beep)
                                {
                                    [System.Console]::Beep()
                                }
                            }
                        }
                        catch
                        {
                            Write-Error $_
                            Write-Host
                            Write-Prompt "[$([datetime]::Now.ToString('HH:mm:ss'))]     An error occurred: $($_.Exception.ToString())" White Red
                            
                            $showPrompt = $true
                            while ($showPrompt) 
                            {
                                $showPrompt = $false
                                $retryPrompt = Read-Host 'Abort all remaining steps (A), Retry (R), Ignore and continue with next action (I)?'
                                $retryPrompt = $retryPrompt.ToUpper()
                                switch -regex ($retryPrompt) {
                                    # Common options:
                                    '^[HhOo]|\?'  { 
                                        Write-PromptingInstructions
                                        $showPrompt = $true 
                                    }
                                    '^[Ee]' { 
                                        # Enter a nested prompt (useful for debugging)
                                        $host.EnterNestedPrompt()
                                        $showPrompt = $true
                                    }   
                                    '^[Dd][Ll][sS]?$' {
                                        # Debug prompting library with stepping through commands
                                        $global:prompting_DebugMode = 'dls'
                                        $showPrompt = $true 
                                        Set-PSDebug -Step
                                    } 
                                    '^[Dd][Ll][Tt]' {
                                        # Debug prompting library with tracing commands
                                        $global:prompting_DebugMode = 'dlt'
                                        $showPrompt = $true 
                                        Set-PSDebug -Trace 2
                                    } 
                                    '^[Dd][sS]?$' {
                                        # Debug with stepping through commands
                                        Set-PSDebug -off
                                        $global:prompting_DebugMode = 'ds'
                                        $showPrompt = $true 
                                    }
                                    '^[Dd][Tt]'   { 
                                        # Debug with tracing commands
                                        Set-PSDebug -off
                                        $global:prompting_DebugMode = 'dt'
                                        $showPrompt = $true
                                    }
                                    '^[Dd][Ii]' {
                                        # Debug info for the prompting framework
                                        Write-PromptingDebugInfo
                                        $showPrompt = $true 
                                    }
                                    '^[Xx]' {
                                        # Stop debugging:
                                        Set-PSDebug -off
                                        $global:prompting_DebugMode = 'x'
                                        $showPrompt = $true 
                                    }
                                    # Other options:
                                    '^[Aa]' { 
                                        $promptResult = 'Q'
                                        $global:prompting_lastPromptResults[$global:prompting_currentLevel] = $promptResult
                                        $performAction = $false 
                                    }
                                    '^[Rr]'
                                    {
                                        $performAction = $true
                                    }
                                    '^[Ii]' {
                                        $performAction = $false
                                    }
                                    default {
                                        Write-Prompt "Unrecognised option: $retryPrompt" White Red
                                        $showPrompt = $true 
                                    }
                                }
                            }
                        }
                    }
                }
                finally
                {
                    $global:Prompting_LastPromptResult = $global:prompting_lastPromptResults[-1]
                    $newLastIndex = $global:prompting_lastPromptResults.Count - 2
                    $global:prompting_lastPromptResults = $global:prompting_lastPromptResults[0..$newLastIndex]
                    if ($global:Prompting_LastPromptResult -match '^[AaQq]')
                    {
                        $global:prompting_lastPromptResults[-1] = $global:Prompting_LastPromptResult
                    }
                    $newLastIndex = $global:prompting_StepNumbers.Count - 2
                    
                    # Set-PSDebug -step
                    # $hadNestedSteps = $global:prompting_StepNumbers[$currentLevel] -gt 0
                    # Set-PSDebug -off
                    
                    $global:prompting_StepNumbers = $global:prompting_StepNumbers[0..$newLastIndex]
                    $global:prompting_StepNumbers[-1] = $global:prompting_StepNumbers[-1] + 1
                    $global:prompting_currentLevel--
                    
                    if ($hadNestedSteps)
                    {
                        Write-Prompt '===================================' Yellow Black
                        Write-Host
                    }
                    
                    $promptingStepNumberUpdated = $true
                }
            }
        }
        finally
        {
            if (-not $promptingStepNumberUpdated)
            {
                $global:prompting_StepNumbers[-1] = $global:prompting_StepNumbers[-1] + 1
            }
        }
    }
    finally
    {
        if ($isSelfContainedPromptingRun -and ($global:prompting_currentLevel -eq 0))
        {
            # Stop prompting:
            $global:prompting_InProgress = $false
            $global:prompting_lastPromptResults = @()
            $global:prompting_stepNumbers = @()
            if ($global:prompting_logFilePath)
            {
                Stop-Transcript
            }
            Write-Host
            Write-Prompt '=====================' Green Black
            Write-Prompt "Stopped prompting run" Green Black
            Write-Host
        }
    }
}

New-Alias AskTo Invoke-PromptingAction

Export-ModuleMember -Function Invoke-PromptingAction,Write-Prompt -Alias *
