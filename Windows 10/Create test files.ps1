# Make test files

$path = "C:\temp"

1..10 | % {
    $newFile = "$path\test_file_$_.txt";
    New-Item $newFile
}
