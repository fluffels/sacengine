#!/bin/bash
wine ./ldc2-1.24.0-windows-x64/bin/dub.exe build -b release-debug --compiler=./ldc2-1.24.0-windows-x64/bin/ldc2.exe && bbe -e "s/\x5C$USER\x5C/\x5Ctg___\x5C/" 3d.exe > tmp_3d_tmp && mv tmp_3d_tmp 3d.exe
