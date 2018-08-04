function Ffmpeg-Size-Converter{
    param(
    [Parameter(Mandatory=$true)][string]$in,
    [Parameter(Mandatory=$true)][string]$out,
    [Parameter(Mandatory=$true)][string]$t_fs,
    [int]$p = 50,
    [int]$min_br = 350
    )
    $curr_fs = 0
    $iterate = 1
    $count = 0
    $max_fs = [string]$t_fs + "K"
    $in_pre = $in.Substring(0, 2)

    if($in_pre -eq ".\"){
        $in = $in.Substring(2)
    }

    if(!(test-path $in)){
        echo "File not found. Breaking"
        return
    }
    
    $directorypath = (Get-Item -Path ".\").FullName

    $objShell = New-Object -ComObject Shell.Application 
    $objFolder = $objShell.Namespace($directorypath)
    $objFile = $objFolder.ParseName($in)


    #Getting object properties the really weird way because windows is windows. Found
    #the different values by looping through all properties and knowing what to look for.
    $width = $objFolder.GetDetailsOf($objFile, 316)
    $height = $objFolder.GetDetailsOf($objFile, 314)
    $Length = $objFolder.GetDetailsOf($objFile, 27)

    $min_s = $Length.SubString(3,2)
    $sec = $Length.SubString(6)

    if($min_s -eq "gt"){
        echo "Error getting file length. Breaking"
        return
    }

    [int]$min = [convert]::ToInt32($min_s, 10)

    echo "min: $min, min_s:$min_s, Length: $Length"

    while($min -gt 0){
        [int]$sec += 60;
        $min = $min -1;
    }

    #Approximation of bitrate to decrease need of adjustment, doesn't do much but at least something. 
    $br = 24288 / $sec

    if($br -lt $min_br){
        echo "Approximation too small, setting to min bitrate: $min_br"
        $br = $min_br
    }

    echo "Initial bitrate $br, min: $min sec: $sec"

    $ratio_adjust = 0
    
    while($iterate){
        $br_K = [string]$br + "K"
    
        #Remove previous iteration 
        if(test-path $out){Remove-Item $out}
    
        #If bitrate is too low for current resolution, change aspect ratio (done further down after result is analyzed)
        if($ratio_adjust){
            ffmpeg -i $in -c:v libvpx -b:v $br_K -an  -s $ratio_string -c:a libvorbis $out
        }else{
            ffmpeg -i $in -c:v libvpx -b:v $br_K -an  -c:a libvorbis $out
        }

        echo "`n----- Adjustments:"
    
        #Get filesize
        $curr_fs = Get-ChildItem $out | % {[int]($_.length / 1kb)}
    

        #If current filesize is too large (upper limit is more important than lower), decrease by
        #the ratio created from target_bitrate/current_bitrate, then divide current bitrate with this ratio.
        #This simple algorithm will generate value >1 if greater, <1 if lesser, approaching target_fs.

        if($curr_fs -gt $t_fs){
            $br = $br * ($t_fs / $curr_fs);
            echo "File size too large ($curr_fs > $t_fs), lowering bitrate, decreasing to: $br kbit/s"

            #If bitrate < $min_br (400 default) then quality isn't good enough. Lower the scale by 75% and retry again. Iterate over and over until
            #sufficient quality is ensured
            if($br -lt $min_br){
                $ratio_adjust = 1
                $width = [math]::Floor([int]$width * 0.75)
                $height = [math]::Floor([int]$height * 0.75)
                $ratio_string = [string]$width + "x" + [string]$height
                $br = $min_br

                #Min height 250
                if($height -lt 250){
                    echo "Height too small, unable to make successful webm, aborting."
                    $iterate = 0
                }else{
                    echo "Bitrate under min limit, adjusting scale to $ratio_string, bitrate: $br"
                }

            }

        }elseif($curr_fs -lt $t_fs - $p -or $br -lt $min_br){
            echo "File size too small, taking action"
            if($br -lt $min_br){
                #If bitrate < $min_br (400 default) then quality isn't good enough. Lower the scale by 75% and retry again. Iterate over and over until
                #sufficient quality is ensured.
                $ratio_adjust = 1
                $width = [math]::Floor([int]$width * 0.75)
                $height = [math]::Floor([int]$height * 0.75)
                $ratio_string = [string]$width + "x" + [string]$height
                $br = $min_br

                #Min height 250
                if($height -lt 250){
                    echo "Height too small, unable to make successful webm, aborting."
                    $iterate = 0
                }else{
                    echo "Bitrate under min limit, adjusting scale to $ratio_string, bitrate: $br"
                }
            }else{
                $br = $br * ($t_fs / $curr_fs);

                echo "($curr_fs < $t_fs - $p), increasing bitrate to: $br kbit/s"
            }
        }else{

            #Target filesize hit, within precision, close iteration script is complete.
            $br = [math]::Floor($br)
            echo "Target hit within $p kB precision, after $count iterations, output name: $out, file size: $curr_fs kB, bit rate: $br, file aspect ratio: $ratio_string"
            $iterate = 0
        }

        echo "----- `n `n"
        $count++
    }
}