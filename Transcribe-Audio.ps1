param (
    [Parameter(ValueFromRemainingArguments=$true)]
    $Arguments
)

function transcribe-audio($items){
    
    $url = "https://australiaeast.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1?language=en-AU&format=detailed&profanity=raw"
    $key = "YOUR-SUBSCRIPTION-KEY-HERE"
    $Headers = @{
      'Ocp-Apim-Subscription-Key' = $key;
      'Transfer-Encoding' = 'chunked';
      'Content-type' = 'audio/wav';
      'Accept' = 'application/json';
    }
    $csv = foreach ($item in $items){
        $wav = get-item $item
        #Add chopping long wavs to 59sec intervals.
        (& soxi $wav.FullName)[5] -match "(\d{2}:\d{2}:\d{2})" | Out-Null

        if ([timespan]$Matches[1] -gt [timespan]'00:00:59'){
            write-host "longer than 1min wav, splitting"
            $tempwavs = "C:\temp\"
            $wname = $wav.BaseName
            ffmpeg -i $wav.FullName -f segment -segment_time 59 -c copy $tempwavs$wname-out%03d.wav
            $xcribe = gci -Path $tempwavs -Filter *.wav | %{
                $TextResponse = Invoke-RestMethod -Method POST -Uri $url -Headers $Headers -InFile $_.FullName
                if ($TextResponse.RecognitionStatus){$TextResponse.NBest.Display}
                remove-item $_.FullName
            }
            [pscustomobject]@{Filename=$wav.Name;Transcribed=$xcribe -join " "}
        }else{
            $TextResponse = Invoke-RestMethod -Method POST -Uri $url -Headers $Headers -InFile $wav.FullName
            if ($TextResponse.RecognitionStatus){
                [pscustomobject]@{Filename=$wav.Name;Transcribed=$TextResponse.NBest.Display}
            }
        }
    }
    $csv
}


if ($Arguments){
        
    if ($Arguments.PSIsContainer){
        $folder = Get-ChildItem -Path $Arguments.FullName -Filter *.wav
        $csv = transcribe-audio -items $folder
    }else{
        $csv = transcribe-audio -items $Arguments
    }
    $csv | export-csv -Path "c:\temp\transcribed.csv" -Force -NoTypeInformation
}
