#!/bin/bash
# Show all Slack processes with their priority and resource usage
# Usage: slack-processes.sh [--boost]
#   --boost  Raise the highest-CPU Slack process to the next priority level

BOOST=false
if [[ "$1" == "--boost" ]]; then
    BOOST=true
fi

powershell.exe -NoProfile -Command "
    \$procs = Get-Process -Name '*slack*' -ErrorAction SilentlyContinue
    if (-not \$procs) {
        Write-Host 'No Slack processes found.'
        exit 0
    }

    \$procs | Select-Object Id, ProcessName, PriorityClass,
        @{N='MemoryMB';E={[math]::Round(\$_.WorkingSet64/1MB,2)}},
        @{N='CPU_Seconds';E={[math]::Round(\$_.CPU,2)}} |
    Format-Table -AutoSize

    if ('$BOOST' -eq 'true') {
        \$target = \$procs | Sort-Object CPU -Descending | Select-Object -First 1

        if (-not \$target) {
            Write-Host 'No process to boost.'
            exit 0
        }

        \$ladder = @('Idle','BelowNormal','Normal','AboveNormal','High')
        \$current = \$target.PriorityClass.ToString()
        \$idx = \$ladder.IndexOf(\$current)

        if (\$current -eq 'RealTime') {
            Write-Host \"PID \$(\$target.Id) is already at RealTime. Not changing.\"
            exit 0
        }

        if (\$idx -eq (\$ladder.Count - 1)) {
            Write-Host \"PID \$(\$target.Id) is already at High (max safe). Not changing.\"
            exit 0
        }

        \$next = \$ladder[\$idx + 1]
        Write-Host \"Boosting PID \$(\$target.Id) (\$(\$target.ProcessName)) from \$current -> \$next ...\"

        try {
            \$target.PriorityClass = \$next
            Write-Host 'Done. Updated process:'
            \$target | Select-Object Id, ProcessName, PriorityClass,
                @{N='MemoryMB';E={[math]::Round(\$_.WorkingSet64/1MB,2)}},
                @{N='CPU_Seconds';E={[math]::Round(\$_.CPU,2)}} |
            Format-Table -AutoSize
        } catch {
            Write-Host \"Failed to set priority. You may need to run this from an elevated (admin) shell.\"
            Write-Host \$_.Exception.Message
        }
    }
"
