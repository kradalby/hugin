#!/usr/bin/env bash

pageres --filename='<%= url %>' --overwrite --delay=5 \
    https://hugindemo.kradalby.no/ \
    https://hugindemo.kradalby.no/#/album/content/root/2018/index.json \
    https://hugindemo.kradalby.no/#/album/content/root/2018/2018-04-22_Biking_to_Lisse/index.json \
    https://hugindemo.kradalby.no/#/photo/content/root/2018/2018-04-22_Biking_to_Lisse/20180421-122847-IMG_6983.json \
    https://hugindemo.kradalby.no/#/keyword/content/keywords/Kristoffer_Andreas_Dalby.json \
    https://hugindemo.kradalby.no/#/keyword/content/keywords/Vestfold.json \

