[CmdletBinding()]
param()

function Get-MaxInfoFromSqlServer {
    [CmdletBinding()]
    param()

    $sqlServerKeyName = 'Software\Microsoft\Microsoft SQL Server'
    foreach ($view in @( 'Registry32', 'Registry64' )) {
        $versions =
            Get-RegistrySubKeyNames -Hive 'LocalMachine' -View $view -KeyName $sqlServerKeyName |
            # Filter to include integer key names only.
            ForEach-Object {
                $i = 0
                if (([int]::TryParse($_, [ref]$i))) {
                    $i
                }
            } |
            Sort-Object -Descending
        foreach ($version in $versions) {
            # Get the install directory.
            $verSpecificRootDir = Get-RegistryValue -Hive 'LocalMachine' -View $view -KeyName "$sqlServerKeyName\$version" -Value 'VerSpecificRootDir'
            if (!$verSpecificRootDir) {
                continue
            }

            # Test for SqlPackage.exe.
            $file = [System.IO.Path]::Combine($verSpecificRootDir, 'Dac', 'bin', 'SqlPackage.exe')
            if (!(Test-Leaf -LiteralPath $file)) {
                continue
            }

            # Return the info as an object with properties (for sorting).
            return New-Object psobject -Property @{
                File = $file
                Version = $version
            }
        }
    }
}

function Get-MaxInfoFromSqlServerDtaf {
    [CmdletBinding()]
    param()

    $dtafKeyName = 'Software\Microsoft\Microsoft SQL Server\Data-Tier Application Framework'
    foreach ($view in @( 'Registry32', 'Registry64' )) {
        $versions =
            Get-RegistrySubKeyNames -Hive 'LocalMachine' -View $view -KeyName $dtafKeyName |
            # Filter to include integer key names only.
            ForEach-Object {
                $i = 0
                if (([int]::TryParse($_, [ref]$i))) {
                    $i
                }
            } |
            Sort-Object -Descending
       foreach ($version in $versions) {
            # Get the install directory.
            $installDir = Get-RegistryValue -Hive 'LocalMachine' -View $view -KeyName "$dtafKeyName\$version" -Value 'InstallDir'
            if (!$installDir) {
                continue
            }

            # Test for SqlPackage.exe.
            $file = [System.IO.Path]::Combine($installDir, 'SqlPackage.exe')
            if (!(Test-Leaf -LiteralPath $file)) {
                continue
            }

            # Return the info as an object with properties (for sorting).
            return New-Object psobject -Property @{
                File = $file
                Version = $version
            }
        }
    }
}

function Get-MaxInfoFromVisualStudio_15_0 {
    [CmdletBinding()]
    param()

    $vs15 = Get-VisualStudio -MajorVersion 15
    if ($vs15 -and $vs15.installationPath) {
        # End with "\" for consistency with old ShellFolder values.
        $shellFolder15 = $vs15.installationPath.TrimEnd('\'[0]) + "\"

        # Test for the DAC directory.
        $dacDirectory = [System.IO.Path]::Combine($shellFolder15, 'Common7', 'IDE', 'Extensions', 'Microsoft', 'SQLDB', 'DAC')
        $sqlPacakgeInfo = Get-SqlPacakgeFromDacDirectory -dacDirectory $dacDirectory

        if($sqlPacakgeInfo -and $sqlPacakgeInfo.File) {
            return $sqlPacakgeInfo
        }
    }
}

function Get-MaxInfoFromVisualStudio_16_0 {
    [CmdletBinding()]
    param()

    $vs16 = Get-VisualStudio -MajorVersion 16
    if ($vs16 -and $vs16.installationPath) {
        # End with "\" for consistency with old ShellFolder values.
        $shellFolder16 = $vs16.installationPath.TrimEnd('\'[0]) + "\"

        # Test for the DAC directory.
        $dacDirectory = [System.IO.Path]::Combine($shellFolder16, 'Common7', 'IDE', 'Extensions', 'Microsoft', 'SQLDB', 'DAC')
        $sqlPacakgeInfo = Get-SqlPacakgeFromDacDirectory -dacDirectory $dacDirectory

        if($sqlPacakgeInfo -and $sqlPacakgeInfo.File) {
            return $sqlPacakgeInfo
        }
    }
}

function Get-MaxInfoFromVisualStudio {
    [CmdletBinding()]
    param()

    $visualStudioKeyName = 'Software\Microsoft\VisualStudio'
    foreach ($view in @( 'Registry32', 'Registry64' )) {
        $versions =
            Get-RegistrySubKeyNames -Hive 'LocalMachine' -View $view -KeyName $visualStudioKeyName |
            # Filter to include integer key names only.
            ForEach-Object {
                $d = 0
                if (([decimal]::TryParse($_, [ref]$d))) {
                    $d
                }
            } |
            Sort-Object -Descending
        foreach ($version in $versions) {
            # Get the install directory.
            $installDir = Get-RegistryValue -Hive 'LocalMachine' -View $view -KeyName "$visualStudioKeyName\$version" -Value 'InstallDir'
            if (!$installDir) {
                continue
            }

            # Test for the DAC directory.
            $dacDirectory = [System.IO.Path]::Combine($installDir, 'Extensions', 'Microsoft', 'SQLDB', 'DAC')
            $sqlPacakgeInfo = Get-SqlPacakgeFromDacDirectory -dacDirectory $dacDirectory

            if($sqlPacakgeInfo -and $sqlPacakgeInfo.File)
           {
                return $sqlPacakgeInfo
            }
        }
    }
}

function Get-SqlPacakgeFromDacDirectory {
    [CmdletBinding()]
    param([string] $dacDirectory)


    if (!(Test-Container -LiteralPath $dacDirectory)) {
        return
    }

    # Get the DAC version folders.
    $dacVersions =
        Get-ChildItem -LiteralPath $dacDirectory |
        Where-Object { $_ -is [System.IO.DirectoryInfo] }
        # Filter to include integer key names only.
        ForEach-Object {
            $i = 0
            if (([int]::TryParse($_.Name, [ref]$i))) {
                $i
            }
        } |
        Sort-Object -Descending
    foreach ($dacVersion in $dacVersions) {
        # Test for SqlPackage.exe.
        $file = [System.IO.Path]::Combine($dacDirectory, $dacVersion, 'SqlPackage.exe')
        if (!(Test-Leaf -LiteralPath $file)) {
            continue
        }

        # Return the info as an object with properties (for sorting).
        return New-Object psobject -Property @{
            File = $file
            Version = $dacVersion
        }
    }
}

$sqlPackageInfo = @( )
$sqlPackageInfo += (Get-MaxInfoFromSqlServer)
$sqlPackageInfo += (Get-MaxInfoFromSqlServerDtaf)
$sqlPackageInfo += (Get-MaxInfoFromVisualStudio)
$sqlPackageInfo += (Get-MaxInfoFromVisualStudio_15_0)
$sqlPackageInfo += (Get-MaxInfoFromVisualStudio_16_0)
$sqlPackageInfo |
    Sort-Object -Property Version -Descending |
    Select -First 1 |
    ForEach-Object { Write-Capability -Name 'SqlPackage' -Value $_.File }

# SIG # Begin signature block
# MIInzgYJKoZIhvcNAQcCoIInvzCCJ7sCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCOjTE62sJdoUmq
# k9HIKV1rPBftv+AAM5QuYfoYjKNCpKCCDYUwggYDMIID66ADAgECAhMzAAADri01
# UchTj1UdAAAAAAOuMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjMxMTE2MTkwODU5WhcNMjQxMTE0MTkwODU5WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQD0IPymNjfDEKg+YyE6SjDvJwKW1+pieqTjAY0CnOHZ1Nj5irGjNZPMlQ4HfxXG
# yAVCZcEWE4x2sZgam872R1s0+TAelOtbqFmoW4suJHAYoTHhkznNVKpscm5fZ899
# QnReZv5WtWwbD8HAFXbPPStW2JKCqPcZ54Y6wbuWV9bKtKPImqbkMcTejTgEAj82
# 6GQc6/Th66Koka8cUIvz59e/IP04DGrh9wkq2jIFvQ8EDegw1B4KyJTIs76+hmpV
# M5SwBZjRs3liOQrierkNVo11WuujB3kBf2CbPoP9MlOyyezqkMIbTRj4OHeKlamd
# WaSFhwHLJRIQpfc8sLwOSIBBAgMBAAGjggGCMIIBfjAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQUhx/vdKmXhwc4WiWXbsf0I53h8T8w
# VAYDVR0RBE0wS6RJMEcxLTArBgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5kIE9wZXJh
# dGlvbnMgTGltaXRlZDEWMBQGA1UEBRMNMjMwMDEyKzUwMTgzNjAfBgNVHSMEGDAW
# gBRIbmTlUAXTgqoXNzcitW2oynUClTBUBgNVHR8ETTBLMEmgR6BFhkNodHRwOi8v
# d3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNDb2RTaWdQQ0EyMDExXzIw
# MTEtMDctMDguY3JsMGEGCCsGAQUFBwEBBFUwUzBRBggrBgEFBQcwAoZFaHR0cDov
# L3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9NaWNDb2RTaWdQQ0EyMDEx
# XzIwMTEtMDctMDguY3J0MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQELBQADggIB
# AGrJYDUS7s8o0yNprGXRXuAnRcHKxSjFmW4wclcUTYsQZkhnbMwthWM6cAYb/h2W
# 5GNKtlmj/y/CThe3y/o0EH2h+jwfU/9eJ0fK1ZO/2WD0xi777qU+a7l8KjMPdwjY
# 0tk9bYEGEZfYPRHy1AGPQVuZlG4i5ymJDsMrcIcqV8pxzsw/yk/O4y/nlOjHz4oV
# APU0br5t9tgD8E08GSDi3I6H57Ftod9w26h0MlQiOr10Xqhr5iPLS7SlQwj8HW37
# ybqsmjQpKhmWul6xiXSNGGm36GarHy4Q1egYlxhlUnk3ZKSr3QtWIo1GGL03hT57
# xzjL25fKiZQX/q+II8nuG5M0Qmjvl6Egltr4hZ3e3FQRzRHfLoNPq3ELpxbWdH8t
# Nuj0j/x9Crnfwbki8n57mJKI5JVWRWTSLmbTcDDLkTZlJLg9V1BIJwXGY3i2kR9i
# 5HsADL8YlW0gMWVSlKB1eiSlK6LmFi0rVH16dde+j5T/EaQtFz6qngN7d1lvO7uk
# 6rtX+MLKG4LDRsQgBTi6sIYiKntMjoYFHMPvI/OMUip5ljtLitVbkFGfagSqmbxK
# 7rJMhC8wiTzHanBg1Rrbff1niBbnFbbV4UDmYumjs1FIpFCazk6AADXxoKCo5TsO
# zSHqr9gHgGYQC2hMyX9MGLIpowYCURx3L7kUiGbOiMwaMIIHejCCBWKgAwIBAgIK
# YQ6Q0gAAAAAAAzANBgkqhkiG9w0BAQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNV
# BAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlm
# aWNhdGUgQXV0aG9yaXR5IDIwMTEwHhcNMTEwNzA4MjA1OTA5WhcNMjYwNzA4MjEw
# OTA5WjB+MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSgwJgYD
# VQQDEx9NaWNyb3NvZnQgQ29kZSBTaWduaW5nIFBDQSAyMDExMIICIjANBgkqhkiG
# 9w0BAQEFAAOCAg8AMIICCgKCAgEAq/D6chAcLq3YbqqCEE00uvK2WCGfQhsqa+la
# UKq4BjgaBEm6f8MMHt03a8YS2AvwOMKZBrDIOdUBFDFC04kNeWSHfpRgJGyvnkmc
# 6Whe0t+bU7IKLMOv2akrrnoJr9eWWcpgGgXpZnboMlImEi/nqwhQz7NEt13YxC4D
# dato88tt8zpcoRb0RrrgOGSsbmQ1eKagYw8t00CT+OPeBw3VXHmlSSnnDb6gE3e+
# lD3v++MrWhAfTVYoonpy4BI6t0le2O3tQ5GD2Xuye4Yb2T6xjF3oiU+EGvKhL1nk
# kDstrjNYxbc+/jLTswM9sbKvkjh+0p2ALPVOVpEhNSXDOW5kf1O6nA+tGSOEy/S6
# A4aN91/w0FK/jJSHvMAhdCVfGCi2zCcoOCWYOUo2z3yxkq4cI6epZuxhH2rhKEmd
# X4jiJV3TIUs+UsS1Vz8kA/DRelsv1SPjcF0PUUZ3s/gA4bysAoJf28AVs70b1FVL
# 5zmhD+kjSbwYuER8ReTBw3J64HLnJN+/RpnF78IcV9uDjexNSTCnq47f7Fufr/zd
# sGbiwZeBe+3W7UvnSSmnEyimp31ngOaKYnhfsi+E11ecXL93KCjx7W3DKI8sj0A3
# T8HhhUSJxAlMxdSlQy90lfdu+HggWCwTXWCVmj5PM4TasIgX3p5O9JawvEagbJjS
# 4NaIjAsCAwEAAaOCAe0wggHpMBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBRI
# bmTlUAXTgqoXNzcitW2oynUClTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTAL
# BgNVHQ8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBRyLToCMZBD
# uRQFTuHqp8cx0SOJNDBaBgNVHR8EUzBRME+gTaBLhklodHRwOi8vY3JsLm1pY3Jv
# c29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFf
# MDNfMjIuY3JsMF4GCCsGAQUFBwEBBFIwUDBOBggrBgEFBQcwAoZCaHR0cDovL3d3
# dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFf
# MDNfMjIuY3J0MIGfBgNVHSAEgZcwgZQwgZEGCSsGAQQBgjcuAzCBgzA/BggrBgEF
# BQcCARYzaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9kb2NzL3ByaW1h
# cnljcHMuaHRtMEAGCCsGAQUFBwICMDQeMiAdAEwAZQBnAGEAbABfAHAAbwBsAGkA
# YwB5AF8AcwB0AGEAdABlAG0AZQBuAHQALiAdMA0GCSqGSIb3DQEBCwUAA4ICAQBn
# 8oalmOBUeRou09h0ZyKbC5YR4WOSmUKWfdJ5DJDBZV8uLD74w3LRbYP+vj/oCso7
# v0epo/Np22O/IjWll11lhJB9i0ZQVdgMknzSGksc8zxCi1LQsP1r4z4HLimb5j0b
# pdS1HXeUOeLpZMlEPXh6I/MTfaaQdION9MsmAkYqwooQu6SpBQyb7Wj6aC6VoCo/
# KmtYSWMfCWluWpiW5IP0wI/zRive/DvQvTXvbiWu5a8n7dDd8w6vmSiXmE0OPQvy
# CInWH8MyGOLwxS3OW560STkKxgrCxq2u5bLZ2xWIUUVYODJxJxp/sfQn+N4sOiBp
# mLJZiWhub6e3dMNABQamASooPoI/E01mC8CzTfXhj38cbxV9Rad25UAqZaPDXVJi
# hsMdYzaXht/a8/jyFqGaJ+HNpZfQ7l1jQeNbB5yHPgZ3BtEGsXUfFL5hYbXw3MYb
# BL7fQccOKO7eZS/sl/ahXJbYANahRr1Z85elCUtIEJmAH9AAKcWxm6U/RXceNcbS
# oqKfenoi+kiVH6v7RyOA9Z74v2u3S5fi63V4GuzqN5l5GEv/1rMjaHXmr/r8i+sL
# gOppO6/8MO0ETI7f33VtY5E90Z1WTk+/gFcioXgRMiF670EKsT/7qMykXcGhiJtX
# cVZOSEXAQsmbdlsKgEhr/Xmfwb1tbWrJUnMTDXpQzTGCGZ8wghmbAgEBMIGVMH4x
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01p
# Y3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMTECEzMAAAOuLTVRyFOPVR0AAAAA
# A64wDQYJYIZIAWUDBAIBBQCgga4wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQw
# HAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIAcA
# YT1LTbAZxyxGLKTg1nm/vR7uqCERjyR4QaLcAfKfMEIGCisGAQQBgjcCAQwxNDAy
# oBSAEgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20wDQYJKoZIhvcNAQEBBQAEggEAvreIpomzWVd42zbJ3oTT3dNsLQDa1+fNWmke
# tUsYaxB8ViJYhr21GUVzsqY0/ElDV0oUsFnGWu/k4FwSXssxEMHkC6XQE85zdLOd
# nJCjm2PJQz7zmAiFPK+0b7hIWvKUcFivUGSuvhBFe5LaF/7szbuHKsG9sNWC9c7R
# /I2hS8OoMm1iEOyCOtwhvADhoFs3yxI+mtzv1TRR/i3N0qw8eTvu+SwvozmHWFdY
# ST/dwP1qgfFdgmZikO62kE9IHGC8oUOaZeiWyhE2yXJhty1tH9qPHG2NgNiWS2HA
# XwZnZPanTMzmzxkJf9Zi6130kGiA82Pix4+QZbEgizjBojt2tqGCFykwghclBgor
# BgEEAYI3AwMBMYIXFTCCFxEGCSqGSIb3DQEHAqCCFwIwghb+AgEDMQ8wDQYJYIZI
# AWUDBAIBBQAwggFZBgsqhkiG9w0BCRABBKCCAUgEggFEMIIBQAIBAQYKKwYBBAGE
# WQoDATAxMA0GCWCGSAFlAwQCAQUABCALZN5MtUS5tM5MH1eWgcM5lkYD8lagnOjg
# L1m6pFgrqwIGZpe1ti7dGBMyMDI0MDcxODE2NTEyNS4xNTRaMASAAgH0oIHYpIHV
# MIHSMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQL
# EyRNaWNyb3NvZnQgSXJlbGFuZCBPcGVyYXRpb25zIExpbWl0ZWQxJjAkBgNVBAsT
# HVRoYWxlcyBUU1MgRVNOOjA4NDItNEJFNi1DMjlBMSUwIwYDVQQDExxNaWNyb3Nv
# ZnQgVGltZS1TdGFtcCBTZXJ2aWNloIIReDCCBycwggUPoAMCAQICEzMAAAHajtXJ
# WgDREbEAAQAAAdowDQYJKoZIhvcNAQELBQAwfDELMAkGA1UEBhMCVVMxEzARBgNV
# BAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAg
# UENBIDIwMTAwHhcNMjMxMDEyMTkwNjU5WhcNMjUwMTEwMTkwNjU5WjCB0jELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEtMCsGA1UECxMkTWljcm9z
# b2Z0IElyZWxhbmQgT3BlcmF0aW9ucyBMaW1pdGVkMSYwJAYDVQQLEx1UaGFsZXMg
# VFNTIEVTTjowODQyLTRCRTYtQzI5QTElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUt
# U3RhbXAgU2VydmljZTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAJOQ
# Bgh2tVFR1j8jQA4NDf8bcVrXSN080CNKPSQo7S57sCnPU0FKF47w2L6qHtwm4EnC
# lF2cruXFp/l7PpMQg25E7X8xDmvxr8BBE6iASAPCfrTebuvAsZWcJYhy7prgCuBf
# 7OidXpgsW1y8p6Vs7sD2aup/0uveYxeXlKtsPjMCplHkk0ba+HgLho0J68Kdji3D
# M2K59wHy9xrtsYK+X9erbDGZ2mmX3765aS5Q7/ugDxMVgzyj80yJn6ULnknD9i4k
# UQxVhqV1dc/DF6UBeuzfukkMed7trzUEZMRyla7qhvwUeQlgzCQhpZjz+zsQgpXl
# PczvGd0iqr7lACwfVGog5plIzdExvt1TA8Jmef819aTKwH1IVEIwYLA6uvS8kRdA
# 6RxvMcb//ulNjIuGceyykMAXEynVrLG9VvK4rfrCsGL3j30Lmidug+owrcCjQagY
# mrGk1hBykXilo9YB8Qyy5Q1KhGuH65V3zFy8a0kwbKBRs8VR4HtoPYw9z1DdcJfZ
# BO2dhzX3yAMipCGm6SmvmvavRsXhy805jiApDyN+s0/b7os2z8iRWGJk6M9uuT24
# 93gFV/9JLGg5YJJCJXI+yxkO/OXnZJsuGt0+zWLdHS4XIXBG17oPu5KsFfRTHREl
# oR2dI6GwaaxIyDySHYOtvIydla7u4lfnfCjY/qKTAgMBAAGjggFJMIIBRTAdBgNV
# HQ4EFgQUoXyNyVE9ZhOVizEUVwhNgL8PX0UwHwYDVR0jBBgwFoAUn6cVXQBeYl2D
# 9OXSZacbUzUZ6XIwXwYDVR0fBFgwVjBUoFKgUIZOaHR0cDovL3d3dy5taWNyb3Nv
# ZnQuY29tL3BraW9wcy9jcmwvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUy
# MDIwMTAoMSkuY3JsMGwGCCsGAQUFBwEBBGAwXjBcBggrBgEFBQcwAoZQaHR0cDov
# L3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9NaWNyb3NvZnQlMjBUaW1l
# LVN0YW1wJTIwUENBJTIwMjAxMCgxKS5jcnQwDAYDVR0TAQH/BAIwADAWBgNVHSUB
# Af8EDDAKBggrBgEFBQcDCDAOBgNVHQ8BAf8EBAMCB4AwDQYJKoZIhvcNAQELBQAD
# ggIBALmDVdTtuI0jAEt41O2OM8CU237TGMyhrGr7FzKCEFaXxtoqk/IObQriq1ca
# HVh2vyuQ24nz3TdOBv7rcs/qnPjOxnXFLyZPeaWLsNuARVmUViyVYXjXYB5DwzaW
# ZgScY8GKL7yGjyWrh78WJUgh7rE1+5VD5h0/6rs9dBRqAzI9fhZz7spsjt8vnx50
# WExbBSSH7rfabHendpeqbTmW/RfcaT+GFIsT+g2ej7wRKIq/QhnsoF8mpFNPHV1q
# /WK/rF/ChovkhJMDvlqtETWi97GolOSKamZC9bYgcPKfz28ed25WJy10VtQ9P5+C
# /2dOfDaz1RmeOb27Kbegha0SfPcriTfORVvqPDSa3n9N7dhTY7+49I8evoad9hdZ
# 8CfIOPftwt3xTX2RhMZJCVoFlabHcvfb84raFM6cz5EYk+x1aVEiXtgK6R0xn1wj
# MXHf0AWlSjqRkzvSnRKzFsZwEl74VahlKVhI+Ci9RT9+6Gc0xWzJ7zQIUFE3Jiix
# 5+7KL8ArHfBY9UFLz4snboJ7Qip3IADbkU4ZL0iQ8j8Ixra7aSYfToUefmct3dM6
# 9ff4Eeh2Kh9NsKiiph589Ap/xS1jESlrfjL/g/ZboaS5d9a2fA598mubDvLD5x5P
# P37700vm/Y+PIhmp2fTvuS2sndeZBmyTqcUNHRNmCk+njV3nMIIHcTCCBVmgAwIB
# AgITMwAAABXF52ueAptJmQAAAAAAFTANBgkqhkiG9w0BAQsFADCBiDELMAkGA1UE
# BhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0
# IFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5IDIwMTAwHhcNMjEwOTMwMTgyMjI1
# WhcNMzAwOTMwMTgzMjI1WjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDCC
# AiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAOThpkzntHIhC3miy9ckeb0O
# 1YLT/e6cBwfSqWxOdcjKNVf2AX9sSuDivbk+F2Az/1xPx2b3lVNxWuJ+Slr+uDZn
# hUYjDLWNE893MsAQGOhgfWpSg0S3po5GawcU88V29YZQ3MFEyHFcUTE3oAo4bo3t
# 1w/YJlN8OWECesSq/XJprx2rrPY2vjUmZNqYO7oaezOtgFt+jBAcnVL+tuhiJdxq
# D89d9P6OU8/W7IVWTe/dvI2k45GPsjksUZzpcGkNyjYtcI4xyDUoveO0hyTD4MmP
# frVUj9z6BVWYbWg7mka97aSueik3rMvrg0XnRm7KMtXAhjBcTyziYrLNueKNiOSW
# rAFKu75xqRdbZ2De+JKRHh09/SDPc31BmkZ1zcRfNN0Sidb9pSB9fvzZnkXftnIv
# 231fgLrbqn427DZM9ituqBJR6L8FA6PRc6ZNN3SUHDSCD/AQ8rdHGO2n6Jl8P0zb
# r17C89XYcz1DTsEzOUyOArxCaC4Q6oRRRuLRvWoYWmEBc8pnol7XKHYC4jMYcten
# IPDC+hIK12NvDMk2ZItboKaDIV1fMHSRlJTYuVD5C4lh8zYGNRiER9vcG9H9stQc
# xWv2XFJRXRLbJbqvUAV6bMURHXLvjflSxIUXk8A8FdsaN8cIFRg/eKtFtvUeh17a
# j54WcmnGrnu3tz5q4i6tAgMBAAGjggHdMIIB2TASBgkrBgEEAYI3FQEEBQIDAQAB
# MCMGCSsGAQQBgjcVAgQWBBQqp1L+ZMSavoKRPEY1Kc8Q/y8E7jAdBgNVHQ4EFgQU
# n6cVXQBeYl2D9OXSZacbUzUZ6XIwXAYDVR0gBFUwUzBRBgwrBgEEAYI3TIN9AQEw
# QTA/BggrBgEFBQcCARYzaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9E
# b2NzL1JlcG9zaXRvcnkuaHRtMBMGA1UdJQQMMAoGCCsGAQUFBwMIMBkGCSsGAQQB
# gjcUAgQMHgoAUwB1AGIAQwBBMAsGA1UdDwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/
# MB8GA1UdIwQYMBaAFNX2VsuP6KJcYmjRPZSQW9fOmhjEMFYGA1UdHwRPME0wS6BJ
# oEeGRWh0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01p
# Y1Jvb0NlckF1dF8yMDEwLTA2LTIzLmNybDBaBggrBgEFBQcBAQROMEwwSgYIKwYB
# BQUHMAKGPmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljUm9v
# Q2VyQXV0XzIwMTAtMDYtMjMuY3J0MA0GCSqGSIb3DQEBCwUAA4ICAQCdVX38Kq3h
# LB9nATEkW+Geckv8qW/qXBS2Pk5HZHixBpOXPTEztTnXwnE2P9pkbHzQdTltuw8x
# 5MKP+2zRoZQYIu7pZmc6U03dmLq2HnjYNi6cqYJWAAOwBb6J6Gngugnue99qb74p
# y27YP0h1AdkY3m2CDPVtI1TkeFN1JFe53Z/zjj3G82jfZfakVqr3lbYoVSfQJL1A
# oL8ZthISEV09J+BAljis9/kpicO8F7BUhUKz/AyeixmJ5/ALaoHCgRlCGVJ1ijbC
# HcNhcy4sa3tuPywJeBTpkbKpW99Jo3QMvOyRgNI95ko+ZjtPu4b6MhrZlvSP9pEB
# 9s7GdP32THJvEKt1MMU0sHrYUP4KWN1APMdUbZ1jdEgssU5HLcEUBHG/ZPkkvnNt
# yo4JvbMBV0lUZNlz138eW0QBjloZkWsNn6Qo3GcZKCS6OEuabvshVGtqRRFHqfG3
# rsjoiV5PndLQTHa1V1QJsWkBRH58oWFsc/4Ku+xBZj1p/cvBQUl+fpO+y/g75LcV
# v7TOPqUxUYS8vwLBgqJ7Fx0ViY1w/ue10CgaiQuPNtq6TPmb/wrpNPgkNWcr4A24
# 5oyZ1uEi6vAnQj0llOZ0dFtq0Z4+7X6gMTN9vMvpe784cETRkPHIqzqKOghif9lw
# Y1NNje6CbaUFEMFxBmoQtB1VM1izoXBm8qGCAtQwggI9AgEBMIIBAKGB2KSB1TCB
# 0jELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1Jl
# ZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEtMCsGA1UECxMk
# TWljcm9zb2Z0IElyZWxhbmQgT3BlcmF0aW9ucyBMaW1pdGVkMSYwJAYDVQQLEx1U
# aGFsZXMgVFNTIEVTTjowODQyLTRCRTYtQzI5QTElMCMGA1UEAxMcTWljcm9zb2Z0
# IFRpbWUtU3RhbXAgU2VydmljZaIjCgEBMAcGBSsOAwIaAxUAQqIfIYljHUbNoY0/
# wjhXRn/sSA2ggYMwgYCkfjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDAN
# BgkqhkiG9w0BAQUFAAIFAOpDhYQwIhgPMjAyNDA3MTgyMDEzNTZaGA8yMDI0MDcx
# OTIwMTM1NlowdDA6BgorBgEEAYRZCgQBMSwwKjAKAgUA6kOFhAIBADAHAgEAAgIB
# AzAHAgEAAgIT1DAKAgUA6kTXBAIBADA2BgorBgEEAYRZCgQCMSgwJjAMBgorBgEE
# AYRZCgMCoAowCAIBAAIDB6EgoQowCAIBAAIDAYagMA0GCSqGSIb3DQEBBQUAA4GB
# AAtv1NjM6zqGRE2nIEMWW0oIDYBTHSkPRMeQWCkZSnRDZ23ONXdkYKEaEN2Di7iv
# lM4cEHUpuketGkYyo3DqXjxVey7FITAY80tEPgZEQw63xVdVsWYGsxB3mlFci+wI
# G0GgjXpHgiRTEX+FGW8iGmpnlg8dQVsNYnCNrNQripX1MYIEDTCCBAkCAQEwgZMw
# fDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1Jl
# ZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMd
# TWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAHajtXJWgDREbEAAQAA
# AdowDQYJYIZIAWUDBAIBBQCgggFKMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRAB
# BDAvBgkqhkiG9w0BCQQxIgQg73RQdEBg3ZdK5rLGCmQhB0rvp9jte6X2JWNiK1iX
# R+MwgfoGCyqGSIb3DQEJEAIvMYHqMIHnMIHkMIG9BCAipaNpYsDvnqTe95Dj1C09
# 020I5ljibrW/ndICOxg9xjCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBD
# QSAyMDEwAhMzAAAB2o7VyVoA0RGxAAEAAAHaMCIEIMQ6lOlBEDTUNo4mPoOme2kO
# F7gJZSgLlhEjWcH9ziJzMA0GCSqGSIb3DQEBCwUABIICAEFP15+2hsiFloNSggEO
# A0C62/K0JQJsY2QCRW6hPyjjuzz7GtZpNNv2ZUyAoyJfL+GtWcRopex7MyAXOJ3a
# tv5WmyPRPBSmtmSuudsGVENb9bQ0N1O0ZFcrC6rB9RD+LOnfvOHSq6eHaJDtM57z
# tySl0LA9kIvXI41osdgid+gyCO5FTGzCYXYQ0yJbWTFu8xsuerSzMIbH0FXD+KXY
# VBhmFx/9K0xxfq7emV1J6iWAtquVanmaCIBezbIZVxuG8TmA8NZw3QHTmCRegat4
# B8kGQORAb2RsRrqgKnarJgT5AmjBkG97bISF8g7whaDC3j1UnTUQTvdtZtH88Scc
# Gl+OmcAWHOHEl181PMpsh0UG2k8xGVKdTIMB7GMV6BRgU3qqTZPF4Wh2HelnpOpM
# wxySE6f79XNxJ0O7nUK48pMuTVU064O4jY9eeXn/8By/R5UGkBx5S0V6rQPf2xEr
# kXuPTggxjKoFqEX9t2Z/9V0VWt/t85Qza5GidnN5RsL/LXy7XvP9s12oW5p0YSyw
# Wkkm61pZL4N4mXvfJmiqPqkIUtp69LcCbqcdGYZGL88Y9A+/BM/9R4IU9ZCbUZOo
# 5yCauZs0DCUpbZmfNgCCwVgywaIGH/7oUflyOw/RInEhizutNX+KInx92Wbct+Um
# ZVvVCDFQrzSknENH3/lA2i43
# SIG # End signature block
