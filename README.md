# Ffmpeg-size-converter
Simple powershell script which converts from mp4 to webm (possibly other file formats also, haven't tried it) analyses file size and adjusts bitrate depending on properties until target filesize is reached within a certain precision.

Script doesn't allow to go over target bitrate, allows t_fs-p under the target bitrate.

Minimum bitrate added to ensure quality. Script adjusts the scale of the clip if minimum bitrate isn't reached.

If height of the clip becomes less than 250 pixels (and still can't reach minimum br) script aborts since it cannot reach target.

## Requirements
Needs ffmpeg added to environment path in order to function
Script needs to be run from the same location as the movie file

## Properties
-in: File name of clip input
-out: File name of converted clip
-t_fs: Target File Size, in kB
-p: Precision, how close to target filesize it needs to be. Default is 50kB
-min_br: Minimum bitrate allowed. Default is 300 kB