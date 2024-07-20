#!/bin/bash


    pifrun() {
        COLLECTION_VERSION=130
        SCRIPT_VERSION=420
        RootDir="/data/adb/pifs"
        FailedFile="$RootDir/failed.lst"
        ConfirmedDir="$RootDir/confirmed"
        BackupDir="$RootDir/backups"
        UserAgent="Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/115.0"
        ScriptVerUrl="https://raw.githubusercontent.com/TheFreeman193/PIFS/main/SCRIPT_VERSION"
        ColVerUrl="https://raw.githubusercontent.com/TheFreeman193/PIFS/main/JSON/VERSION"
        ScriptUrl="https://raw.githubusercontent.com/TheFreeman193/PIFS/main/pickaprint.sh"
        CollectionUrl="https://codeload.github.com/TheFreeman193/PIFS/zip/refs/heads/main"
        CollectionFile="./PIFS.zip"
        BackupCollectionFile="./PIFS_OLD.zip"
        JsonDir="./JSON"
        ListFile="./pifs_file_list"

        echo "$NL$NL==== PIFS Random Profile/Fingerprint Picker ===="
        echo " Buy me a coffee: https://ko-fi.com/nickbissell"
        echo "============ v4.2 - collection v1.3 ============$NL"

        if [ "$(echo "$*" | grep -e "-[a-z]*[?h]" -e "--help")" ]; then
            echo "Usage: ./pickaprint.sh [-x] [-i] [-c] [-a] [-s] [-r[r]] [-h|?]$NL$NL"
            echo "  -x  Add existing pif.json/custom.pif.json profile to exclusions and pick a print"
            echo "  -xx Add existing pif.json/custom.pif.json profile to exclusions and exit"
            echo "  -i  Add existing pif.json/custom.pif.json profile to confirmed and exit"
            echo "  -c  Use only confirmed profiles from '$ConfirmedDir'"
            echo "  -a  Pick profile from entire JSON directory - overrides \$FORCEABI"
            echo "  -s  Add additional 'SDK_INT'/'*.build.version.sdk' props to profile"
            echo "  -r  Reset - removes all settings/lists/collection (except confirmed directory)"
            echo "  -rr Completely remove - as Reset but also removes confirmed and script file"
            echo "  -h  Display this help message$NL"
            exit 0
        fi

        # Test for root
        if [ ! -d "/data/adb" ]; then
            echo "Can't touch /data/adb - this script needs to run as root on an Android device!"
            exit 1
        fi

        # Needed commands/shell functions
        CMDS="cat
        chmod
        chown
        cp
        curl
        date
        find
        grep
        killall
        mkdir
        mv
        rm
        sed
        unzip
        wget"

        # API/SDK level reference
        ApiLevels="14=34
        13=33
        12=31
        11=30
        10=29
        9=28
        8.1=27
        8.0=26
        7.1 7.1.1 7.1.2=25
        7.0=24
        6.0 6.0.1=23
        5.1 5.1.1=22
        5.0 5.0.1 5.0.2=21
        4.4W 4.4W.1 4.4W.2=20
        4.4 4.4.1 4.4.2 4.4.3 4.4.4=19
        4.3 4.3.1=18
        4.2 4.2.1 4.2.2=17
        4.1 4.1.1 4.1.2=16
        4.0.3 4.0.4=15
        4.0 4.0.1 4.0.2=14
        3.2 3.2.1 3.2.2 3.2.4 3.2.6=13
        3.1=12
        3.0=11
        2.3.3 2.3.4 2.3.5 2.3.6 2.3.7=10
        2.3 2.3.1 2.3.2=9
        2.2 2.2.1 2.2.2 2.2.3=8
        2.1=7
        2.0.1=6
        2.0=5
        1.6=4
        1.5=3
        1.1=2
        1.0=1"

        ROOTMODE=""

        if [ "$(command -v /data/adb/magisk/busybox)" ]; then
            BBOX="/data/adb/magisk/busybox"
            ROOTMODE="Magisk"
        elif [ "$(command -v /data/adb/ksu/bin/busybox)" ]; then
            BBOX="/data/adb/ksu/bin/busybox"
            ROOTMODE="KSU"
        elif [ "$(command -v /sbin/.magisk/busybox/busybox)" ]; then
            BBOX="/sbin/.magisk/busybox/busybox"
            ROOTMODE="Magisk"
        elif [ "$(command -v /debug_ramdisk/.magisk/busybox/busybox)" ]; then
            BBOX="/debug_ramdisk/.magisk/busybox/busybox"
            ROOTMODE="KSU"
        else
            LastHope="$(find /system \( -type f -o -type l \) -name busybox 2>/dev/null | head -n 1)"
            [ -z "$LastHope" ] && LastHope="$(find /data \( -type f -o -type l \) -name busybox 2>/dev/null | head -n 1)"
            [ -z "$LastHope" ] && [ -d "/bin" ] && LastHope="$(find /bin \( -type f -o -type l \) -name busybox 2>/dev/null | head -n 1)"
            [ -z "$LastHope" ] && [ -d "/usr" ] && LastHope="$(find /usr \( -type f -o -type l \) -name busybox 2>/dev/null | head -n 1)"
            [ -z "$LastHope" ] && [ -d "/sbin" ] && LastHope="$(find /sbin \( -type f -o -type l \) -name busybox 2>/dev/null | head -n 1)"
            [ -n "$LastHope" ] && BBOX="$LastHope" || BBOX=""
        fi

        if [ -n "$BBOX" ]; then
            # Use busybox
            echo "    Using busybox '$BBOX'"
            for acmd in $($BBOX --list | grep '[a-z0-9]'); do
                alias $acmd="$BBOX $acmd"
            done
        else
            for acmd in "${CMDS[@]}"; do
                # Don't touch if command/builtin exists
                [ "$(command -v "$acmd")" ] && continue
                # Find bin paths
                tgt="$(find /system \( -type f -o -type l \) -name $acmd -print 2>/dev/null | head -n 1)"
                [ -z "$tgt" ] && tgt="$(find /data \( -type f -o -type l \) -name $acmd -print 2>/dev/null | head -n 1)"
                [ -z "$tgt" ] && tgt="$(find /bin \( -type f -o -type l \) -name $acmd -print 2>/dev/null | head -n 1)"
                [ -z "$tgt" ] && tgt="$(find /usr \( -type f -o -type l \) -name $acmd -print 2>/dev/null | head -n 1)"
                [ -z "$tgt" ] && tgt="$(find /sbin \( -type f -o -type l \) -name $acmd -print 2>/dev/null | head -n 1)"
                if [ -n "$tgt" ]; then
                    alias $acmd="$tgt"
                elif [ "$acmd" != "curl" -a "$acmd" != "wget" ]; then
                    echo "ERROR: Couldn't find bin path for command '$acmd'"
                    exit 2
                fi
            done
            if ! [ "$(command -v wget)" -o "$(command -v curl)" ]; then
                echo "ERROR: Couldn't find bin path for 'curl' or 'wget'"
                exit 3
            fi
        fi

        # Check if interactive
        INTERACTIVE=0
        echo "$0" | grep 'pickaprint\.sh$' >/dev/null && INTERACTIVE=1 && cd "$(dirname "$0")"

        # Reset/remove if requested with -r
        RESET_CONFIRM="/data/adb/pifs/CONFIRM_RESETREMOVE"
        if [ "$(echo "$*" | grep -e "-[a-z]*r")" ]; then
            if [ ! -f "$RESET_CONFIRM" ]; then
                echo "${NL}Running with -r or -rr will permanently delete PIFS settings. Run again to confirm."
                touch "$RESET_CONFIRM"
                exit 0
            fi
            echo "${NL}Removing all PIFS settings, lists, and local collection..."
            [ -d "$JsonDir" ] && rm -r "$JsonDir"
            [ -f "$CollectionFile" ] && rm "$CollectionFile"
            [ -f "$BackupCollectionFile" ] && rm "$BackupCollectionFile"
            [ -d "$RootDir/failed" ] && rm -r "$RootDir/failed"
            [ -d "$BackupDir" ] && rm -r "$BackupDir"
            [ -f "$FailedFile" ] && rm "$FailedFile"
            if [ "$(echo "$*" | grep -e "-[a-z]*rr")" ]; then
                echo "Removing confirmed directory and pickaprint.sh script..."
                [ -d "$ConfirmedDir" ] && rm -r "$ConfirmedDir"
                [ -d "$RootDir" ] && [ "$(ls "$RootDir")" = "" ] && rm -r "$RootDir"
                if [ "$INTERACTIVE" -eq 1 ]; then
                    [ -f "$0" ] && rm -f "$0"
                else
                    [ -f "./pickaprint.sh" ] && rm -f "./pickaprint.sh"
                fi
            fi
            rm -f "$RESET_CONFIRM"
            exit 0
        fi
        [ -f "$RESET_CONFIRM" ] && rm -f "$RESET_CONFIRM"

        # Update check, disable with 'export PIFSNOUPDATE=1'
        if [ -z "$PIFSNOUPDATE" ] && [ ! "$(echo "$*" | grep -e "-[a-z]*i" -e "-[a-z]*xx")" ]; then
            echo "${NL}Checking for new version...${NL}    Tip: You can disable this check with 'export PIFSNOUPDATE=1'"

            if [ "$(command -v wget)" ]; then
                ONLINEVERSION="$(wget -O - -U "$UserAgent" --no-check-certificate "$ScriptVerUrl" 2>/dev/null)"
                ONLINECOLLECTIONVERSION="$(wget -O - -U "$UserAgent" --no-check-certificate "$ColVerUrl" 2>/dev/null)"
            elif [ "$(command -v curl)" ]; then
                ONLINEVERSION="$(curl -k -A "$UserAgent" "$ScriptVerUrl" 2>/dev/null)"
                ONLINECOLLECTIONVERSION="$(curl -k -A "$UserAgent" "$ColVerUrl" 2>/dev/null)"
            else
                echo "WARNING: Couldn't find wget or curl to check for latest version."
            fi
            if [ -n "$ONLINEVERSION" ] && [ "$ONLINEVERSION" -gt $SCRIPT_VERSION ]; then
                echo "$NL================================================"
                echo "A newer version of the script is available.${NL}Download with:$NL"
                if [ "$ROOTMODE" == "Magisk" ]; then
                    echo "/data/adb/magisk/busybox wget -O pickaprint.sh \"$ScriptUrl\""
                elif [ "$ROOTMODE" == "KSU" ]; then
                    echo "/data/adb/ksu/bin/busybox wget -O pickaprint.sh \"$ScriptUrl\""
                else
                    echo "curl -o pickaprint.sh \"$ScriptUrl\""
                fi
                echo "================================================$NL"
            fi
            [ -n "$ONLINECOLLECTIONVERSION" ] && COLLECTION_VERSION=$ONLINECOLLECTIONVERSION
            if [ -d "$JsonDir" ] && [ ! -f "$JsonDir/VERSION" -o $(cat "$JsonDir/VERSION") -lt $COLLECTION_VERSION ]; then
                echo "${NL}There is an updated collection available. Moving existing to $BackupCollectionFile..."
                rm -r "$JsonDir" # Remove old unpacked collection
                [ -f "$CollectionFile" ] && mv "$CollectionFile" "$BackupCollectionFile" # Move old repo archive
                # Triggers re-download below
            fi
        else
            [ -n "$PIFSNOUPDATE" ] && echo "${NL}\$PIFSNOUPDATE is set - offline mode"
        fi

        # Test if JSON dir exists
        if [ ! -d "$JsonDir" ] && [ ! "$(echo "$*" | grep -e "-[a-z]*i" -e "-[a-z]*xx")" ]; then
            # Check if repo ZIP exists
            if [ ! -f "$CollectionFile" ]; then
                if [ -n "$PIFSNOUPDATE" ]; then
                    echo "Neither collection '$JsonDir' nor archive '$CollectionFile' found but \$PIFSNOUPDATE is set. Stopping."
                    exit 0
                fi
                # Download repo archive
                echo "${NL}Downloading profile/fingerprint collection from GitHub..."
                # Handle many environments; usually curl or webget exist somewhere
                if [ "$(command -v wget)" ]; then
                    wget -O "$CollectionFile" --no-check-certificate "$CollectionUrl" >/dev/null 2>&1
                elif [ ! -f "$CollectionFile" ] && [ "$(command -v curl)" ]; then
                    curl -ko "$CollectionFile" "$CollectionUrl" >/dev/null 2>&1
                else
                    echo "WARNING: Couldn't find wget or curl to download the repository."
                fi
                if [ ! -f "$CollectionFile" ]; then
                    if [ -f "$BackupCollectionFile" ]; then
                        mv "$BackupCollectionFile" "$CollectionFile" # Restore outdated copies
                        echo "Restored outdated version from $BackupCollectionFile"
                    else
                        echo "ERROR: Couldn't get repo. You'll have to download manually from https://github.com/TheFreeman193/PIFS"
                        exit 4
                    fi
                fi
            fi
            if [ ! -d "$JsonDir" ]; then
                if [ ! -f "$CollectionFile" ]; then
                    echo "ERROR: Repository archive $CollectionFile couldn't be downloaded"
                    exit 5
                fi
                # Unzip repo archive
                echo "${NL}Extracting profiles/fingerprints from $CollectionFile..."
                unzip -qo "$CollectionFile" -x .git* -x README.md -x LICENSE
                # Copy JSON files
                mv ./PIFS-main/JSON .
                if [ ! -f "./pickaprint.sh" ]; then
                    mv ./PIFS-main/pickaprint.sh .
                fi
                rm -r ./PIFS-main
            fi
        fi

        if [ -f "./pickaprint.sh" ]; then
            chown root:root ./pickaprint.sh
            chmod 755 ./pickaprint.sh
        fi

        [ ! -d "$RootDir" ] && mkdir "$RootDir"

        # Migrate old versions
        [ ! -d "$BackupDir" ] && [ -d "/data/adb/oldpifs" ] && mv "/data/adb/oldpifs" "$BackupDir"
        [ ! -f "$FailedFile" ] && [ -f "/data/adb/failedpifs.lst" ] && mv "/data/adb/failedpifs.lst" "$FailedFile"

        [ ! -d "$ConfirmedDir" ] && mkdir "$ConfirmedDir"
        [ ! -d "$BackupDir" ] && mkdir "$BackupDir"
        [ ! -f "$FailedFile" ] && touch "$FailedFile"

        # Check which module installed, fall back to data/adb/pif.json
        echo "${NL}Looking for installed PIF module..."
        Author=$(cat /data/adb/modules/playintegrityfix/module.prop | grep "author=" | sed -r 's/author=([^ ]+) ?.*/\1/gi')
        if [ -z "$Author" ]; then
            echo "    Can't detect an installed PIF module! Will use /data/adb/pif.json"
            Target="/data/adb/pif.json"
        elif [ "$Author" == "chiteroman" ]; then
            echo "    Detected chiteroman module. Will use /data/adb/pif.json"
            Target="/data/adb/pif.json"
        elif [ "$Author" == "osm0sis" ]; then
            echo "    Detected osm0sis module. Will use /data/adb/modules/playintegrityfix/custom.pif.json"
            Target="/data/adb/modules/playintegrityfix/custom.pif.json"
        else
            echo "    PIF module found but not recognized! Will use /data/adb/pif.json"
            Target="/data/adb/pif.json"
        fi

        if [ "$(echo "$*" | grep -e "-[a-z]*[ix]")" ] && [ -f "$Target" ]; then
            TargetName="$(cat "$Target" | grep '"FINGERPRINT":' | sed -r 's/.*"FINGERPRINT" *: *"(.+)".*/\1.json/ig;s/[^a-z0-9_.\-]/_/gi')"
            [ -z "$TargetName" ] && TargetName="$(date +%Y%m%dT%H%M%S).json"
        fi

        # Add to confirmed and exit if requested with -i
        if [ "$(echo "$*" | grep -e "-[a-z]*i")" ]; then
            if [ -f "$Target" ] && [ -n "$TargetName" ]; then
                echo "${NL}Copying '$Target' to '$ConfirmedDir/$TargetName'..."
                cp "$Target" "$ConfirmedDir/$TargetName"
            else
                echo "Profile '$Target' doesn't exist - can't add it to confirmed"
            fi
            exit 0
        fi

        # Add exclusion from current PIF fingerprint if requested with -x (and exit with -xx)
        if [ "$(echo "$*" | grep -e "-[a-z]*x")" ]; then
            if [ -f "$Target" ] && [ -n "$TargetName" ]; then
                echo "${NL}Adding profile '$TargetName' to failed list..."
                echo "$TargetName" >> "$FailedFile"
                rm "$Target"
            else
                echo "Profile '$Target' doesn't exist - nothing to exclude"
            fi
            [ "$(echo "$*" | grep -e "-[a-z]*xx")" ] && exit 0
        fi

        # Clean failed file
        sed -ir "/^ *$/d" "$FailedFile"
        sort -uo "$FailedFile" "$FailedFile"

        # Pick from all profiles if requested with -a
        FList=""
        SearchPath=""
        if [ "$(echo "$*" | grep -e "-[a-z]*a")" ]; then
            echo "${NL}-a present. Using entire JSON directory."
            FList="$(find "$JsonDir" -type f -name "*.json" | grep -vFf "$FailedFile")"
            if [ -z "$FList" ]; then
                echo "ERROR: No profiles/fingerprints found in '$JsonDir' that aren't excluded"
                exit 6
            fi
            SearchPath="$JsonDir"
        fi

        # Pick only from confirmed profiles if requested with -c
        CONFIRMEDONLY=0
        if [ -z "$SearchPath" ] && [ "$(echo "$*" | grep -e "-[a-z]*c")" ]; then
            CONFIRMEDONLY=1
            if [ -d "$ConfirmedDir" ]; then
                FList=$(find "$ConfirmedDir" -type f -name "*.json" | grep -vFf "$FailedFile")
            else
                echo "ERROR: -c argument present but '$ConfirmedDir' directory doesn't exist"
                exit 10
            fi
            if [ -n "$FList" ]; then
                SearchPath="$ConfirmedDir"
            else
                echo "ERROR: No profiles/fingerprints found in '$ConfirmedDir' that aren't excluded"
                exit 10
            fi
        fi

        # Allow overrides, enable with 'export FORCEABI="<abi_list>"'
        if [ -z "$SearchPath" ] && [ -n "$FORCEABI" ]; then
            if [ -d "$JsonDir/$FORCEABI" ]; then
                echo "${NL}\$FORCEABI is set, will only pick profile from '${FORCEABI}'"
                # Get files in overridden dir
                FList=$(find "$JsonDir/$FORCEABI" -type f -name "*.json" | grep -vFf "$FailedFile")
            else
                echo "${NL}ERROR: \$FORCEABI set but dir '$FORCEABI' doesn't exist in $JsonDir"
                exit 7
            fi
            if [ -n "$FList" ]; then
                SearchPath="$JsonDir/$FORCEABI"
            else
                echo "${NL}ERROR: No profiles/fingerprints found in '$JsonDir/$FORCEABI' that aren't excluded"
                exit 7
            fi
        fi

        if [ -z "$SearchPath" ]; then
            # Get compatible ABIs from build props
            echo "${NL}Detecting device ABI list..."
            ABIList="$(getprop | grep -E '\[ro\.product\.cpu\.abilist\]: \[' | sed -r 's/\[[^]]+\]: \[(.+)\]/\1/g')"
            if [ -z "$ABIList" ]; then # Old devices had single string prop for this
                ABIList="$(getprop | grep -E '\[ro\.product\.cpu\.abi\]: \[' | sed -r 's/\[[^]]+\]: \[(.+)\]/\1/g')"
            fi
            # Get files from detected dir, else try all dirs
            if [ -n "$ABIList" ]; then
                echo "    Will use profile/fingerprint with ABI list '${ABIList}'"
                FList=$(find "$JsonDir/${ABIList}" -type f -name "*.json" | grep -vFf "$FailedFile")
                if [ -n "$FList" ]; then
                    SearchPath="$JsonDir/$ABIList"
                else
                    echo "WARNING: No profiles/fingerprints found for ABI list '$ABIList'"
                fi
            else
                echo "WARNING: Couldn't detect ABI list."
            fi
        fi

        # Ensure we don't get empty lists, fall back to all dirs
        if [ -z "$SearchPath" ]; then
            echo "    Will use profile/fingerprint from entire $JsonDir directory."
            FList=$(find "$JsonDir" -type f -name "*.json" | grep -vFf "$FailedFile")
            if [ -n "$FList" ]; then
                SearchPath="$JsonDir"
            fi
        fi

        if [ -z "$SearchPath" ]; then
            echo "ERROR: Couldn't find any profiles/fingerprints. Is the $PWD/JSON directory empty?"
            exit 8
        fi

        while true; do

            find "$SearchPath" -type f -name "*.json" | grep -vFf "$FailedFile" > "$ListFile"

            # Count JSON files in list
            FCount=0
            [ -f "$ListFile" ] && FCount="$(sed -n '$=' "$ListFile")"
            if [ -z "$FCount" ] || [ "$FCount" -eq 0 ]; then
                echo "${NL}ERROR: No profiles/fingerprints found in '$SearchPath' that aren't excluded"
                [ -f "$ListFile" ] && rm -f "$ListFile"
                exit 9
            fi

            # Get random device profile from file list excluding previously failed
            [ "$CONFIRMEDONLY" -eq 1 ] && echo "${NL}Picking a random confirmed profile/fingerprint..." \
            || echo "${NL}Picking a random profile/fingerprint..."
            RandFPNum=$((1 + ($RANDOM * 2) % $FCount)) # Get a random index from the list
            RandFP="$(sed -r "${RandFPNum}q;d" "$ListFile")" # Get path of random index
            rm -f "$ListFile"
            FName=$(basename "$RandFP") # Resolve filename

            # Back up old profiles
            if [ -f "${Target}" ]; then
                if [ ! -d "$BackupDir" ]; then
                    mkdir "$BackupDir"
                fi
                BackupFName="$(cat "$Target" | grep '"FINGERPRINT":' | sed -r 's/.*"FINGERPRINT" *: *"(.+)".*/\1.json/ig;s/[^a-z0-9_.\-]/_/gi')"
                [ -z "$BackupFName" ] && BackupFName="$(date +%Y%m%dT%H%M%S).json"
                if [ "$(echo "$BackupFName" | grep -xFf "$FailedFile")" ]; then
                    echo "${NL}Profile '$BackupFName' is in failed list - won't back up"
                    rm "$Target"
                elif [ ! -f "$BackupDir/$BackupFName" ]; then
                    echo "${NL}Backing up old profile to '$BackupDir'..."
                    mv "${Target}" "$BackupDir/$BackupFName"
                fi
                echo "${NL}    Old Profile: '${BackupFName/ /}'"
            fi

            echo "${NL}    New Profile: '${FName/ /}'"

            # Copy random FP
            echo "${NL}Copying profile to ${Target}..."
            cp "${RandFP}" "${Target}"

            # Alternate key names
            if [ "$Author" = "chiteroman" ]; then
                echo "    Converting pif.json to chiteroman format..."
                sed -i -r 's/("DEVICE_INITIAL_SDK_INT": *)(""|"?0"?|null)/\1"25"/ig
                s/("DEVICE_INITIAL_SDK_INT": )([0-9]+)/\1"\2"/ig
                s/"DEVICE_INITIAL_SDK_INT":/"FIRST_API_LEVEL":/ig
                s/"ID":/"BUILD_ID":/ig
                /^[[:space:]]*"\*.+$/d
                /^[[:space:]]*"[^"]*\..+$/d
                /^[[:space:]]*"(RELEASE_OR_CODENAME|INCREMENTAL|TYPE|TAGS|SDK_INT|RELEASE)":.+$/d
                /^[[:space:]]*$/d' "$Target"
            else
                sed -i -r 's/("(DEVICE_INITIAL_SDK_INT|\*api_level)": *)(""|"?0"?|null)/\1"25"/ig' "$Target"
            fi

            # Remove any trailing terminal comma
            LineCount="$(sed -n '$=' "$Target")"
            if [ "$LineCount" -gt 2 ]; then
                prefix="$(cat "$Target" | head -n $((LineCount - 2)))"
                replaced="$(cat "$Target" | head -n $((LineCount - 1)) | tail -n 1 | sed -r 's/^([[:space:]]*"[^"]+":[[:space:]]*.+),[[:space:]]*$/\1/')"
                suffix="$(cat "$Target" | tail -n 1)"
                echo "${prefix}${NL}${replaced}${NL}${suffix}" > "$Target"
            fi

            # Restore SDK level props if requested
            if [ "$(echo "$*" | grep -e "-[a-z]*s")" ]; then
                RELEASE="$(cat "$Target" | grep '"FINGERPRINT":' | sed -r 's/ *"FINGERPRINT": *"[^\/]*\/[^\/]*\/[^\/:]*:([^\/]+).*$/\1/g')"
                SDKLevel="$(echo "$ApiLevels" | grep "$RELEASE" | sed -r 's/.+=//g')"
                sed -i -r -e "/\{/a\ \ \"SDK_INT\": \"$SDKLevel\"," -e "/\{/a\ \ \"*.build.version.sdk\": \"$SDKLevel\"," "$Target"
            fi

            # Kill GMS unstable to force new values
            echo "${NL}Killing GMS unstable process..."
            killall com.google.android.gms.unstable >/dev/null 2>&1

            echo "${NL}===== Test your Play Integrity now =====$NL"

            if [ "$INTERACTIVE" -eq 1 ]; then
                INPUT=""
                while true; do
                    echo -n "${NL}Did the profile pass both BASIC and DEVICE integrity? (y/n/c): "
                    read -r INPUT
                    case "$INPUT" in
                        y)
                            if [ "$CONFIRMEDONLY" -ne 1 ]; then
                                echo "Copying '$FName' to '$ConfirmedDir'"
                                echo "${NL}Tip: You can use './pickaprint.sh -c' to try only confirmed profiles"
                                cp "$RandFP" "$ConfirmedDir"
                            fi
                            break 2
                        ;;
                        n)
                            echo "Excluding '$FName'"
                            echo "$FName" >> "$FailedFile"
                            sed -ir "/^ *$/d" "$FailedFile"
                            sort -uo "$FailedFile" "$FailedFile"
                            rm "$Target"
                            [ -f "$ConfirmedDir/$FName" ] && rm "$ConfirmedDir/$FName"
                            break
                        ;;
                        c)
                            echo "Exiting immediately."
                            exit 0
                        ;;
                        *)
                            echo "Invalid input"
                        ;;
                    esac
                done
            else
                echo "NOTE: As the script was piped or dot-sourced, the interactive mode can't work."
                echo "If this profile didn't work, run the script locally with -x using:"
                echo "    ./pickaprint.sh -x"
                echo "Or manually add the profile to the failed list:"
                echo "    echo '$FName' >> '$FailedFile'"
                echo "${NL}If the profile works, you can copy it to the confirmed directory with:"
                echo "    cp '$RandFP' '$ConfirmedDir'"
                echo "To use only confirmed profiles, run the script with -c:"
                echo "    ./pickaprint.sh -c"
                break
            fi

        done

        echo "${NL}Finished!"
    } &>/dev/null

pifrun
clear



echo -e "========== BYPASS LAZZZ.................. ==========="
dir="/system/build.prop"
random_number() {
    echo $((RANDOM % 100))
}

random_string() {
    tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 8
}

random_date() {
    echo "2017-$(random_number)-$(random_number)"
}

mount -o rw,remount /
mount -o rw,remount /dev/block/platform/soc/7824900.sdhci/by-name/system
settings put global airplane_mode_on 1

clear_android_data(){
    echo "Clearing Android Data..."
    killall com.google.android.gms.unstable >/dev/null 2>&1
    am kill com.lazada.android
    am kill com.android.chrome
    am kill com.evo.browser
    am kill mark.via.gp
    am kill com.brave.browser
    am kill android.ext.services
    am kill com.google.android.apps.docs
    am kill com.google.android.apps.googleassistant
    am kill com.android.download
    am kill com.android.tools
    am kill com.android.webview
    am kill com.android.defcontainer
    am force-stop com.lazada.android
    am force-stop com.android.chrome
    pm clear com.lazada.android
    pm clear com.android.chrome
    pm clear com.brave.browser
    am force-stop com.android.phone
    am force-stop com.android.dialer
    am force-stop com.android.smspush
    am force-stop com.android.ime
    am force-stop android.ext.services
    am force-stop com.google.android.apps.docs
    am force-stop com.google.android.apps.googleassistant
    am force-stop com.android.download
    am force-stop com.android.tools
    am force-stop com.android.webview
    am force-stop com.android.defcontainer
    am force-stop com.lazada.android
    am force-stop com.microsoft.office.outlook
    am force-stop com.ss.android.ugc.trill
    am force-stop mark.via.gp
    am force-stop com.evo.browser
    am force-stop com.lazada.android
    pm clear com.android.dialer
    pm clear com.whatsapp
    pm clear com.android.dialer
    pm clear com.lazada.android
    pm clear com.microsoft.office.outlook
    pm clear com.ss.android.ugc.trill
    pm clear com.google.android.gmsa
    pm clear com.google.android.gsfa
    rm -r /data/data/com.lazada.android/*
    rm -r /data/data/com.lazada.android/*
    rm -r /storage/emulated/0/android/*
    rm -r /storage/emulated/0/data
    rm -r /storage/emulated/0/Alarm
    rm -r /storage/emulated/0/Audiobooks
    rm -r /storage/emulated/0/DCIM
    rm -r /storage/emulated/0/Document
    rm -r /storage/emulated/0/MT2
    rm -r /storage/emulated/0/Movies
    rm -r /storage/emulated/0/Pictures
    rm -r /storage/emulated/0/android/data/*
    rm -r /storage/emulated/0/Music
    rm -r /data/system/graphicsstats/*
    rm -r /data/system/package_cache/*
    rm -r /storage/BA23-1D05/android
} &>/dev/null

# Define random values
echo "Generating random values..."
angka3=$(random_number)
number1=$(random_number)
number=$(random_number)
user=$(random_string)
fpp="Xiaomi/POCO F3/$user:user/$user/$user/release-keys"
n2="POCO F3"
n3="alioth"
n4="11"
n5="RP1A.200720.012"
n6=$(random_number)
modelok="POCO F3"
n1="Xiaomi"
host=$(random_string)
bl1=$(random_number)
hrf21=$(random_number)
uds=$(random_number)
hrf22=$(random_number)
hrf31=$(random_number)
lr21=$(random_number)
hrf11=$(random_number)
hrf23=$(random_number)
hrf24=$(random_number)
sj11=$(random_number)
hrf32=$(random_number)
brnd="$(head -5 /dev/urandom | tr -cd 'A-Z' | cut -c -6)$(head -1 /dev/urandom | tr -cd '1-9' | cut -c -2)"


# Backup the original build.prop
cp $dir ${dir}.bak

echo "ro.build.version.security_index=$angka3" >> $dir
echo "ro.build.version.security_patch=$(random_date)" >> $dir
echo "ro.build.version.codenames=$user" >> $dir
echo "ro.build.version.preview_sdk=$angka3" >> $dir
echo "ro.build.fingerprint=$fpp" >> $dir
echo "ro.bootimage.build.fingerprint=$fpp" >> $dir
echo "ro.system.build.fingerprint=$fpp" >> $dir
echo "ro.vendor.build.fingerprint=$fpp" >> $dir
echo "ro.product.build.fingerprint=$fpp" >> $dir
echo "ro.odm.build.fingerprint=$fpp" >> $dir
echo "ro.system_ext.build.fingerprint=$fpp" >> $dir
echo "ro.build.description=$n2-user $n4 $n5 $n6 release-keys" >> $dir
echo "ro.product.name=$n2" >> $dir
echo "ro.product.system.name=$n2" >> $dir
echo "ro.product.vendor.name=$n2" >> $dir
echo "ro.product.product.name=$n2" >> $dir
echo "ro.product.odm.name=$n2" >> $dir
echo "ro.product.system_ext.name=$n2" >> $dir
echo "ro.product.device=$n3" >> $dir
echo "ro.build.product=$n3" >> $dir
echo "ro.product.system.device=$n3" >> $dir
echo "ro.product.vendor.device=$n3" >> $dir
echo "ro.product.product.device=$n3" >> $dir
echo "ro.product.odm.device=$n3" >> $dir
echo "ro.product.system_ext.device=$n3" >> $dir
echo "ro.build.version.release=$n4" >> $dir
echo "ro.system.build.version.release=$n4" >> $dir
echo "ro.vendor.build.version.release=$n4" >> $dir
echo "ro.product.build.version.release=$n4" >> $dir
echo "ro.odm.build.version.release=$n4" >> $dir
echo "ro.system_ext.build.version.release=$n4" >> $dir
echo "ro.build.id=$n5" >> $dir
echo "ro.system.build.id=$n5" >> $dir
echo "ro.vendor.build.id=$n5" >> $dir
echo "ro.product.build.id=$n5" >> $dir
echo "ro.odm.build.id=$n5" >> $dir
echo "ro.system_ext.build.id=$n5" >> $dir
echo "ro.build.version.incremental=$n6" >> $dir
echo "ro.system.build.version.incremental=$n6" >> $dir
echo "ro.vendor.build.version.incremental=$n6" >> $dir
echo "ro.product.build.version.incremental=$n6" >> $dir
echo "ro.odm.build.version.incremental=$n6" >> $dir
echo "ro.system_ext.build.version.incremental=$n6" >> $dir
echo "ro.build.display.id=POCO$bl1$hrf21$uds$hrf22$hrf31$lr21$hrf11$uds$hrf23$uds$hrf24$sj11$hrf24$uds$hrf32" >> $dir
echo "ro.build.version.sdk=30" >> $dir
echo "ro.system.build.version.sdk=30" >> $dir
echo "ro.vendor.build.version.sdk=30" >> $dir
echo "ro.product.build.version.sdk=30" >> $dir
echo "ro.odm.build.version.sdk=30" >> $dir
echo "ro.system_ext.build.version.sdk=30" >> $dir
echo "ro.product.manufacturer=$n1" >> $dir
echo "ro.product.system.manufacturer=$n1" >> $dir
echo "ro.product.vendor.manufacturer=$n1" >> $dir
echo "ro.product.product.manufacturer=$n1" >> $dir
echo "ro.product.odm.manufacturer=$n1" >> $dir
echo "ro.product.system_ext.manufacturer=$n1" >> $dir
echo "ro.product.model=$modelok" >> $dir
echo "ro.product.system.model=$modelok" >> $dir
echo "ro.product.vendor.model=$modelok" >> $dir
echo "ro.product.product.model=$modelok" >> $dir
echo "ro.product.odm.model=$modelok" >> $dir
echo "ro.product.system_ext.model=$modelok" >> $dir
echo "ro.build.type=user" >> $dir
echo "ro.build.user=dpi" >> $dir
echo "ro.build.host=$host$angka3$host$angka3" >> $dir
echo "ro.build.tags=release-keys" >> $dir
echo "ro.build.flavor=$n2-user" >> $dir
echo "ro.product.brand=" >> $dir
echo "ro.product.system.brand=" >> $dir
echo "ro.product.vendor.brand=" >> $dir
echo "ro.product.product.brand=" >> $dir
echo "ro.product.odm.brand=" >> $dir
echo "ro.product.system_ext.brand=" >> $dir
echo "ro.build.system_root_image=true" >> $dir
echo "ro.build.characteristics=phone" >> $dir


echo "SUKSES MENYIMPAN build."
sleep 1

customemodul(){
                     echo $(head -3 /dev/urandom | tr -cd 'A-Z' | cut -c -4)
} &>/dev/null

xnxx(){
        echo "menginstall..."
        mount -o rw,remount /
        sleep 0.2
        echo "________________________slow down_______________________"
    	sleep 1   
	  	   # d
		sed -i '/ro.product.brand=/d' /data/adb/modules/playintegrityfix/system.prop
		sed -i '/ro.product.system.brand=/d' /data/adb/modules/playintegrityfix/system.prop
		sed -i '/ro.product.vendor.brand=/d' /data/adb/modules/playintegrityfix/system.prop
		sed -i '/ro.product.product.brand=/d' /data/adb/modules/playintegrityfix/system.prop
		sed -i '/ro.product.product.brand=/d' /data/adb/modules/playintegrityfix/system.prop
		sed -i '/ro.product.odm.brand=/d' /data/adb/modules/playintegrityfix/system.prop
        sed -i '/ro.product.system_ext.brand=/d' /data/adb/modules/playintegrityfix/system.prop
        
		# Tulis ro. di txt
	    echo -e "${V}###################### NGOPI  DULU #####################${N}"
		sleep 5
        
		#clonebrand
		echo -e "ro.product.system.brand=$(customemodul)" >> /data/local/tmp/build.txt
		grep -i "ro.product.system.brand=/*" /data/local/tmp/build.txt >> /data/local/tmp/system2.txt
		grep -i "ro.product.system.brand=/*" /data/local/tmp/build.txt >> /data/local/tmp/systemext.txt
		grep -i "ro.product.system.brand=/*" /data/local/tmp/build.txt >> /data/local/tmp/vendor2.txt
		grep -i "ro.product.system.brand=/*" /data/local/tmp/build.txt >> /data/local/tmp/odm.txt
		grep -i "ro.product.system.brand=/*" /data/local/tmp/build.txt >> /data/local/tmp/product.txt
		grep -i "ro.product.system.brand=/*" /data/local/tmp/build.txt >> /data/local/tmp/vendor.txt
		#rename
		sed -i 's/ro.product.system.brand=/ro.product.brand=/' /data/local/tmp/system2.txt
		sed -i 's/ro.product.system.brand=/ro.product.vendor.brand=/' /data/local/tmp/systemext.txt
		sed -i 's/ro.product.system.brand=/ro.product.product.brand=/' /data/local/tmp/vendor2.txt
		sed -i 's/ro.product.system.brand=/ro.product.odm.brand=/' /data/local/tmp/odm.txt
		sed -i 's/ro.product.system.brand=/ro.product.system_ext.brand=/' /data/local/tmp/product.txt
		#kembalikan
		grep -i "ro.product.brand=/*" /data/local/tmp/system2.txt >> /data/local/tmp/build.txt
		grep -i "ro.product.vendor.brand=/*" /data/local/tmp/systemext.txt >> /data/local/tmp/build.txt
		grep -i "ro.product.product.brand=/*" /data/local/tmp/vendor2.txt >> /data/local/tmp/build.txt
		grep -i "ro.product.odm.brand=/*" /data/local/tmp/odm.txt >> /data/local/tmp/build.txt
		grep -i "ro.product.system_ext.brand=/*" /data/local/tmp/product.txt >> /data/local/tmp/build.txt
		
		
        # Copy ro. ke hideprop
		echo   "${Y}_________________________success________________________${N}"
		sleep 1
		#brand
		grep -i "ro.product.brand=/*" /data/local/tmp/build.txt >> /data/adb/modules/playintegrityfix/system.prop
		grep -i "ro.product.system.brand=/*" /data/local/tmp/build.txt >> /data/adb/modules/playintegrityfix/system.prop
		grep -i "ro.product.vendor.brand=/*" /data/local/tmp/build.txt >> /data/adb/modules/playintegrityfix/system.prop
		grep -i "ro.product.product.brand=/*" /data/local/tmp/build.txt >> /data/adb/modules/playintegrityfix/system.prop
		grep -i "ro.product.product.brand=/*" /data/local/tmp/build.txt >> /data/adb/modules/playintegrityfix/system.prop
		grep -i "ro.product.odm.brand=/*" /data/local/tmp/build.txt >> /data/adb/modules/playintegrityfix/system.prop
		grep -i "ro.product.system_ext.brand=/*" /data/local/tmp/build.txt >> /data/adb/modules/playintegrityfix/system.prop
		
        sleep 0.2
		echo "reboot the device to continues"
		sleep 5
        echo ""
		sleep 1
		echo ""
		sleep 1
		rm -f /data/local/tmp/build.txt
		rm -f /data/local/tmp/system2.txt
		rm -f /data/local/tmp/vendor.txt
		rm -f /data/local/tmp/vendor2.txt
		rm -f /data/local/tmp/systemext.txt
		rm -f /data/local/tmp/product.txt
		rm -f /data/local/tmp/odm.txt
		
        mount -o ro,remount /
		clear

        FURANDOM=$(head -3 /dev/urandom | tr -cd 'A-Z' | cut -c -1)$(head -3 /dev/urandom | tr -cd 'aeiou' | cut -c -1)$(head -3 /dev/urandom | tr -cd 'bcdfghjklmnpqrstvwxyz' | cut -c -1)$(head -3 /dev/urandom | tr -cd 'aeiou' | cut -c -1)$(head -3 /dev/urandom | tr -cd 'bcdfghjklmnpqrstvwxyz' | cut -c -1)$(head -3 /dev/urandom | tr -cd 'aeiou' | cut -c -1)
        FUBTNAME=$(grep -n bluetooth_name /data/system/users/0/settings_secure.xml | grep -o 'value=".*"*' | cut -d '"' -f2)
        FUBTNAMEFB=$(grep -n bluetooth_name /data/system/users/0/settings_secure.xml.fallback | grep -o 'value=".*"*' | cut -d '"' -f2)
        FUDVNAME=$(grep -n device_name /data/system/users/0/settings_global.xml | grep -o 'value=".*"*' | cut -d '"' -f2)
        FUDVNAMEFB=$(grep -n device_name /data/system/users/0/settings_global.xml.fallback | grep -o 'value=".*"*' | cut -d '"' -f2)

        settings delete secure advertising_id
        echo "settings delete secure advertising_id"
        settings delete secure android_id
        echo "settings delete secure android_id"

        sed -i '/Name =/d' /data/misc/bluedroid/bt_config.conf
        echo "Name = $FURANDOM $modelok" >> /data/misc/bluedroid/bt_config.conf

        sed -i "s/$FUBTNAME/$FURANDOM $modelok/g" /data/system/users/0/settings_secure.xml

        if [ -f /data/system/users/0/settings_secure.xml.fallback ]; then 
        echo "Edo, fallback not found"
        else
        sed -i "s/$FUBTNAMEFB/$FURANDOM $modelok/g" /data/system/users/0/settings_secure.xml.fallback
        fi

        echo "Ganti nama bluetooth"
        sed -i "s/$FUDVNAME/$modelok/g" /data/system/users/0/settings_global.xml
        if [ -f /data/system/users/0/settings_global.xml.fallback ]; then 
        echo "Edo, fallback not found"
        else
        sed -i "s/$FUDVNAMEFB/$FURANDOM $modelok/g" /data/system/users/0/settings_global.xml.fallback
        fi

        echo "Ganti nama device"

        SCRIPTS_FILE=/data/adb/modules/playintegrityfix/system.prop
        if [ ! -f "$SCRIPTS_FILE" ]; then SCRIPTS_FILE=/data/adb/modules/playintegrityfix/system.prop;
        fi
        cp "$SCRIPTS_FILE" /data/adb/modules/magisk-drm-disabler/system.prop

        mount -o ro,remount /

		} &>/dev/null

    zxjanda() {
            IDKEY=$(grep -n "userkey" /data/system/users/0/settings_ssaid.xml | grep -o 'defaultValue=".*"*' | cut -d '"' -f2)
            IDV2=$(grep -n "com.lazada.android" /data/system/users/0/settings_ssaid.xml | grep -o 'defaultValue=".*"*' | cut -d '"' -f2)
            IDPS2=$(grep -n "com.android.vending" /data/system/users/0/settings_ssaid.xml | grep -o 'defaultValue=".*"*' | cut -d '"' -f2)
            IDPSRANDOM2=$(head -3 /dev/urandom | tr -cd $IDKEY | cut -c -16)

            IDRANDOM2=$(head -3 /dev/urandom | tr -cd $IDKEY | cut -c -16)
            IDLINE2=$(grep -n "com.google.android.gms" /data/system/users/0/settings_ssaid.xml | grep -o 'defaultValue=".*"*' | cut -d '"' -f2)

            IDLINERANDOM2=$(head -3 /dev/urandom | tr -cd $IDKEY | cut -c -16)
            sed -i "s/$IDLINE2/$IDLINERANDOM2/g" /data/system/users/0/settings_ssaid.xml
            sed -i "s/$IDV2/$IDRANDOM2/g" /data/system/users/0/settings_ssaid.xml
            sed -i "s/$IDPS2/$IDPSRANDOM2/g" /data/system/users/0/settings_ssaid.xml
            echo " DefaultID berhasil dirubah pak menjadi $(grep -n "com.lazada.android" /data/system/users/0/settings_ssaid.xml | grep -o 'defaultValue=".*"*' | cut -d '"' -f2) "
            sleep 0.5
            clear
    } &>/dev/null


clear_android_data
sleep 1
xnxx
sleep 1
zxjanda
sleep 5
# reboot
