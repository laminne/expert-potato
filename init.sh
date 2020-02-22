#! bin/bash
echo "------------------------------------------------"
echo  "Expert-Potato -Automation Package insraller"
echo  "(C)laminne 2019-2020"
echo "------------------------------------------------"
echo .
echo .
echo Select installer number:
echo e.g. 153
read num

echo Ok. Checking recipe server....
wget http://clappdon.work/repos/amagasa/recipe/$num/start.sh
echo Checking Finished.
echo Finish This Script....
sh start.sh
exit 0
