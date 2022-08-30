# Create empty directory structure

$path = "d:\lab\emptydirectories"
$nrOfFolderLvl1 = 10;
$nrOfFolderLvl2 = 5;
$nrOfFolderLvl3 = 3

md $path;

1..5 | % { 
    
    $lvl1 = $path + "\" + "Level1-folder" + $_
    md $lvl1;
    

    1..5 | % { 
        $lvl2 = $lvl1 + "\" + "SubLevel2-folder" + $_
        md $lvl2
    }

    1..10 | % { 
        $lvl3 = $lvl2 + "\" + "SubLevel3-folder" + $_
        md $lvl3
    }
}
