#!/usr/bin/env bash


pageres --format=jpg --overwrite --delay=10 --filename='root' https://hugindemo.kradalby.no/ 
pageres --format=jpg --overwrite --delay=10 --filename='albums' https://hugindemo.kradalby.no/#/album/content/root/2018/index.json 
pageres --format=jpg --overwrite --delay=10 --filename='album' https://hugindemo.kradalby.no/#/album/content/root/2018/2018-04-22_Biking_to_Lisse/index.json 
pageres --format=jpg --overwrite --delay=10 --filename='photo' https://hugindemo.kradalby.no/#/photo/content/root/2018/2018-04-22_Biking_to_Lisse/20180421-122847-IMG_6983.json 
pageres --format=jpg --overwrite --delay=10 --filename='person' https://hugindemo.kradalby.no/#/keyword/content/keywords/Kristoffer_Andreas_Dalby.json 
pageres --format=jpg --overwrite --delay=10 --filename='keyword' https://hugindemo.kradalby.no/#/keyword/content/keywords/Vestfold.json 

