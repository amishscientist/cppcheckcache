#!/usr/bin/env bash  
set -euo pipefail
IFS=$'\n\t' 

#-| #TODO: Fill this out!
#/ Usage: For large projects this should speed up cppcheck so it can be used on per commit build servers.   
#/
#/ Description: This script is a proto type for cacheing cppcheck results to speed up cppcheck.
#/ This script needs to be able to WRITE to /tmp/
#/ 
#/ Examples: #TODO: Examples.
#/ 
#/ Options: Other then --version and --help all other options start with --ccc-
#/    --ccc-path Where you would like the cache to be. Default is $HOME/.cppcheckcache.  
#/    --ccc-hash A path to a hash function to use instead of the date of a file. 
#/    --ccc-jobs Is if you want to use a diffrent number of jobs then cppchecks -j option.
#/    --ccc-prog Is the program you want to cache.
#/    --version Displays the version of the script and cache layout.
#/    --help: Display this help message.
usage() { grep '^#/' "$0" | cut -c4- ; exit 0 ; }
expr "$*" : ".*--help" > /dev/null && usage


#######   Start of Setup of Work Area   #######
# This is for temp files the script makes and uses.
# In this block you might want to tweek these.


sIsEmpty() { [[ -z $1 ]] ; } ; export -f sIsEmpty;
sIsNotEmpty() { [[ -n $1 ]] ; } ; export -f sIsNotEmpty;
sIsFile() { local file=$1 ; [[ -f $file ]] ; } ; export -f sIsFile;
sIsNotFile() { local file=$1 ; [[ ! -f $file ]] ; } ; export -f sIsNotFile;
sIsDir() { local dir=$1 ; [[ -d $dir ]] ; } ; export -f sIsDir;
sIsNotDir() { local dir=$1 ; [[ ! -d $dir ]] ; } ; export -f sIsNotDir;
sDoesExist() { local thing=$1 ; [[ -e $thing ]] ; } ; export -f sDoesExist;
sDoesNotExist() { local thing=$1 ; [[ ! -e $thing ]] ; } ; export -f sDoesNotExist;


sDoesNotExist "/tmp/cccWorkDir" && $( mkdir -p /tmp/cccWorkDir/ )
export CPPCHECKCACHE_DATE=$( date +%s )
export dirNumCMD="$( find /tmp/cccWorkDir/ -maxdepth 1 -type d -name "work_*" | wc -l )"
sIsEmpty "${dirNumCMD}" && export dirNUM="0";
sIsNotEmpty "${dirNumCMD}" && export dirNUM="${dirNumCMD}";
echo "${dirNumCMD}"

export readonly CPPCHECKCacheWorkDir="/tmp/cccWorkDir/work_${dirNUM}_${CPPCHECKCACHE_DATE}__${PPID}_$$"

export readonly CPPCHECKOUTPUTFILE="${CPPCHECKCacheWorkDir}/cppcheckcache_workFile.txt"
export readonly cLogFile="${CPPCHECKCacheWorkDir}/$(basename "$0").log"
export readonly cachedOutputStr="" #This adds a string to the front of cached output. TODO: It has issues. 

#######   Version Info   #######
readonly export configFileVer="0.0"
readonly export softwareVer="0.0"

version() { echo "cppcheckcache: ${softwareVer}"; echo "cacheLayout: ${configFileVer=}"; exit 0 ; }
expr "$*" : ".*--version" > /dev/null && version

########   Some Simple Functions   #######

sLog()     { echo "cache[LOG]     $*" >> "$cLogFile";            } ; export -f sLog;
sInfo()    { echo "cache[INFO]    $*" | tee -a "$cLogFile" >&2 ; } ; export -f sInfo;
sWarning() { echo "cache[WARNING] $*" | tee -a "$cLogFile" >&2 ; } ; export -f sWarning;
sError()   { echo "cache[ERROR]   $*" | tee -a "$cLogFile" >&2 ; } ; export -f sError;
sFatal()   { echo "cache[FATAL]   $*" | tee -a "$cLogFile" >&2 ; exit 1 ; } ; export -f sFatal;

sCleanUpFunc() {
    # Remove temporary files
    # Restart services
    # ...
    true # you can't have an empty funciton.
    #TODO: Do some cleanUp. 
}

#######  Make Script Work Area  #######
#sIsDir "${CPPCHECKCacheWorkDir}" && sFatal "Already in use: ${CPPCHECKCacheWorkDir}"
$( mkdir -p "${CPPCHECKCacheWorkDir}" && sLog "ccc: WorkDir created"; )


####### Put some useful data in the log #######
sInfo "ccc: Cache Work Dir:  ${CPPCHECKCacheWorkDir}"
sLog  "CppCheck Output File: ${CPPCHECKOUTPUTFILE}"
sLog  "Cache Config Ver:     ${configFileVer}"
sLog  "Cache Software Ver:   ${softwareVer}"
sLog  "Script Location:      ${BASH_SOURCE[0]}"


#######   Parsing of cmd line args   #######
checkArgFunc() {

#TODO: Rewrite this to parse before writing to workDir.  That way workDir can be an arg.
#TODO: Change vpath="$PWD" back to vpath="$HOME"
   sLog "***: Start arg parse func"
   echo "$@" | awk -v vpath="$PWD" '                                 \
        BEGIN{                                                       \
            cccPath=vpath"/.cppcheckcache";                          \
            cccHash="false";                                         \
            cccJobs=1;                                               \
            cccProg="cppcheck";                                      \
            cccDump="false";                                         \
            cccArgs="";                                              \
            cccSrc="";                                               \
            jobsSet="false";                                         \
            zeroNextVar="false";                                     \
        }                                                            \
        {                                                            \
            for (i = 1; i <= NF; ++i)                                \
            {                                                        \
                                                                     \
                if(zeroNextVar=="true")                              \
                {                                                    \
                    $i="";                                           \
                    zeroNextVar="false";                             \
                    ++i;                                             \
                }                                                    \
                if($i=="--ccc-prog")                                 \
                {                                                    \
                    cccProg=$(i+1);                                  \
                    $i="";                                           \
                    zeroNextVar="true";                              \
                }                                                    \
                else if($i=="--ccc-path")                            \
                {                                                    \
                    cccPath=$(i+1)"/.cppcheckcache";                 \
                    $i="";                                           \
                    zeroNextVar="true";                              \
                }                                                    \
                else if($i=="--ccc-hash")                            \
                {                                                    \
                    cccHash=$(1+1);                                  \
                    $i="";                                           \
                    zeroNextVar="true";                              \
                                                                     \
                }                                                    \
                else if($i=="--ccc-jobs")                            \
                {                                                    \
                    cccJobs=$(i+1);                                  \
                    jobsSet="true";                                  \
                    $i="";                                           \
                    zeroNextVar="true";                              \
                                                                     \
                }                                                    \
                else if($i=="-j")                                    \
                {                                                    \
                   if(jobsSet=="false")                              \
                   {                                                 \
                     cccJobs=$(i+1);                                 \
                   }                                                 \
                }                                                    \
                                                                     \
            }                                                        \
                                                                     \
            cccSrc=$NF;                                              \
            $NF="";                                                  \
            cccArgs=$0;                                              \
        }                                                            \
        END{                                                         \
            print cccPath"\n"cccHash"\n"cccJobs"\n"cccDump"\n"cccProg"\n"cccSrc"\n"cccArgs;  \
        }' > "${CPPCHECKCacheWorkDir}/parseArgs.txt"

    
    sLog "***: End arg parse func"

}


#######  Global Var Yuck!   #######
    $(checkArgFunc "$@" )
    sLog "ret: Check Arg Exit Code: $?"

    sLog "***: Start of global var set"
    export runCache="true"

    declare -a array
    readarray array < "${CPPCHECKCacheWorkDir}/parseArgs.txt"

    export cppCheckCacheDir="$( echo -n ${array[0]} )"
    export cppCheckCacheHash="$( echo -n ${array[1]} )"
    export NumCPU="$( echo -n ${array[2]} )"
    export cppCheckCacheDump="$( echo ${array[3]} )"
    export cppCheckProgramToCache="$( echo -n ${array[4]} )"
    export cppCheckProgramSrc="$( echo -n ${array[5]} )"
    export cppCheckArgs="$( echo -n ${array[6]} )"
    
    sLog "Cache  Dir:               ${cppCheckCacheDir}"
    sLog "Path to Hash Func:        ${cppCheckCacheHash}"
    sLog "Number of CPU to use:     ${NumCPU}"
    sLog "Need to Copy Dump Files:  ${cppCheckCacheDump}"
    sLog "Program Name to Cache:    ${cppCheckProgramToCache}"
    sLog "Src Dir to Parse:         ${cppCheckProgramSrc}"
    sLog "CppCheck Args:            ${cppCheckArgs}"

    export cppCheckCacheVerDir="${cppCheckCacheDir}/${configFileVer}"
    export cppCheckProgramToCacheDir="${cppCheckCacheVerDir}/${cppCheckProgramToCache}"
    export cppCheckVer="$( ${cppCheckProgramToCache} --version | awk '{print $2;}' )"  #TODO: Should probably check all the programs to see if they have a --version.
    export cppCheckVerDir="${cppCheckProgramToCacheDir}/${cppCheckVer}"
    export cppCheckArgsForPath="$( echo "${cppCheckArgs} ${cppCheckProgramSrc}" | sed 's/\//S/g; s/=/E/g; s/--/D/g; s/-/d/g;' | sort | awk 'BEGIN{ OFS ="";} { $1=$1; print $0; }' )"
    export cppCheckArgDir="${cppCheckVerDir}/${cppCheckArgsForPath}"
    export cppCheckCacheWorkAreaPath="${cppCheckArgDir}"
    export cppCheckCacheWorkAreaPath_NUM="$( echo ${cppCheckCacheWorkAreaPath} | awk -F \/ '{print NF;}' )"


    sLog "CppCheck Cache Ver:       ${cppCheckCacheVerDir}"
    sLog "Name for Prog Dir:        ${cppCheckProgramToCacheDir}"
    sLog "CppCheck Ver:             ${cppCheckVer}"
    sLog "CppCheck Ver. Dir:        ${cppCheckVerDir}"
    sLog "CppCheck Args Path:       ${cppCheckArgsForPath}"
    sLog "CppCheck Args Dir:        ${cppCheckArgDir}"
    sLog "CppCheck Cache Work Path: ${cppCheckCacheWorkAreaPath}"
    sLog "CppCheck Cache Work Path Depth: ${cppCheckCacheWorkAreaPath_NUM}"


    sLog "***: End of global var set"

#######   Runs Cpp Check Command   #######
runCppCheckFunc() {

    #TODO: NICE: I should make a debug option that just copies saved off output to save on debugging time.

    sInfo  "***: Starting Cpp Check"
    #Build Command
    cmdToRun="$* > >(tee -a ${CPPCHECKCacheWorkDir}/cppcheckcache_workFile.stdout.log) 2> >(tee -a ${CPPCHECKCacheWorkDir}/cppcheckcache_workFile.stderr.log >&2)"
    echo  "${cmdToRun}" >& ${CPPCHECKCacheWorkDir}/cmd.out
    sLog   "ccc: Command and Args are in file :  ${CPPCHECKCacheWorkDir}/cmd.out"

    #Run Command
    eval ${cmdToRun}
    sLog   "ret: Cpp Check Exit Code: $?"

    #Join stderr and stdout into one file.   
    $( cat ${CPPCHECKCacheWorkDir}/cppcheckcache_workFile.stdout.log  ${CPPCHECKCacheWorkDir}/cppcheckcache_workFile.stderr.log > ${CPPCHECKCacheWorkDir}/cppcheckcache_workFile.txt ) 
    sLog   "ret: Output File Merge Exit Code: $?"   
    sInfo  "***: Cpp Check Finished"

}


#######   Checks single Cache entry to see if it can be used   #######
cppCheckCacheFileCheckFunc () {
set -euo pipefail #called from a xargs

    local threadNumber=$1
    cacheDir="${cppCheckCacheWorkAreaPath}"
    cacheFile=$2
    cacheFileDir="$( dirname ${cacheFile} )"
    projectFile="$( echo "${cacheFileDir}" | awk -v var=$cppCheckCacheWorkAreaPath_NUM -F \/ '{path="."; for (i = var+1; i <= NF; ++i) {path=path"/"$i; } print path;  }' )"
    
   
    local fileTime01="$(stat -c %Y ${cacheFile})"
    sDoesNotExist "${projectFile}" && return 0;
    local fileTime02="$( stat -c %Y ${projectFile} )"
    if [ $fileTime01 -gt $fileTime02 ]; then
        #Cache File is Newer!
        #Need to add this file to the cppcheck ignore file list.
        echo "${projectFile}"
        $( cat ${cacheFileDir}/OUTPUT.txt >> ${CPPCHECKCacheWorkDir}/SplitFiles/Thread__${threadNumber}_Output.txt )
    else    
        #Project File is Newer!
        #Need to remove Cache Dir
        rm -rf ${cacheFileDir}
    fi

} ; export -f cppCheckCacheFileCheckFunc;


#######   Batches the Cache entry Checks Per thread   #######
cppCheckCacheBatchFileCheckFunc () {
set -euo pipefail #called from a xarg

    local threadNumber=$1
    listOfFilesToCheck=$2
    $( cat ${listOfFilesToCheck} | xargs -n 1 -P 1  -I {} bash -c "cppCheckCacheFileCheckFunc ${threadNumber} {}" >& ${CPPCHECKCacheWorkDir}/SplitFiles/Thread__${threadNumber}_Filelist.txt )
} ; export -f cppCheckCacheBatchFileCheckFunc;



#######   Makes a Cache Entry From Cpp Check Output   #######
cppCheckCacheFileEntryFunc () {
set -euo pipefail #called from a xarg
    local cacheDir="${cppCheckCacheWorkAreaPath}"
    local projectFile="${2}"
    local projectFileDir="${cacheDir}/${projectFile}"

    #echo "Cache Dir: ${cacheDir}"
    #echo "Project File: ${projectFile}"
    #echo "Project File Dir: ${projectFileDir}"
    sDoesNotExist "${projectFileDir}" && mkdir -p ${projectFileDir} #&& echo "Made Dir: ${projectFileDir}"
    
    #TODO: why the fgrep?  grep ${projectFile} ${CPPCHECKOUTPUTFILE} | fgrep -v  "${cachedOutputStr}" | awk -v var=${cachedOutputStr} '{print var$0}' >>  ${projectFileDir}/OUTPUT.txt 2>&1
    if [ "$1" -eq "1" ]; then

   $( sDoesExist "${projectFileDir}" && rm -rf "${projectFileDir}" )

    $( mkdir -p "${projectFileDir}")  #&& echo "Made Dir: ${projectFileDir}"
        grep ${projectFile} ${CPPCHECKCacheWorkDir}/cppcheckcache_workFile.stderr.log  | awk -v var=${cachedOutputStr} '{print var$0}' >>  ${projectFileDir}/OUTPUT.txt 2>&1

    else

        grep ${projectFile} ${CPPCHECKCacheWorkDir}/cppcheckcache_workFile.stdout.log | awk -v var=${cachedOutputStr} '{print var$0}' >>  ${projectFileDir}/OUTPUT.txt 2>&1

    fi

    cmdOutput=$( find ${projectFileDir} -name "DATE_*" ) 
    sIsNotEmpty "${cmdOutput}" && $( echo "${cmdOutput}" | xargs -n 4 -P 1 -I {} rm {} )
    $( touch ${projectFileDir}/DATE_${CPPCHECKCACHE_DATE} )
    #SLOC count.
    #$( is_file ${projectFile} && is_not_file "${projectFileDir}/SLOC_*" && wc -l ${projectFile} | awk '{print $1;}' | xargs -n 1 -P 1 -I {} touch ${projectFileDir}/SLOC_{} )
    #$( is_not_file ${projectFile} && is_not_file "${projectFileDir}/SLOC_*" &&  touch ${projectFileDir}/SLOC_0 )
    #HASH could be done here.

} ; export -f cppCheckCacheFileEntryFunc;


#######   Splits up the List of cache entrys into a list for each thread   #######
splitUpWorkFunc() {
    sLog "***: Start of Split Func"
    local numOfFiles=${NumCPU}
    local fileToSplit=$1

    sLog  "ccc: numFiles=${numOfFiles}"
    sLog  "ccc: fileToSplit=${fileToSplit}"
    # Work out lines per file.
    local totalLines=$(wc -l <${fileToSplit})
    sLog  "ccc: totalLines=${totalLines}"
    ((linesPerFile = (totalLines + numOfFiles - 1) / numOfFiles))

    #Split files up.
    $( mkdir ${CPPCHECKCacheWorkDir}/SplitFiles )
    split --lines=${linesPerFile} ${fileToSplit} ${CPPCHECKCacheWorkDir}/SplitFiles/ccc_fileList.
    sLog  "ret: Split Exit Code: $?"

    # Debug information
    sLog  "ccc: Total lines     = ${totalLines}"
    sLog  "ccc: Lines  per file = ${linesPerFile}"    
    sLog  "ccc: $( wc -l ${CPPCHECKCacheWorkDir}/SplitFiles/ccc_fileList.* )"
    sLog  "***: End of Split Func"            
}

#TODO: DON'T FORGET to run shellcheck -x -a scriptName.sh


if [[ "${BASH_SOURCE[0]}" = "$0" ]]; then
    trap sCleanUpFunc EXIT
    #TODO: Add Hashing
    #TODO: Add Unit Test.
    #TODO: Delete A Project File Test.
    #TODO: Format Clean up. Make Short Var names!
    #TODO: Find out which Cpp Check Args Break the cache. xml and unused function probably? 
    #TODO: NICE: Check for mawk over awk.
    #TODO: NICE: set a max size for hash.
    #TODO: NICE: Maybe compress cache or workDir.
    #TODO: Cache stats.
    #TODO: NICE: git diff option.

    sLog "***: Start Main"

    if [ "${runCache}" == "true" ]; then
        sLog "***: Running with Cpp Check Cache"
        #Build Cpp Check Cache Layout.
        sLog "ccc: Build Cache Layout"
        export cacheEmpty=""
        sDoesNotExist ${cppCheckCacheDir}          && mkdir -p ${cppCheckCacheDir}          && sInfo "ccc: Making cppcheck cache Dir: ${cppCheckCacheDir}"
        sDoesNotExist ${cppCheckCacheVerDir}       && mkdir -p ${cppCheckCacheVerDir}       && sInfo "ccc: Making cppcheck cache version Dir: ${cppCheckCacheVerDir}"
        sDoesNotExist ${cppCheckProgramToCacheDir} && mkdir -p ${cppCheckProgramToCacheDir} && sInfo "ccc: Making cppcheck Program to cache Dir: ${cppCheckProgramToCacheDir}"
        sDoesNotExist ${cppCheckVerDir}            && mkdir -p ${cppCheckVerDir}            && sInfo "ccc: Making cppcheck Version Dir: ${cppCheckVerDir}"
        sDoesNotExist ${cppCheckArgDir}            && mkdir -p ${cppCheckArgDir}            && sInfo "ccc: Making cppcheck Args Dir: ${cppCheckArgDir}" && export cacheEmpty=true        
        sLog "Finished Building Cache Layout"

        if [ "${cacheEmpty}" == "true" ]; then
            sInfo "***: Cpp Check Cache Empty!"

            cmdToRun="${cppCheckProgramToCache} ${cppCheckArgs} ${cppCheckProgramSrc}"
            runCppCheckFunc "${cmdToRun}"
            sLog "ret: Run Cpp Check Func Exit Code: $?"

        else
            sInfo "***: Cpp Check Cache Found!"
            listOfCachedFiles="${CPPCHECKCacheWorkDir}/ccc_MainFileList.txt"
            sLog  "ccc: Build List of Files in Cache in File: ${listOfCachedFiles}"
            sLog  "ccc: Path where it is looking for Cache Files: ${cppCheckCacheWorkAreaPath}"
            sLog  "ret: sLog Exit Code: $?" #Weird Error one time with the sLog blowing up here!.

            #Builds up a list of all files in cache.
            $( find ${cppCheckCacheWorkAreaPath} -type f -name "DATE_*" > ${listOfCachedFiles} )
            sLog "ret: Build List of Files in Cache Exit Code: $?"
  
            #This splits the work up to use more then one core to check the files.  
            echo "$( splitUpWorkFunc "${listOfCachedFiles}" )"
            sLog "ret: Split Up Work Func Exit Code: $?"
            
            sLog  "ccc: Start Checking files in cache"            
            find ${CPPCHECKCacheWorkDir}/SplitFiles/ -type f | nl | xargs -n 1 -P ${NumCPU} -I {} bash -c "cppCheckCacheBatchFileCheckFunc {}"
            #TODO: NICE: if NumCPU less then 2  #| xargs -n 1 -P ${NumCPU} -I {} bash -c "cppCheckCacheFileCheckFunc {}" 
            sLog "ret: File Check Exit Code: $?"

            sLog "ccc: Build Ignore List"            
            #Bring all files into One ignore list. 
            export ignoreList=$( find ${CPPCHECKCacheWorkDir}/SplitFiles/ -type f -name "Thread__*_Filelist.txt"  | xargs -n 1 -P ${NumCPU}  awk '{printf " -i%s",$0;}' )
            sLog "ret: Ignore List Exit Code: $?"

            sLog "ccc: Build Cached Output"            
            export cachedOutput=$( find ${CPPCHECKCacheWorkDir}/SplitFiles/ -type f -name "Thread__*_Output.txt" | xargs -n 1 -P 1  awk '{print $0; }' )
            sLog "ret: Build Cached Output Exit Code: $?"

            sLog "ccc: Output Cached Output"
            echo "${cachedOutput}" # | sort | uniq  #TODO: Hack.
            sLog "ret: Output Cached Output Exit Code: $?"

            #TODO: I should proably store off output as stderr and stdout

            #Run cppcheck.
            sLog "ccc: Adding Ignore List to Cpp Check Command";
            cmdToRun="${cppCheckProgramToCache} ${cppCheckArgs} ${ignoreList} ${cppCheckProgramSrc}"
            sInfo "ccc: Run Cpp Check With Ignore List";
            runCppCheckFunc "${cmdToRun}" 
            sLog "ret: Run Cpp Check Func Exit Code: $?"

        fi
            #Parse CppCheck Output.
            sInfo "***: Parse Cpp Check Outputfile"
            sLog  "ccc: Parse Cpp Check Outputfile 01 Rules"
            #STDerr
            #OUTPUT01="$( awk -F ":" '/^\[/ {split($1,array,"["); n=split(array[2],fileName,"."); if ( fileName[n]  print array[2];}' ${CPPCHECKCacheWorkDir}/cppcheckcache_workFile.stderr.log  |  awk -F "." '{if( $NF != "hh" && $NF != "h" ){ print $0}}' | xargs -n 1 -P ${NumCPU} -I {} bash -c "cppCheckCacheFileEntryFunc 1 {}" )"
            OUTPUT01="$( awk -F ":" '/^\[/ {split($1,array,"["); print array[2];}' ${CPPCHECKCacheWorkDir}/cppcheckcache_workFile.stderr.log  | sort | uniq | awk -F "." '{if( $NF != "hh" && $NF != "h" ){ print $0}}' | xargs -n 1 -P 1  -I {} bash -c "cppCheckCacheFileEntryFunc 1 {}" )"
            sLog  "ret: P1Rule Exit Code: $?" 
            #echo "${OUTPUT01}"  
            sLog  "ccc: Parse Cpp Check Outputfile 02 Checking"
            #STDout
            OUTPUT02="$( awk '/^Checking/ {split($2,array,":"); print array[1];}' ${CPPCHECKCacheWorkDir}/cppcheckcache_workFile.stdout.log | sort | uniq | awk -F "." '{if( $NF != "hh" && $NF != "h" ){ print $0}}' | xargs -n 1 -P 1 -I {} bash -c "cppCheckCacheFileEntryFunc 2 {}" )"
            sLog  "ret: P2Checking Exit Code: $?"   
            sInfo "***: Parse Cpp Check Outputfile Done"
        
    fi


    sLog "***: End  Main";

fi
